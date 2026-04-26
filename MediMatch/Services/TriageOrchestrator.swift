import Foundation

/// Coordinates the triage pipeline:
/// `HeuristicSafetyFilter → PromptGuardService → TriageLLMService`.
///
/// The LLM receives a **single** user message per run, returns one reply and a
/// machine-readable `MEDIMATCH_JSON` block. Streaming exposes safe prose to the UI
/// as tokens (meta markers are hidden).
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
        case parsing
        case done
    }

    private let safetyFilter: HeuristicSafetyFilter
    private let promptGuard: PromptGuardService
    private let triageLLM:   TriageLLMService
    private let persistence: PersistenceService

    /// Probability threshold above which the prompt-guard model's
    /// "injection / unsafe" verdict is allowed to override input.
    private let unsafeThreshold: Float = 0.75

    public init(
        safetyFilter: HeuristicSafetyFilter = .init(),
        promptGuard:  PromptGuardService,
        triageLLM:    TriageLLMService,
        persistence:  PersistenceService
    ) {
        self.safetyFilter = safetyFilter
        self.promptGuard  = promptGuard
        self.triageLLM    = triageLLM
        self.persistence  = persistence
    }

    /// Streams the triage pipeline for one user message. Only the latest user
    /// turn in `chatTurns` is sent to the model.
    public func run(chatTurns: [TriageChatTurn], locale: Locale = .current) -> AsyncStream<StreamUpdate> {
        AsyncStream { continuation in
            let task = Task {
                await self.runPipeline(
                    chatTurns: chatTurns,
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
    }

    // MARK: - Pipeline

    private static let metaBlockMarker = "MEDIMATCH_JSON"

    /// Stops the token stream as soon as a well-formed `MEDIMATCH_JSON` object exists (avoids long post-JSON run-on).
    public static func isTriageGenerationComplete(_ raw: String) -> Bool {
        guard let r = raw.range(of: Self.metaBlockMarker, options: .caseInsensitive) else {
            return false
        }
        var tail = String(raw[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if tail.hasPrefix("```") {
            if let idx = tail.firstIndex(of: "\n") {
                tail = String(tail[tail.index(after: idx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        guard let open = tail.firstIndex(of: "{") else { return false }
        var depth = 0
        var inString = false
        var escape = false
        var i = open
        while i < tail.endIndex {
            let c = tail[i]
            if inString {
                if escape {
                    escape = false
                } else if c == "\\" {
                    escape = true
                } else if c == "\"" {
                    inString = false
                }
            } else {
                switch c {
                case "\"":
                    inString = true
                case "{":
                    depth += 1
                case "}":
                    depth -= 1
                    if depth == 0 {
                        let json = String(tail[open...i])
                        guard let d = json.data(using: .utf8) else { return false }
                        return (try? JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed])) is [String: Any]
                    }
                default:
                    break
                }
            }
            i = tail.index(after: i)
        }
        return false
    }

    private func runPipeline(
        chatTurns: [TriageChatTurn],
        locale: Locale,
        continuation: AsyncStream<StreamUpdate>.Continuation
    ) async {
        let send: (StreamUpdate.Kind) -> Void = { kind in
            continuation.yield(StreamUpdate(kind: kind))
        }
        // Single-pass triage: only the latest user text is used (no multi-turn transcript).
        let userMessages = chatTurns.filter { $0.role == .user }
        guard let soleUser = userMessages.last else {
            send(.failed("Missing user message."))
            return
        }
        let lastUserText = soleUser.text
        if lastUserText.isEmpty {
            send(.failed("Missing user message."))
            return
        }
        let effectiveTurns = [soleUser]
        let transcript = TriageChatTurn.makeTranscript(effectiveTurns)

        // 1) Heuristic safety filter (always-on first layer)
        send(.stage(.validating))
        let heuristic = safetyFilter.evaluate(lastUserText)
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
        let inputVerdict = await promptGuard.classify(lastUserText)
        if (inputVerdict.label == .injection || inputVerdict.label == .unsafe)
            && inputVerdict.score >= unsafeThreshold {
            send(.failed(NSLocalizedString("guard.modelBlocked",
                value: "MediMatch couldn't safely process that message. Try describing your symptoms differently.",
                comment: "")))
            return
        }

        // 3) Triage LLM (recommendation_system) - streaming
        send(.stage(.generating))
        let baseSeverity = SymptomCatalog.baseSeverity(for: matchedCatalogIds(symptoms: lastUserText))
        let prompt = PromptTemplates.triageSinglePassPrompt(
            userMessage: lastUserText,
            locale: locale,
            baseSeverityHint: baseSeverity
        )

        var fullText = ""
        do {
            for try await token in await triageLLM.stream(
                prompt: prompt,
                shouldStopAfterAppending: { TriageOrchestrator.isTriageGenerationComplete($0) }
            ) {
                if Task.isCancelled { return }
                fullText.append(token)
                send(.token(token))
            }
        } catch {
            send(.failed(NSLocalizedString("triage.failure",
                value: "Triage model failed. Please try again.", comment: "")))
            return
        }

        // 4) Parse machine JSON and apply condition_mapping cross-check
        send(.stage(.parsing))
        let (displayProse, jsonSlice) = TriageOrchestrator.splitProseAndMetaBlock(fullText)
        let polishedProse = TriageDisplayFormatting.compactRepeatedProse(displayProse)
        var result: TriageResult
        if let json = jsonSlice, let parsed = TriageOrchestrator.parseTriageJSON(json, originalInput: transcript) {
            result = TriageResult(
                inputSymptoms: transcript,
                severity: parsed.severity,
                severityConfidence: parsed.severityConfidence,
                summary: !polishedProse.isEmpty ? polishedProse : TriageDisplayFormatting.compactRepeatedProse(parsed.summary),
                recommendedActions: parsed.recommendedActions,
                redFlags: parsed.redFlags,
                candidates: parsed.candidates,
                medicalEnrichment: nil
            )
        } else if let parsed = TriageOrchestrator.parseTriageJSON(fullText, originalInput: transcript) {
            // Legacy: model returned only JSON
            result = TriageResult(
                inputSymptoms: transcript,
                severity: parsed.severity,
                severityConfidence: parsed.severityConfidence,
                summary: TriageDisplayFormatting.compactRepeatedProse(parsed.summary),
                recommendedActions: parsed.recommendedActions,
                redFlags: parsed.redFlags,
                candidates: parsed.candidates,
                medicalEnrichment: nil
            )
        } else {
            send(.warning(NSLocalizedString("triage.parseFallback",
                value: "Could not read structured follow-up from the model. The message above is still shown.",
                comment: "")))
            result = TriageResult(
                inputSymptoms: transcript,
                severity: baseSeverity == .unknown ? .urgentCare : baseSeverity,
                severityConfidence: 0.4,
                summary: !polishedProse.isEmpty
                    ? polishedProse
                    : TriageOrchestrator.firstParagraph(
                        TriageDisplayFormatting.compactRepeatedProse(
                            TriageOrchestrator.stripCodeFences(fullText)),
                        fallback: NSLocalizedString("triage.noOutput",
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
            medicalEnrichment: nil
        )

        await persistence.appendHistory(HistoryEntry(result: finalResult))

        send(.stage(.done))
        send(.finished(finalResult))
    }

    /// Hides the machine JSON block (and the marker) while the model streams.
    public static func displayableProsePrefix(from raw: String) -> String {
        if let r = raw.range(of: Self.metaBlockMarker, options: .caseInsensitive) {
            return String(raw[..<r.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw
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

    /// Splits the model output into the user-facing prose and an optional
    /// JSON object after the `MEDIMATCH_JSON` marker.
    static func splitProseAndMetaBlock(_ raw: String) -> (prose: String, json: String?) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = raw.range(of: Self.metaBlockMarker, options: .caseInsensitive) {
            let before = String(raw[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            var after = String(raw[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if after.hasPrefix("\n") { after = String(after.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines) }
            if after.hasPrefix("{") { return (before, after) }
            if let b = after.range(of: "{"), let e = after.range(of: "}", options: .backwards) {
                return (before, String(after[b.lowerBound..<e.upperBound]))
            }
            return (before, after.isEmpty ? nil : after)
        }
        return (trimmed, nil)
    }

    /// Parses the strict-JSON object for severity and lists. Tolerates minor
    /// wrapper artifacts.
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
