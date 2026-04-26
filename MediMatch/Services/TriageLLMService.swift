import Foundation
import ZeticMLange

/// Streaming triage LLM (see `AppConfig.ModelID.triageRecommender`).
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
    private var warmUpIsLoadFromCache: Bool = false

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
        if warmUpTask == task { warmUpTask = nil }
    }

    /// The synchronous SDK constructor performs blocking network + file I/O.
    /// We run it on a detached task so the actor stays responsive to
    /// `status` reads and `stream(prompt:)` calls during the download.
    private func performWarmUp(onProgress: @Sendable @escaping (Double) -> Void) async {
        warmUpIsLoadFromCache = ZeticModelInstallState.hasTriageWeightsInstalled()
        status = warmUpIsLoadFromCache
            ? .loading(progress: 0)
            : .downloading(progress: 0)
        let key  = AppConfig.personalKeyForSDK()
        let name = AppConfig.ModelID.triageRecommender

        do {
            let version = AppConfig.triageLLMModelVersion
            let m = try await Task.detached(priority: .utility) { () throws -> ZeticMLangeLLMModel in
                // Matches ZETIC automatic LLM init: version nil = latest for `name`.
                // See https://docs.zetic.ai/api-reference/ios/ZeticMLangeLLMModel
                try ZeticMLangeLLMModel(
                    personalKey: key,
                    name: name,
                    version: version,
                    modelMode: .RUN_AUTO,
                    initOption: LLMInitOption(
                        kvCacheCleanupPolicy: .CLEAN_UP_ON_FULL,
                        nCtx: AppConfig.triageLLMContextTokens
                    ),
                    onDownload: { progress in
                        let p = Self.normalizeProgress(progress)
                        onProgress(p)
                        Task { [weak self] in
                            await self?.setModelLoadProgress(p)
                        }
                    }
                )
            }.value
            self.model = m
            self.status = .ready
            self.telemetry.lastError = nil
            ZeticModelInstallState.markTriageWeightsInstalled()
        } catch {
            self.model = nil
            self.status = .failed(message: sanitize(error))
            self.telemetry.lastError = sanitize(error)
            ZeticModelInstallState.markTriageWeightsCleared()
        }
    }

    /// Streams tokens for `prompt`. Cancel by calling `stop()`.
    /// `shouldStopAfterAppending` is invoked with the full output so far (including the current
    /// token) to end generation early without cancel noise — e.g. once `MEDIMATCH_JSON` + JSON is complete.
    public func stream(
        prompt: String,
        shouldStopAfterAppending: @escaping @Sendable (String) -> Bool = { _ in false }
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                do {
                    try await self.runStream(
                        prompt: prompt,
                        shouldStopAfterAppending: shouldStopAfterAppending,
                        continuation: continuation
                    )
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

    /// Frees the loaded LLM to avoid holding two large models in RAM (OOM on
    /// iPhone). Artifacts stay on disk; the next `warmUp()` re-loads quickly.
    public func releaseFromMemory() async {
        generationTask?.cancel()
        generationTask = nil
        model?.forceDeinit()
        model = nil
        status = .onDevice
    }

    /// Performs the model warm-up + cleanUp + run + token loop in a way that
    /// yields each token to the continuation.
    private func runStream(
        prompt: String,
        shouldStopAfterAppending: @escaping @Sendable (String) -> Bool,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
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
            var accumulated = ""
            while true {
                if Task.isCancelled { break }
                let result = model.waitForNextToken()
                if result.generatedTokens == 0 { break }
                if !result.token.isEmpty {
                    accumulated.append(result.token)
                    continuation.yield(result.token)
                    if shouldStopAfterAppending(accumulated) {
                        try? model.cleanUp()
                        break
                    }
                }
                if result.generatedTokens >= AppConfig.triageLLMMaxOutputTokens {
                    try? model.cleanUp()
                    break
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

    private func setModelLoadProgress(_ p: Double) {
        let q = Self.clamp01(p)
        status = warmUpIsLoadFromCache
            ? .loading(progress: q)
            : .downloading(progress: q)
    }

    private static func normalizeProgress(_ value: some BinaryFloatingPoint) -> Double {
        let d = Double(value)
        return d > 1.0 ? d / 100.0 : d
    }

    private static func clamp01(_ p: Double) -> Double {
        min(1, max(0, p))
    }
}
