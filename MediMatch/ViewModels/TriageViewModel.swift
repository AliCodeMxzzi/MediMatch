import Foundation
import SwiftUI
import Combine

/// SwiftUI-facing view model for the triage flow.
///
/// Single-shot: each run sends one user message to the on-device model and
/// receives one triage result (no follow-up chat with the model).
@MainActor
public final class TriageViewModel: ObservableObject {

    public enum Phase: Equatable {
        case idle
        case validating
        case classifying
        case generating(progress: String)
        case parsing
        case finished(TriageResult)
        case failed(String)
    }

    @Published public var input: String = ""
    @Published public var selectedSymptomIds: Set<String> = []
    @Published public private(set) var phase: Phase = .idle
    @Published public private(set) var chatTurns: [TriageChatTurn] = []
    @Published public private(set) var streamingText: String = ""
    @Published public private(set) var lastResult: TriageResult?
    @Published public private(set) var inlineWarning: String?

    @Published public var promptGuardStatus: ModelStatus = .idle
    @Published public var triageStatus:      ModelStatus = .idle

    public var canSubmit: Bool {
        if case .idle = phase { return !composedInput.isEmpty }
        if case .finished = phase { return !composedInput.isEmpty }
        if case .failed = phase { return !composedInput.isEmpty }
        return false
    }

    public var isRunning: Bool {
        switch phase {
        case .idle, .finished, .failed: return false
        default: return true
        }
    }

    public var hasConversation: Bool {
        !chatTurns.isEmpty
    }

    public var composedInput: String {
        var lines: [String] = []
        let selected = SymptomCatalog.all.filter { selectedSymptomIds.contains($0.id) }
        if !selected.isEmpty {
            let names = selected.map { $0.displayName }.joined(separator: ", ")
            lines.append(String(format: NSLocalizedString("triage.composed.selected",
                value: "Selected: %@", comment: ""), names))
        }
        let typed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty {
            lines.append(typed)
        }
        return lines.joined(separator: "\n")
    }

    private let orchestrator: TriageOrchestrator
    private let promptGuard:  PromptGuardService
    private let triage:       TriageLLMService
    private let settings:     AccessibilitySettings

    private var streamAccum: String = ""
    /// Raw text in the text editor before a send, for undo on cancel/failure.
    private var pendingTypedBackup: String?
    private var pollTask: Task<Void, Never>?
    private var streamTask: Task<Void, Never>?

    public init(
        orchestrator: TriageOrchestrator,
        promptGuard:  PromptGuardService,
        triage:       TriageLLMService,
        settings:     AccessibilitySettings
    ) {
        self.orchestrator = orchestrator
        self.promptGuard  = promptGuard
        self.triage       = triage
        self.settings     = settings
        self.pollTask = Task { [weak self] in await self?.pollStatuses() }
    }

    deinit {
        pollTask?.cancel()
        streamTask?.cancel()
    }

    public func toggleSymptom(_ id: String) {
        if selectedSymptomIds.contains(id) {
            selectedSymptomIds.remove(id)
        } else {
            selectedSymptomIds.insert(id)
        }
    }

    public func reset() {
        streamTask?.cancel()
        streamTask = nil
        input = ""
        selectedSymptomIds = []
        chatTurns = []
        streamAccum = ""
        streamingText = ""
        inlineWarning = nil
        lastResult = nil
        pendingTypedBackup = nil
        phase = .idle
    }

    public func submit() {
        let text = composedInput
        guard !text.isEmpty else { return }
        inlineWarning = nil
        streamAccum = ""
        streamingText = ""
        pendingTypedBackup = input
        let newUser = TriageChatTurn(role: .user, text: text)
        // Single user message per run; previous back-and-forth is not passed to the model.
        let pipeline = [newUser]
        chatTurns = [newUser]
        input = ""
        phase = .validating
        streamTask?.cancel()
        let stream = orchestrator
        let locale = settings.preferredLocale
        let pipelineSnapshot = pipeline
        let userId = newUser.id
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await update in await stream.run(chatTurns: pipelineSnapshot, locale: locale) {
                if Task.isCancelled { break }
                await self.apply(update, userIdForFailure: userId)
            }
        }
    }

    public func cancel() {
        streamTask?.cancel()
        streamTask = nil
        Task { [orchestrator] in await orchestrator.cancel() }
        if case .finished = phase {
            return
        }
        streamAccum = ""
        streamingText = ""
        if let last = chatTurns.last, last.role == .user {
            chatTurns.removeLast()
            if let backup = pendingTypedBackup {
                input = backup
            }
            pendingTypedBackup = nil
        }
        phase = .idle
    }

    private func apply(
        _ update: TriageOrchestrator.StreamUpdate,
        userIdForFailure: UUID? = nil
    ) async {
        switch update.kind {
        case .stage(let stage):
            switch stage {
            case .validating: phase = .validating
            case .classifying: phase = .classifying
            case .generating: phase = .generating(progress: streamingText)
            case .parsing:
                streamAccum = TriageOrchestrator.displayableProsePrefix(from: streamAccum)
                streamingText = streamAccum
                phase = .parsing
            case .done:       break
            }
        case .token(let token):
            streamAccum.append(token)
            let visible = TriageOrchestrator.displayableProsePrefix(from: streamAccum)
            streamingText = visible
            if case .generating = phase {
                phase = .generating(progress: streamingText)
            }
        case .warning(let message):
            inlineWarning = message
        case .finished(let result):
            lastResult = result
            pendingTypedBackup = nil
            if !result.summary.isEmpty {
                chatTurns.append(TriageChatTurn(role: .assistant, text: result.summary))
            } else {
                let fallback = TriageOrchestrator.displayableProsePrefix(from: streamAccum)
                if !fallback.isEmpty {
                    chatTurns.append(TriageChatTurn(role: .assistant, text: fallback))
                }
            }
            streamAccum = ""
            streamingText = ""
            phase = .finished(result)
        case .failed(let message):
            streamAccum = ""
            streamingText = ""
            if let uid = userIdForFailure, chatTurns.last?.id == uid, chatTurns.last?.role == .user {
                chatTurns.removeLast()
                if let backup = pendingTypedBackup { input = backup }
                pendingTypedBackup = nil
            }
            inlineWarning = nil
            phase = .failed(message)
        }
    }

    private func pollStatuses() async {
        while !Task.isCancelled {
            self.promptGuardStatus = await promptGuard.status
            self.triageStatus      = await triage.status
            try? await Task.sleep(nanoseconds: 600_000_000)
        }
    }
}
