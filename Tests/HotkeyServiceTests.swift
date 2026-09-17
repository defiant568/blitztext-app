import Cocoa
import Carbon

// Only model discovery is stubbed; the shortcut service and settings use production code.
enum LocalTranscriptionService {
    static let recommendedFastModelName = "test-model"
}

@main
struct HotkeyServiceTests {
    @MainActor
    static func main() {
        let service = HotkeyService()
        var events: [String] = []
        service.onHotkeyEvent = {
            switch $0 {
            case .down(let type): events.append("down:\(type.rawValue)")
            case .up(let type): events.append("up:\(type.rawValue)")
            case .cancel: events.append("cancel")
            }
        }
        func expect(_ expected: [String]) {
            precondition(events == expected, "Expected \(expected), got \(events)")
            events.removeAll()
        }

        service.handleF5(isDown: true)
        service.handleF5(isDown: true)
        service.handleModifiers([.shift])
        service.handleF5(isDown: false)
        service.handleF5(isDown: false)
        expect(["down:transcription", "up:transcription"])

        for _ in 0..<2 {
            service.handleF5(isDown: true)
            service.handleF5(isDown: false)
        }
        expect(["down:transcription", "up:transcription", "down:transcription", "up:transcription"])

        service.handleF5(isDown: true)
        service.handleEscape()
        service.handleF5(isDown: true)
        service.handleF5(isDown: false)
        expect(["down:transcription", "cancel"])

        let combos: [(NSEvent.ModifierFlags, WorkflowType)] = [
            ([.function, .shift], .transcription),
            ([.function, .shift, .control], .localTranscription),
            ([.function, .control], .textImprover),
            ([.function, .option], .dampfAblassen),
            ([.function, .command], .emojiText)
        ]
        for (flags, type) in combos {
            service.handleModifiers(flags)
            service.handleModifiers(flags)
            service.handleF5(isDown: true)
            service.handleF5(isDown: false)
            service.handleModifiers([])
            expect(["down:\(type.rawValue)", "up:\(type.rawValue)"])
        }

        service.handleF5(isDown: true)
        service.handleModifiers([.function, .shift])
        service.handleModifiers([])
        service.handleF5(isDown: false)
        expect(["down:transcription", "up:transcription"])

        service.handleF5(isDown: true)
        service.stop()
        service.handleF5(isDown: false)
        expect(["down:transcription"])
        service.handleF5(isDown: true)
        service.handleF5(isDown: false)
        expect(["down:transcription", "up:transcription"])
        print("PASS: F5 hold/repeat/toggle pairs, Escape, overlapping shortcuts, legacy shortcuts, reset")

        if CommandLine.arguments.contains("--registration") {
            _ = NSApplication.shared
            service.start()
            precondition(service.f5RegistrationError == nil, service.f5RegistrationError ?? "")
            for kind in [kEventHotKeyPressed, kEventHotKeyReleased] {
                var event: EventRef?
                precondition(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kind), 0, 0, &event) == noErr)
                var identifier = EventHotKeyID(signature: 0x42545854, id: 5)
                precondition(SetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    MemoryLayout<EventHotKeyID>.size, &identifier
                ) == noErr)
                precondition(SendEventToEventTarget(event, GetApplicationEventTarget()) == noErr)
                ReleaseEvent(event)
            }
            expect(["down:transcription", "up:transcription"])
            service.stop()
            var conflictingHotKey: EventHotKeyRef?
            precondition(RegisterEventHotKey(
                UInt32(kVK_F5), 0, EventHotKeyID(signature: 0x54455354, id: 1),
                GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &conflictingHotKey
            ) == noErr)
            service.start()
            precondition(service.f5RegistrationError != nil)
            service.stop()
            UnregisterEventHotKey(conflictingHotKey)
            service.start()
            precondition(service.f5RegistrationError == nil)
            service.stop()
            print("PASS: macOS F5 registration, native press/release dispatch, conflict detection, unregister/restart")
        }
    }
}
