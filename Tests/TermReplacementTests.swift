import Foundation

// Only model discovery and the hotkey mode are stubbed; the replacement logic and settings use production code.
enum LocalTranscriptionService {
    static let recommendedFastModelName = "test-model"
}

enum HotkeyMode: String, Codable {
    case hold
}

@main
struct TermReplacementTests {
    static func main() throws {
        func expect(_ text: String, _ replacements: [TermReplacement], _ expected: String) {
            let result = TermReplacement.apply(replacements, to: text)
            precondition(result == expected, "Expected \"\(expected)\", got \"\(result)\"")
        }

        let blitztext = TermReplacement(from: "Blutztext", to: "Blitztext")
        expect("Ich teste Blutztext heute.", [blitztext], "Ich teste Blitztext heute.")
        expect("blutztext, BLUTZTEXT!", [blitztext], "Blitztext, Blitztext!")
        expect("Blutztexte bleiben.", [blitztext], "Blutztexte bleiben.")
        expect("Ein Blutztext-Fehler", [blitztext], "Ein Blitztext-Fehler")

        let ce = TermReplacement(from: "CE KI Solutions", to: "CE KI-Solutions")
        expect("Angebot von CE KI Solutions.", [ce], "Angebot von CE KI-Solutions.")

        let dollar = TermReplacement(from: "Euro", to: "$1 €")
        expect("zehn Euro", [dollar], "zehn $1 €")

        expect("unverändert", [TermReplacement(from: " ", to: "x")], "unverändert")

        // Settings written before 1.6 have no replacements key and must still load.
        let legacy = try JSONDecoder().decode(TranscriptionSettings.self, from: Data(#"{"language":"de"}"#.utf8))
        precondition(legacy.language == "de" && legacy.replacements.isEmpty)

        let roundTrip = try JSONDecoder().decode(
            TranscriptionSettings.self,
            from: JSONEncoder().encode(TranscriptionSettings(replacements: [blitztext]))
        )
        precondition(roundTrip.replacements == [blitztext])

        print("TermReplacement tests passed")
    }
}
