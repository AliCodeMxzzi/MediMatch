import Foundation

/// Serializes `ZeticMLangeLLMModel` initialisation for Triage and Medical.
///
/// Even when one model's weights are on disk, the native constructor is heavy;
/// running two in parallel can over-allocate or race the SDK. All warm-ups for
/// these two LLMs should route through this gate.
public actor ZeticLLMInitGate {
    public static let shared = ZeticLLMInitGate()
    public init() {}

    public func run<T: Sendable>(
        _ work: @Sendable @escaping () async throws -> T
    ) async rethrows -> T {
        try await work()
    }
}
