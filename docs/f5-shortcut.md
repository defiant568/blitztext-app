# F5 und Logitech MX Keys: Einrichtung auf beiden Macs

Diese Version ergaenzt F5 fuer den normalen Blitztext-Diktiermodus.
Fn + Shift und alle anderen bisherigen Fn-Kombinationen bleiben erhalten.
In Blitztext unter **Einstellungen > Anpassen > Tastenkuerzel** steht F5
zusaetzlich in der Liste.

## Logitech MX Keys: F5 ohne Fn

1. Auf der Logitech-Tastatur **Fn gedrueckt halten und einmal Esc druecken**.
2. Beide Tasten loslassen.
3. **F5 allein halten**, sprechen und zum Beenden loslassen.

Fn + Esc schaltet die gesamte obere Reihe zwischen Sonderfunktionen und
F1-F12 um. Im F-Tasten-Modus sind Lautstaerke und andere Sonderfunktionen
ueber Fn plus die jeweilige Taste erreichbar. Erneutes Fn + Esc schaltet zurueck.

Wenn **Fn + F5** funktioniert, aber **F5 allein** nicht, ist die Reihe meist
noch auf Sonderfunktionen eingestellt. Diese Kombinationen wurden mit einer
Logitech-MX-Tastatur am Mac praktisch getestet.

Bei einer Tastatur-Maus-Kombination fuer zwei Macs:

- Die Tastatur wie gewohnt ueber Easy-Switch auf den anderen Mac umschalten.
- Blitztext muss auf **jedem Mac** installiert sein und laufen.
- Auf dem neu gewaehlten Mac F5 pruefen. Falls nur Fn + F5 reagiert,
  dort einmal Fn + Esc umschalten.
- Den Fn-Lock-Zustand nach einem Geraetewechsel pruefen, statt anzunehmen,
  dass er bei jeder MX-Variante und Verbindung identisch gespeichert wird.
- Die Maus benoetigt fuer diesen Kurzbefehl keine Aenderung.

[Logitech: MX Keys Setup Guide, Abschnitt Fn + Esc](https://hub.sync.logitech.com/mx-keys/post/mx-keys-for-business---setup-guide-RfWxVegf2vZCAjM)

## Halten oder zweimal druecken

Unter **Einstellungen > Anpassen > Tastenkuerzel > Modus**:

- **Halten**: F5 waehrend der Aufnahme halten; Loslassen beendet die Aufnahme.
- **Druecken**: einmal F5 startet, nochmals F5 beendet die Aufnahme.

Diese Einstellung gilt auch fuer die bisherigen Fn-Kombinationen.
Im Haltemodus fuehrt kurzes Antippen nur zu einer sehr kurzen Aufnahme.
Escape beendet die laufende Aufnahme entsprechend dem bestehenden App-Verhalten.

F5 ist waehrend der Laufzeit von Blitztext systemweit reserviert.
Falls eine andere Anwendung die Taste bereits reserviert hat, zeigt Blitztext
einen Fehler bei den Tastenkuerzeln. Kombinationen wie Command + F5 werden
nicht von dieser Erweiterung registriert.

## Auf dem zweiten Mac installieren

Voraussetzungen sind macOS 14 oder neuer, vollstaendiges Xcode und XcodeGen.
Xcode einmal starten und die angebotene Ersteinrichtung abschliessen.
Die Command Line Tools allein reichen nicht aus.

1. Die **GitHub-Kopie mit dieser F5-Erweiterung** oeffnen und unter
   **Code > HTTPS** die Clone-Adresse kopieren. Der unveraenderte
   Originalstand von cmagnussen enthaelt diese Erweiterung noch nicht.
2. Das Repository klonen, den Branch mit dieser Anleitung auschecken und
   im Repository-Ordner bauen:

   ```sh
   ./build.sh --install --run
   ```

   Falls XcodeGen fehlt und Homebrew bereits installiert ist:

   ```sh
   brew install xcodegen
   ```

   Ohne Homebrew kann das offizielle
   [XcodeGen-Release](https://github.com/yonaskolb/XcodeGen/releases) verwendet
   werden. Beim Entpacken die Verzeichnisstruktur mit bin und share erhalten.
   Mit dem entpackten Binary das Projekt erzeugen:

   ```sh
   /pfad/zu/xcodegen/bin/xcodegen generate --spec BlitztextMac/project.yml
   ./build.sh --install --run
   ```

3. Die installierte App liegt unter **/Applications/Blitztext.app**.
4. Auf diesem Mac Mikrofonzugriff und fuer automatisches Einfuegen
   **Systemeinstellungen > Datenschutz & Sicherheit > Bedienungshilfen**
   fuer Blitztext freigeben. Diese Freigaben werden nicht vom anderen Mac
   uebernommen. Falls eine erneute Installation nicht erkannt wird, den alten
   Bedienungshilfen-Eintrag entfernen, die App aus Programme neu hinzufuegen
   und Blitztext neu starten.
5. Den eigenen API-Key in der App eintragen oder ein lokales WhisperKit-Modell
   installieren. API-Key, Modelle und Einstellungen werden durch GitHub
   nicht zwischen den Macs synchronisiert.
6. Die Logitech-Tastatur verbinden und wie oben mit Fn + Esc auf F-Tasten
   umschalten.

## Apple-Mikrofontaste

Die Mikrofon-Sonderfunktion auf einem MacBook ist nicht automatisch das
Tastensignal F5. Wenn Apples Diktierfunktion startet, unter
**Systemeinstellungen > Tastatur > Tastaturkurzbefehle > Funktionstasten**
die Option **Die Tasten F1, F2 usw. als Standard-Funktionstasten verwenden**
einschalten. Das aendert die gesamte obere Tastenreihe; Fn ruft dann die
Sonderfunktionen auf.

[Apple-Anleitung](https://support.apple.com/de-de/102439)

Eine per hidutil eingerichtete Mikrofontasten-Zuordnung ist eine separate
macOS-Einstellung. Sie wird weder mit der App eingebaut noch durch GitHub
auf den zweiten Mac uebertragen und kann nach einem Neustart verloren gehen.
Fuer die Logitech-Loesung mit Fn + Esc ist diese Zuordnung nicht erforderlich.

## Technische Pruefung

Die Erweiterung registriert F5 ueber RegisterEventHotKey, wertet Druecken und
Loslassen aus und unterdrueckt wiederholte Start-Ereignisse beim Halten.
Build 16 kennzeichnet die lokale F5-Version.

Im Repository-Ordner:

```sh
xcrun swiftc -parse-as-library BlitztextMac/Services/HotkeyService.swift BlitztextMac/Features/Workflows/WorkflowProtocol.swift Tests/HotkeyServiceTests.swift -o /tmp/blitztext-hotkey-tests
/tmp/blitztext-hotkey-tests
```

Optionaler macOS-Registrierungstest in einer angemeldeten Desktop-Sitzung:
Blitztext zuvor beenden, damit F5 fuer den Test frei ist.

```sh
/tmp/blitztext-hotkey-tests --registration
```

Der Test startet keine Mikrofonaufnahme. Er prueft Registrierung, native
Ereigniszustellung, Belegungskonflikte und erneute Registrierung.
Die tatsaechliche Tastaturbelegung muss zusaetzlich mit der physischen Taste
geprueft werden.
