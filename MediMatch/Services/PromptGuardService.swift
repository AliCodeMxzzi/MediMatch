import Foundation
import ZeticMLange

/// On-device prompt-guard classifier backed by `jathin-zetic/llama_prompt_guard`.
///
/// Implements both `symptom_input_processing` (validate the user's input) and
/// `condition_mapping` (sanity-check candidate output before showing it).
///
/// Threading: All inference happens on a serial background queue. The public
/// surface is async and returns to the caller's actor.
public actor PromptGuardService {

    public struct Verdict: Sendable, Equatable {
        public let label: Label
        public let score: Float
        public let raw: [Float]

        public enum Label: String, Sendable, Equatable {
            case safe
            case injection
            case unsafe
            case unknown
        }
    }

    public private(set) var status: ModelStatus = .idle
    public private(set) var telemetry: InferenceTelemetry = .init()

    private let tokenizer: PromptGuardTokenizer
    private var model: ZeticMLangeModel?
    private var warmUpTask: Task<Void, Never>?

    /// Block sizes for the input/attention tensors. Keep aligned with
    /// `PromptGuardTokenizer.sequenceLength`.
    private let sequenceLength: Int

    public init(tokenizer: PromptGuardTokenizer = .init()) {
        self.tokenizer = tokenizer
        self.sequenceLength = PromptGuardTokenizer.sequenceLength
    }

    /// Lazily downloads / initializes the model. Safe to call repeatedly;
    /// concurrent callers share a single in-flight warm-up so we never spin
    /// up two `ZeticMLangeModel(...)` constructors at the same time.
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

    /// The actual init. The synchronous `ZeticMLangeModel(...)` constructor
    /// performs blocking network + file I/O internally, so we run it on a
    /// detached task. That lets the actor keep servicing `status` reads and
    /// other calls (e.g. `classify`) during the download.
    private func performWarmUp(onProgress: @Sendable @escaping (Double) -> Void) async {
        status = .downloading(progress: 0)
        let key  = AppConfig.personalKeyForSDK()
        let name = AppConfig.ModelID.promptGuard

        do {
            let m = try await Task.detached(priority: .utility) { () throws -> ZeticMLangeModel in
                try ZeticMLangeModel(
                    personalKey: key,
                    name: name,
                    modelMode: .RUN_AUTO,
                    onDownload: { progress in
                        let p = Self.normalizeProgress(progress)
                        onProgress(p)
                        // Hop back to the actor; otherwise UI stays on "0%%" forever.
                        Task { [weak self] in
                            await self?.setDownloadProgress(p)
                        }
                    }
                )
            }.value
            self.model = m
            self.status = .ready
            self.telemetry.lastError = nil
        } catch {
            self.model = nil
            self.status = .failed(message: Self.sanitize(error))
            self.telemetry.lastError = Self.sanitize(error)
        }
    }

    /// Classifies `text`. If the model is not yet ready, returns
    /// `Verdict(label: .unknown, score: 0)` so callers can fall back to the
    /// heuristic filter result alone.
    public func classify(_ text: String) async -> Verdict {
        if model == nil { await warmUp() }
        guard let model else {
            return Verdict(label: .unknown, score: 0, raw: [])
        }

        let (ids, mask) = tokenizer.encode(text)
        let inputTensor = makeInt32Tensor(ids)
        let maskTensor  = makeInt32Tensor(mask)

        let start = Date()
        status = .running
        do {
            let outputs = try model.run(inputs: [inputTensor, maskTensor])
            telemetry.lastLatencyMillis = Int(Date().timeIntervalSince(start) * 1000)
            telemetry.totalCalls += 1
            telemetry.lastError = nil
            status = .ready

            guard let first = outputs.first else {
                return Verdict(label: .unknown, score: 0, raw: [])
            }
            let logits = decodeFloat32(first.data)
            let probs  = softmax(logits)
            return interpret(probs)
        } catch {
            status = .ready
            telemetry.lastError = Self.sanitize(error)
            return Verdict(label: .unknown, score: 0, raw: [])
        }
    }

    public func reset() {
        // ZeticMLangeModel does not expose forceDeinit at this layer; rely on
        // ARC. Setting to nil drops our reference so the SDK can clean up.
        model = nil
        status = .idle
    }

    // MARK: - Private helpers

    private func setDownloadProgress(_ p: Double) {
        status = .downloading(progress: Self.clamp01(p))
    }

    private static func normalizeProgress(_ value: some BinaryFloatingPoint) -> Double {
        let d = Double(value)
        // SDK may report 0…1 or 0…100.
        return d > 1.0 ? d / 100.0 : d
    }

    private static func clamp01(_ p: Double) -> Double {
        min(1, max(0, p))
    }

    private func makeInt32Tensor(_ values: [Int32]) -> Tensor {
        let data = values.withUnsafeBufferPointer { Data(buffer: $0) }
        return Tensor(
            data: data,
            dataType: BuiltinDataType.int32,
            shape: [1, sequenceLength]
        )
    }

    private func decodeFloat32(_ data: Data) -> [Float] {
        let count = data.count / MemoryLayout<Float>.size
        return data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self).prefix(count))
        }
    }

    private func softmax(_ logits: [Float]) -> [Float] {
        guard !logits.isEmpty else { return [] }
        let maxLogit = logits.max() ?? 0
        let exps = logits.map { expf($0 - maxLogit) }
        let sum  = exps.reduce(0, +)
        guard sum > 0 else { return Array(repeating: 1 / Float(logits.count), count: logits.count) }
        return exps.map { $0 / sum }
    }

    /// Maps the classifier's output to a verdict. Llama Prompt Guard models
    /// commonly emit 3 logits: `[benign, injection, jailbreak]` (the latter
    /// two flagged as unsafe). We treat the highest of injection/jailbreak as
    /// the `injection` score and everything else as `safe`.
    private func interpret(_ probs: [Float]) -> Verdict {
        guard !probs.isEmpty else {
            return Verdict(label: .unknown, score: 0, raw: probs)
        }
        if probs.count == 1 {
            // Single sigmoid head: high = unsafe.
            let p = probs[0]
            return Verdict(label: p > 0.5 ? .unsafe : .safe, score: p, raw: probs)
        }
        if probs.count == 2 {
            // [safe, unsafe]
            return probs[1] > probs[0]
                ? Verdict(label: .unsafe, score: probs[1], raw: probs)
                : Verdict(label: .safe,   score: probs[0], raw: probs)
        }
        // Default: assume index 0 is "safe", any other index is "injection/unsafe".
        let safeProb = probs[0]
        let unsafeIdx = probs.dropFirst().enumerated().max(by: { $0.element < $1.element })
        let unsafeProb = unsafeIdx?.element ?? 0
        if unsafeProb > safeProb {
            return Verdict(label: .injection, score: unsafeProb, raw: probs)
        } else {
            return Verdict(label: .safe, score: safeProb, raw: probs)
        }
    }

    private static func sanitize(_ error: Error) -> String {
        // Avoid leaking key material into logs / UI.
        let raw = String(describing: error)
        let key = AppConfig.personalKeyForSDK()
        return raw.replacingOccurrences(of: key, with: "<redacted>")
    }
}
