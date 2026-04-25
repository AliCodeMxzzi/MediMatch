import Foundation
import ZeticMLange

/// Streaming medical-domain LLM backed by `Steve/Medgemma-1.5-4b-it`.
///
/// Implements the `local_data_management` task: summarizes the user's
/// locally-stored history and active medications and surfaces possible
/// drug-symptom interactions in plain language. Output is plain text.
public actor MedicalLLMService {

    public private(set) var status: ModelStatus = .idle
    public private(set) var telemetry: InferenceTelemetry = .init()

    private var model: ZeticMLangeLLMModel?
    private var generationTask: Task<Void, Never>?
    private var warmUpTask: Task<Void, Never>?

    public init() {}

    deinit {
        model?.forceDeinit()
    }

    /// Lazily downloads / initializes the model. Concurrent callers share a
    /// single in-flight warm-up so we never construct two LLMs at once.
    public func warmUp(onProgress: @Sendable @escaping (Double) -> Void = { _ in }) async {
        if model != nil { return }
        if let existing = warmUpTask {
            await existing.value
            return
        }
        let task = Task { [weak self] in
            await self?.performWarmUp(onProgress: onProgress)
        }
        warmUpTask = task
        await task.value
        if warmUpTask === task { warmUpTask = nil }
    }

    /// The synchronous SDK constructor performs blocking network + file I/O.
    /// We run it on a detached task so the actor stays responsive to
    /// `status` reads and `enrich(prompt:)` calls during the download.
    private func performWarmUp(onProgress: @Sendable @escaping (Double) -> Void) async {
        status = .downloading(progress: 0)
        let key  = AppConfig.personalKeyForSDK()
        let name = AppConfig.ModelID.medicalAssistant

        do {
            let m = try await Task.detached(priority: .utility) { () throws -> ZeticMLangeLLMModel in
                try ZeticMLangeLLMModel(
                    personalKey: key,
                    name: name,
                    modelMode: .RUN_AUTO,
                    initOption: LLMInitOption(
                        kvCacheCleanupPolicy: .CLEAN_UP_ON_FULL,
                        nCtx: 4096
                    ),
                    onDownload: { progress in
                        onProgress(Double(progress))
                    }
                )
            }.value
            self.model = m
            self.status = .ready
            self.telemetry.lastError = nil
        } catch {
            self.model = nil
            self.status = .failed(message: sanitize(error))
            self.telemetry.lastError = sanitize(error)
        }
    }

    /// Runs once and returns the full text. Used for the post-triage
    /// enrichment block which is short by design.
    public func enrich(prompt: String, maxTokens: Int = 384) async throws -> String {
        if model == nil { await warmUp() }
        guard let model else {
            throw NSError(domain: "MediMatch.Medical", code: 1, userInfo: [NSLocalizedDescriptionKey: "Medical model is unavailable."])
        }

        try model.cleanUp()

        let start = Date()
        status = .running

        do {
            _ = try model.run(prompt)
            telemetry.totalCalls += 1
            var output = ""
            var produced = 0
            while produced < maxTokens {
                if Task.isCancelled { break }
                let result = model.waitForNextToken()
                if result.generatedTokens == 0 { break }
                if !result.token.isEmpty {
                    output.append(result.token)
                    produced += 1
                }
            }
            telemetry.lastLatencyMillis = Int(Date().timeIntervalSince(start) * 1000)
            status = .ready
            return output
        } catch {
            status = .ready
            telemetry.lastError = sanitize(error)
            throw error
        }
    }

    public func stop() {
        generationTask?.cancel()
        generationTask = nil
        try? model?.cleanUp()
    }

    private func sanitize(_ error: Error) -> String {
        String(describing: error).replacingOccurrences(of: AppConfig.personalKeyForSDK(), with: "<redacted>")
    }
}
