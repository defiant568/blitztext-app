import Cocoa
import Carbon
import Observation

enum HotkeyMode: String, Codable, CaseIterable, Identifiable {
    case hold    // Tasten halten = aufnehmen, loslassen = stoppen
    case toggle  // Einmal drücken = starten, nochmal/Escape = stoppen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hold: return "Halten"
        case .toggle: return "Drücken"
        }
    }

    var description: String {
        switch self {
        case .hold: return "Tasten halten zum Aufnehmen, loslassen zum Stoppen"
        case .toggle: return "Einmal drücken zum Starten, nochmal oder Escape zum Stoppen"
        }
    }
}

enum HotkeyEvent {
    case down(WorkflowType)  // Keys pressed
    case up(WorkflowType)    // Keys released (for hold mode)
    case cancel              // Escape pressed
}

@Observable
@MainActor
final class HotkeyService {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var keyMonitor: Any?
    private var activeCombo: WorkflowType?  // Which combo is currently held
    private var f5HotKey: EventHotKeyRef?
    private var f5Handler: EventHandlerRef?
    private var isF5Down = false
    private var f5Triggered = false

    private(set) var f5RegistrationError: String?

    var onHotkeyEvent: ((HotkeyEvent) -> Void)?

    func start() {
        stop()
        registerF5()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.handleFlags(event)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            Task { @MainActor in
                if event.type == .flagsChanged {
                    self?.handleFlags(event)
                } else if event.keyCode == 53 {
                    self?.handleEscape()
                }
            }
            return event
        }
        // Escape key monitor for toggle mode
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                if event.keyCode == 53 { // Escape
                    self?.handleEscape()
                }
            }
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        globalMonitor = nil
        localMonitor = nil
        keyMonitor = nil
        if let f5HotKey { UnregisterEventHotKey(f5HotKey) }
        if let f5Handler { RemoveEventHandler(f5Handler) }
        f5HotKey = nil
        f5Handler = nil
        activeCombo = nil
        isF5Down = false
        f5Triggered = false
        f5RegistrationError = nil
    }

    private func registerF5() {
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier
                )
                guard status == noErr, identifier.signature == 0x42545854, identifier.id == 5 else {
                    return OSStatus(eventNotHandledErr)
                }
                let service = Unmanaged<HotkeyService>.fromOpaque(context).takeUnretainedValue()
                // Application event handlers run on the main thread.
                MainActor.assumeIsolated {
                    service.handleF5(isDown: GetEventKind(event) == UInt32(kEventHotKeyPressed))
                }
                return noErr
            },
            eventTypes.count, &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(), &f5Handler
        )
        guard handlerStatus == noErr else {
            f5RegistrationError = "F5 konnte nicht aktiviert werden (\(handlerStatus))."
            return
        }
        let status = RegisterEventHotKey(
            UInt32(kVK_F5), 0, EventHotKeyID(signature: 0x42545854, id: 5),
            GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &f5HotKey
        )
        if status != noErr {
            f5RegistrationError = "F5 ist nicht verfügbar, möglicherweise bereits belegt (\(status))."
            if let f5Handler { RemoveEventHandler(f5Handler) }
            f5Handler = nil
        }
    }

    func handleF5(isDown: Bool) {
        if isDown {
            guard !isF5Down else { return }
            isF5Down = true
            guard activeCombo == nil else { return }
            f5Triggered = true
            onHotkeyEvent?(.down(.transcription))
        } else {
            isF5Down = false
            guard f5Triggered else { return }
            f5Triggered = false
            onHotkeyEvent?(.up(.transcription))
        }
    }

    private func handleFlags(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        handleModifiers(flags)
    }

    func handleModifiers(_ flags: NSEvent.ModifierFlags) {
        // F5 owns its press/release pair even when modifiers change while it is held.
        guard !f5Triggered else { return }

        // fn + Shift + Control -> local transcription
        if flags == [.function, .shift, .control] {
            if activeCombo == nil {
                activeCombo = .localTranscription
                onHotkeyEvent?(.down(.localTranscription))
            }
            return
        }

        // fn + Shift -> transcription
        if flags == [.function, .shift] {
            if activeCombo == nil {
                activeCombo = .transcription
                onHotkeyEvent?(.down(.transcription))
            }
            return
        }

        // fn + Control -> Textverbesserer
        if flags == [.function, .control] {
            if activeCombo == nil {
                activeCombo = .textImprover
                onHotkeyEvent?(.down(.textImprover))
            }
            return
        }

        // fn + Option -> Rage Mode
        if flags == [.function, .option] {
            if activeCombo == nil {
                activeCombo = .dampfAblassen
                onHotkeyEvent?(.down(.dampfAblassen))
            }
            return
        }

        // fn + Command -> Emoji Mode
        if flags == [.function, .command] {
            if activeCombo == nil {
                activeCombo = .emojiText
                onHotkeyEvent?(.down(.emojiText))
            }
            return
        }

        // Keys released -- fire up event
        if let combo = activeCombo {
            activeCombo = nil
            onHotkeyEvent?(.up(combo))
        }
    }

    func handleEscape() {
        activeCombo = nil
        f5Triggered = false
        onHotkeyEvent?(.cancel)
    }
}
