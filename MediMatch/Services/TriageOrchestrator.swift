import Foundation

/// Coordinates the full triage pipeline:
/// `HeuristicSafetyFilter → PromptGuardService → TriageLLMService → MedicalLLMService`.
///
/// Streaming model: callers receive incremental token chunks via a
/// continuation, then a final `TriageResult` once parsing finishes.
public actor TriageOrchestrator {

    public struct StreamUpdate: Sendable {
        public enum Kind: Sendable {
            case stage(Stage)
            case token(String)
            case warning(String)
            case finished(TriageResult)
            case failed(String)
        }
        public let kind: Kind
    }

    public enum Stage: String, Sendable, Equatable {
        case validating
        case classifying
        case generating
        case enriching
        case parsing
        case done
    }

    private let safetyFilter: HeuristicSafetyFilter
    private let promptGuard: PromptGuardService
    private let triageLLM:   TriageLLMService
    private let medicalLLM:  MedicalLLMService
    private let persistence: PersistenceService

    /// Probability threshold above which the prompt-guard model's
    /// "injection / unsafe" verdict is allowed to override input.
    private let unsafeThreshold: Float = 0.75

    public init(
        safetyFilter: HeuristicSafetyFilter = .init(),
        promptGuard:  PromptGuardService,
        triageLLM:    TriageLLMService,
        medicalLLM:   MedicalLLMService,
        persistence:  PersistenceService
    ) {
        self.safetyFilter = safetyFilter
        self.promptGuard  = promptGuard
        self.triageLLM    = triageLLM
        self.medicalLLM   = medicalLLM
        self.persistence  = persistence
    }

    /// Streams the full triage pipeline.
    public func run(symptoms: String, locale: Locale = .current) -> AsyncStream<StreamUpdate> {
        AsyncStream { continuation in
            let task = Task {
                await self.runPipeline(
                    symptoms: symptoms,
                    locale: locale,
                    continuation: continuation
                )
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func cancel() async {
        await triageLLM.stop()
        await medicalLLM.stop()
    }

    // MARK: - Pipeline

    private func runPipeline(
        symptoms: String,
        locale: Locale,
        continuation: AsyncStream<StreamUpdate>.Continuation
    ) async {
        let send: (StreamUpdate.Kind) -> Void = { kind in
            continuation.yield(StreamUpdate(kind: kind))
        }

        // 1) Heuristic safety filter (always-on first layer)
        send(.stage(.validating))
        let heuristic = safetyFilter.evaluate(symptoms)
        switch heuristic {
        case .block(let reason):
            send(.failed(reason))
            return
        case .warn(let reason):
            send(.warning(reason))
        case .allow:
            break
        }

        // 2) Prompt-guard classifier (symptom_input_processing)
        send(.stage(.classifying))
        let inputVerdict = await promptGuard.classify(symptoms)
        if (inputVerdict.label == .injection || inputVerdict.label == .unsafe)
            && inputVerdict.score >= unsafeThreshold {
            send(.failed(NSLocalizedString("guard.modelBlocked",
                value: "MediMatch couldn't safely process that message. Try describing your symptoms differently.",
                comment: "")))
            return
        }

        // 3) Triage LLM (recommendation_system) - streaming
        send(.stage(.generating))
        let baseSeverity = SymptomCatalog.baseSeverity(for: matchedCatalogIds(symptoms: symptoms))
        let prompt = PromptTemplates.triagePrompt(
            symptoms: symptoms,
            locale: locale,
            baseSeverityHint: baseSeverity
        )

        var fullText = ""
        do {
            for try await token in await triageLLM.stream(prompt: prompt) {
                if Task.isCancelled { return }
                fullText.append(token)
                send(.token(token))
            }
        } catch {
            send(.failed(NSLocalizedString("triage.failure",
                value: "Triage model failed. Please try again.", comment: "")))
            return
        }

        // 4) Parse JSON and apply condition_mapping cross-check
        send(.stage(.parsing))
        var result: TriageResult
        if let parsed = TriageOrchestrator.parseTriageJSON(fullText, originalInput: symptoms) {
            result = parsed
        } else {
            send(.warning(NSLocalizedString("triage.parseFallback",
                value: "Couldn't parse the model's structured output. Showing the raw summary.",
                comment: "")))
            result = TriageResult(
                inputSymptoms: symptoms,
                severity: baseSeverity == .unknown ? .urgentCare : baseSeverity,
                severityConfidence: 0.4,
                summary: TriageOrchestrator.firstParagraph(fullText, fallback: NSLocalizedString("triage.noOutput",
                    value: "No structured output was produced.", comment: "")),
                recommendedActions: [
                    NSLocalizedString("triage.fallback.action.consult",
                        value: "Consult a licensed clinician.", comment: "")
                ],
                redFlags: [],
                candidates: []
            )
        }

        // condition_mapping checkpoint: re-run the prompt-guard classifier
        // over the produced summary. If unsafe, we strip it and keep severity.
        let outputVerdict = await promptGuard.classify(result.summary)
        if (outputVerdict.label == .unsafe || outputVerdict.label == .injection)
            && outputVerdict.score >= unsafeThreshold {
            result = TriageResult(
                inputSymptoms: result.inputSymptoms,
                severity: result.severity,
                severityConfidence: result.severityConfidence,
                summary: NSLocalizedString("triage.summary.redacted",
                    value: "The model produced text we did not feel safe showing. Please consult a clinician for guidance.",
                    comment: ""),
                recommendedActions: result.recommendedActions,
                redFlags: result.redFlags,
                candidates: []
            )
        }

        // 5) Medical enrichment (local_data_management)
        send(.stage(.enriching))
        let activeMeds = await persistence.activeMedications()
        let enrichmentPrompt = PromptTemplates.medicalEnrichmentPrompt(
            symptoms: symptoms,
            triageSummary: result.summary,
            activeMedications: activeMeds,
            locale: locale
        )
        let enrichment: String?
        do {
            let text = try await medicalLLM.enrich(prompt: enrichmentPrompt)
            enrichment = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
        } catch {
            enrichment = nil
        }

        let finalResult = TriageResult(
            id: result.id,
            createdAt: result.createdAt,
            inputSymptoms: result.inputSymptoms,
            severity: result.severity,
            severityConfidence: result.severityConfidence,
            summary: result.summary,
            recommendedActions: result.recommendedActions,
            redFlags: result.redFlags,
            candidates: result.candidates,
            medicalEnrichment: enrichment
        )

        await persistence.appendHistory(HistoryEntry(result: finalResult))

        send(.stage(.done))
        send(.finished(finalResult))
    }

    private func matchedCatalogIds(symptoms: String) -> Set<String> {
        let lower = symptoms.lowercased()
        var ids: Set<String> = []
        for symptom in SymptomCatalog.all {
            let needles = [symptom.displayName.lowercased()] + symptom.synonyms.map { $0.lowercased() }
            if needles.contains(where: { lower.contains($0) }) {
                ids.insert(symptom.id)
            }
        }
        return ids
    }

    // MARK: - JSON Parsing

    /// Parses the strict-JSON output the triage prompt requested. Tolerates
    /// minor wrapper artifacts (model may add ```json fences despite our
    /// instructions).
    static func parseTriageJSON(_ raw: String, originalInput: String) -> TriageResult? {
        let cleaned = stripCodeFences(raw)
        guard let jsonStart = cleaned.range(of: "{") else { return nil }
        guard let jsonEnd   = cleaned.range(of: "}", options: .backwards) else { return nil }
        let json = String(cleaned[jsonStart.lowerBound..<jsonEnd.upperBound])
        guard let data = json.data(using: .utf8) else { return nil }
        do {
            let decoded = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            guard let dict = decoded as? [String: Any] else { return nil }
            let severity   = (dict["severity"] as? String).flatMap(Severity.init(rawValue:)) ?? .unknown
            let confidence = (dict["severity_confidence"] as? Double) ?? 0.0
            let summary    = (dict["summary"] as? String) ?? ""
            let actions    = (dict["recommended_actions"] as? [Any] ?? [])
                .compactMap { $0 as? String }
            let redFlags   = (dict["red_flags"] as? [Any] ?? [])
                .compactMap { $0 as? String }
            let candidatesRaw = (dict["candidates"] as? [[String: Any]]) ?? []
            let candidates = candidatesRaw.compactMap { entry -> CandidateCondition? in
                guard let name = entry["name"] as? String else { return nil }
                let conf = (entry["confidence"] as? Double) ?? 0
                let why  = (entry["rationale"] as? String) ?? ""
                return CandidateCondition(name: name, confidence: conf, rationale: why)
            }
            return TriageResult(
                inputSymptoms: originalInput,
                severity: severity,
                severityConfidence: confidence,
                summary: summary,
                recommendedActions: actions,
                redFlags: redFlags,
                candidates: candidates
            )
        } catch {
            return nil
        }
    }

    static func stripCodeFences(_ s: String) -> String {
        var out = s
        if let r = out.range(of: "```json") { out.removeSubrange(r) }
        if let r = out.range(of: "```")     { out.removeSubrange(r) }
        if let r = out.range(of: "```", options: .backwards) { out.removeSubrange(r) }
        return out
    }

    static func firstParagraph(_ s: String, fallback: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return fallback }
        if let split = trimmed.range(of: "\n\n") {
            return String(trimmed[..<split.lowerBound])
        }
        return trimmed
    }
}
