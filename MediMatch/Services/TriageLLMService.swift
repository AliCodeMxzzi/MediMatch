import Foundation
import ZeticMLange

/// Streaming triage LLM backed by `google/gemma-3n-E2B-it`.
///
/// Implements the `recommendation_system` task. Tokens stream in via an
/// `AsyncThrowingStream`; the orchestrator parses the trailing JSON.
///
/// Cleanup contract (per ZETIC docs): we call `cleanUp()` before each new
/// `run(prompt:)`, when the user cancels, and when this service is released.
public actor TriageLLMService {

    public private(set) var status: ModelStatus = .idle
    public private(set) var telemetry: InferenceTelemetry = .init()

    private var model: ZeticMLangeLLMModel?
    private var generationTask: Task<Void, Never>?
    private var warmUpTask: Task<Void, Never>?

    public init() {}

    deinit {
        // Best-effort cleanup; runs synchronously on actor isolation release.
        // forceDeinit is non-throwing.
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
            guard let self else { return }
            await self.performWarmUp(onProgress: onProgress)
        }
        warmUpTask = task
        await task.value
        if warmUpTask === task { warmUpTask = nil }
    }

    /// The synchronous SDK constructor performs blocking network + file I/O.
    /// We run it on a detached task so the actor stays responsive to
    /// `status` reads and `stream(prompt:)` calls during the download.
    private func performWarmUp(onProgress: @Sendable @escaping (Double) -> Void) async {
        status = .downloading(progress: 0)
        let key  = AppConfig.personalKeyForSDK()
        let name = AppConfig.ModelID.triageRecommender

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

    /// Streams tokens for `prompt`. Cancel by calling `stop()`.
    public func stream(prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                do {
                    try await self.runStream(prompt: prompt, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            self.generationTask = task
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func stop() {
        generationTask?.cancel()
        generationTask = nil
        // Best-effort cleanup so the next call starts from a fresh KV cache.
        try? model?.cleanUp()
    }

    /// Performs the model warm-up + cleanUp + run + token loop in a way that
    /// yields each token to the continuation.
    private func runStream(prompt: String, continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        if model == nil { await warmUp() }
        guard let model else {
            throw NSError(domain: "MediMatch.Triage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Triage model is unavailable."])
        }

        // Mandatory cleanup contract: clear context before a new run.
        try model.cleanUp()

        let start = Date()
        status = .running

        do {
            _ = try model.run(prompt)
            telemetry.totalCalls += 1

            // Token loop. Apple recommends running blocking SDK calls off the
            // main actor; we are inside Task.detached already.
            while true {
                if Task.isCancelled { break }
                let result = model.waitForNextToken()
                if result.generatedTokens == 0 { break }
                if !result.token.isEmpty {
                    continuation.yield(result.token)
                }
            }
            telemetry.lastLatencyMillis = Int(Date().timeIntervalSince(start) * 1000)
            status = .ready
        } catch {
            status = .ready
            telemetry.lastError = sanitize(error)
            throw error
        }
    }

    private func sanitize(_ error: Error) -> String {
        String(describing: error).replacingOccurrences(of: AppConfig.personalKeyForSDK(), with: "<redacted>")
    }
}
