import Foundation

/// Lightweight, observable status for any on-device model.
public enum ModelStatus: Equatable, Sendable {
    case idle
    case downloading(progress: Double)
    case ready
    /// Weights are on device (ZETIC cache) but the model is not in RAM, so
    /// a later `warmUp()` is fast. Used for Medical LLM after a prefetch
    /// unload to avoid OOM with two large LLMs at once.
    case onDevice
    case running
    case failed(message: String)

    public var isReady: Bool {
        switch self {
        case .ready, .onDevice: return true
        default: return false
        }
    }

    public var isBusy: Bool {
        switch self {
        case .downloading, .running: return true
        default: return false
        }
    }

    public var displayDescription: String {
        switch self {
        case .idle:
            return NSLocalizedString("model.status.idle", value: "Idle", comment: "")
        case .downloading(let p):
            let pct = Int((p * 100).rounded())
            return String(format: NSLocalizedString("model.status.downloading",
                value: "Downloading… %d%%", comment: ""), pct)
        case .ready:
            return NSLocalizedString("model.status.ready", value: "Ready", comment: "")
        case .onDevice:
            return NSLocalizedString("model.status.onDevice",
                value: "On device (loads when used)", comment: "Model weights cached; not in memory")
        case .running:
            return NSLocalizedString("model.status.running", value: "Thinking…", comment: "")
        case .failed(let message):
            return String(format: NSLocalizedString("model.status.failed",
                value: "Error: %@", comment: ""), message)
        }
    }
}

/// Records latency for each inference call, used by the Settings screen.
public struct InferenceTelemetry: Sendable, Equatable {
    public var lastLatencyMillis: Int = 0
    public var totalCalls: Int = 0
    public var lastError: String? = nil
}
