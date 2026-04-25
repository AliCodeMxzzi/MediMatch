import Foundation
import Speech
import AVFoundation

/// Transcribes the user's voice using Apple's on-device speech recognizer.
/// We require `requiresOnDeviceRecognition = true` so audio never leaves the
/// device. If the device cannot satisfy that constraint, we fail loudly.
@MainActor
public final class SpeechRecognitionService: NSObject, ObservableObject {

    public enum Error: Swift.Error, LocalizedError {
        case unauthorized
        case unavailable
        case onDeviceUnavailable
        case audioEngineFailed
        case noRecognizer

        public var errorDescription: String? {
            switch self {
            case .unauthorized:
                return NSLocalizedString("speech.error.unauthorized",
                    value: "Microphone or speech permissions are denied.", comment: "")
            case .unavailable:
                return NSLocalizedString("speech.error.unavailable",
                    value: "Speech recognition is unavailable on this device.", comment: "")
            case .onDeviceUnavailable:
                return NSLocalizedString("speech.error.onDevice",
                    value: "On-device recognition is unavailable for this language.", comment: "")
            case .audioEngineFailed:
                return NSLocalizedString("speech.error.audio",
                    value: "Couldn't start the audio engine.", comment: "")
            case .noRecognizer:
                return NSLocalizedString("speech.error.recognizer",
                    value: "No speech recognizer for the current locale.", comment: "")
            }
        }
    }

    @Published public private(set) var transcript: String = ""
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var lastError: String?

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    public override init() {
        super.init()
    }

    public func requestAuthorization() async -> Bool {
        let speechAuth = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        guard speechAuth == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    public func start(locale: Locale = .current) throws {
        guard !isRecording else { return }
        transcript = ""
        lastError = nil

        let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer()
        guard let recognizer else { throw Error.noRecognizer }
        guard recognizer.isAvailable else { throw Error.unavailable }
        guard recognizer.supportsOnDeviceRecognition else { throw Error.onDeviceUnavailable }

        self.recognizer = recognizer

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw Error.audioEngineFailed
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = true
        self.request = req

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            throw Error.audioEngineFailed
        }

        isRecording = true
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stop()
                }
            }
        }
    }

    public func stop() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    public func reset() {
        transcript = ""
        lastError = nil
    }
}
