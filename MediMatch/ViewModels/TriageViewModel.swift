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
    /// Set while a run is in progress; used for cancel / failure restore.
    private var inFlightUserMessageId: UUID?
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
        streamAccum = ""
        inlineWarning = nil
        lastResult = nil
        inFlightUserMessageId = nil
        pendingTypedBackup = nil
        phase = .idle
    }

    public func submit() {
        let text = composedInput
        guard !text.isEmpty else { return }
        inlineWarning = nil
        streamAccum = ""
        lastResult = nil
        pendingTypedBackup = input
        let newUser = TriageChatTurn(role: .user, text: text)
        inFlightUserMessageId = newUser.id
        let pipeline = [newUser]
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
        inFlightUserMessageId = nil
        if isRunning, let backup = pendingTypedBackup {
            input = backup
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
            case .generating: phase = .generating(progress: "")
            case .parsing:
                streamAccum = TriageOrchestrator.displayableProsePrefix(from: streamAccum)
                phase = .parsing
            case .done:       break
            }
        case .token(let token):
            // Accumulate for the orchestrator only; the UI shows a spinner until
            // a parsed `TriageResult` is ready (no raw token stream).
            streamAccum.append(token)
        case .warning(let message):
            inlineWarning = message
        case .finished(let result):
            lastResult = result
            inFlightUserMessageId = nil
            pendingTypedBackup = nil
            streamAccum = ""
            phase = .finished(result)
        case .failed(let message):
            streamAccum = ""
            if let uid = userIdForFailure, uid == inFlightUserMessageId, let backup = pendingTypedBackup {
                input = backup
                pendingTypedBackup = nil
            }
            inFlightUserMessageId = nil
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
