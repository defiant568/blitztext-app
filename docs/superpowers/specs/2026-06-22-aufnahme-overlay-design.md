# Aufnahme-Overlay (Bildschirm-HUD) — Design

- **Datum:** 2026-06-22
- **Status:** Freigegeben (Brainstorming abgeschlossen)
- **Bereich:** BlitztextMac (macOS Menüleisten-App)

## Problem / Motivation

Wird ein Workflow per Tastenkombination gestartet, läuft er im Standard-Modus
**„Halten"** (`hotkeyMode = .hold`) bewusst im Hintergrund ohne Popover
(`WorkflowLaunchSource.hotkeyBackground`, `presentsWorkflowPage == false`).
Das einzige sichtbare Feedback ist dann das kleine, animierte Menüleisten-Icon —
das man beim Tippen in einer anderen App nicht im Blick hat.

Folge: Man erkennt nicht, ob gerade aufgenommen wird, ob das Transkript noch
verarbeitet wird, oder ob überhaupt etwas funktioniert hat.

## Ziel

Ein dezentes, durchscheinendes Overlay unten mittig am Bildschirm, das den
aktuellen Zustand eines laufenden Workflows zeigt:

- **Aufnahme:** Live-Waveform, die auf die Stimme reagiert, + Workflow-Name/Farbe.
- **Verarbeitung:** Spinner + Phasentext (z. B. „Text wird verbessert …").
- **Fertig:** kurz „Eingefügt ✓" (grün), blendet aus.
- **Fehler:** kurz eine Fehlermeldung (orange), blendet aus.

## Nicht-Ziele

- Keine Interaktion über das Overlay (kein Stopp-Button). Im Halten-Modus stoppt
  das Loslassen der Tasten; im Toggle-Modus übernimmt weiterhin das Popover.
- Keine Änderungen an Aufnahme-, Transkriptions-, Paste- oder Einstellungslogik.
- Keine neue Persistenz, keine neuen Einstellungen.

## Anforderungen (aus dem Brainstorming)

1. **Wann sichtbar:** *Immer wenn ein Workflow läuft* — unabhängig davon, ob er
   per Hintergrund-Hotkey oder über die Menüleiste gestartet wurde.
2. **Inhalt:** *Lebendig* — Live-Waveform bei Aufnahme, Spinner bei Verarbeitung,
   dazu Name + Akzentfarbe des aktiven Workflows.
3. **Abschluss:** *Kurze Bestätigung* — nach dem Einfügen kurz „Eingefügt ✓"
   (grün) und ausblenden; bei Fehler kurz eine Meldung (orange) und ausblenden.
4. **Position:** unten mittig am Bildschirm.

## Architektur

Gewählter Ansatz: **eigenes schwebendes, nicht-aktivierendes Overlay-Fenster**
(`NSPanel`) mit SwiftUI-Inhalt. Das Fenster wird klickdurchlässig und
nicht-aktivierend konfiguriert, damit es **niemals den Fokus stiehlt** — sonst
würde die Auto-Paste-Logik in `AppState` (die sich die Ziel-App über
`frontmostApplication` merkt) ins falsche Fenster einfügen.

Verworfene Alternativen:

- **Popover unten andocken:** Popover ist fest an den Menüleisten-Button
  gebunden, `.transient` (schließt bei Außen-Klick) und aktiviert die App
  (`NSApp.activate`) → bricht das Auto-Paste.
- **Nur Menüleisten-Icon stärker animieren:** existiert bereits und löst das
  Problem nicht (man schaut beim Tippen nicht in die Menüleiste).

### Komponenten

**1. `OverlayWindowController` (neu, `BlitztextMac/App/`)**

Verwaltet das `NSPanel` und dessen Lebenszyklus:

- Erzeugt das Panel **lazy** beim ersten Anzeigen und hält es danach.
- Fensterkonfiguration:
  - `styleMask = [.borderless, .nonactivatingPanel]`
  - `isFloatingPanel = true`, `level = .statusBar`
  - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`
  - `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = true`
  - `ignoresMouseEvents = true` (klickdurchlässig)
  - `hidesOnDeactivate = false`
  - Inhalt via `NSHostingView(rootView: RecordingOverlayView(appState:))`, einmalig erzeugt.
- Anzeigen mit `orderFrontRegardless()` (**nicht** `makeKeyAndOrderFront`),
  um keinen Fokus zu übernehmen.
- Sanftes Ein-/Ausblenden über `animator().alphaValue` (Fade ~0,18 s).
- Eigener Auto-Hide-Timer für `success`/`error`, damit das Overlay nie hängen
  bleibt — unabhängig davon, ob der Aufruf aus dem Hintergrund- oder
  Popover-Pfad kam.
- Methode `update(to status: MenuBarStatus)`:
  - `recording` / `processing`: Position neu berechnen, Panel einblenden,
    laufenden Auto-Hide-Timer abbrechen.
  - `success`: sichtbar lassen, Auto-Hide-Timer ~1,2 s.
  - `error`: sichtbar lassen, Auto-Hide-Timer ~2,0 s.
  - `idle`: ausblenden.

**2. `RecordingOverlayView` (neu, `BlitztextMac/Features/Overlay/`)**

SwiftUI-Inhalt der Pille. Beobachtet `appState` (`@Bindable`) und rendert anhand
von `appState.menuBarStatus` (trägt bereits den `WorkflowType`) plus dem aktiven
Workflow:

- Hintergrund: abgerundetes Rechteck/Capsule mit `.ultraThinMaterial`, dünner
  Rand (`Color.primary.opacity(~0.08)`), weicher Schatten.
- **Aufnahme** (`recording(type)`): farbiger Punkt/Icon (Akzentfarbe des
  Workflows) + Name (`appState.displayName(for: type)`) +
  `WaveformView(audioLevel: appState.activeWorkflow?.audioLevel ?? 0, isRecording: true, accentColor:)`.
- **Verarbeitung** (`processing(type)`): Icon + Name + kleiner Spinner +
  Phasentext. Text = laufende Phasenmeldung des aktiven Workflows
  (`if case .running(let msg) = appState.activeWorkflow?.phase`) bzw. Fallback
  „Wird verarbeitet …".
- **Fertig** (`success`): grünes Häkchen + „Eingefügt".
- **Fehler** (`error`): oranges Warndreieck + „Etwas ist schiefgelaufen"
  (HUD-Ebene; Detailmeldungen bleiben im Popover für den manuellen Modus).

Akzentfarbe je Workflow analog zum Popover: blau / grün / lila / orange / cyan.

**3. `Workflow`-Protokoll (`WorkflowProtocol.swift`)**

Ergänzung um eine Zeile, damit die Overlay-View den Pegel über
`appState.activeWorkflow` (Typ `any Workflow`) lesen kann:

```swift
var audioLevel: Float { get }
```

Alle vier konkreten Workflows (`TranscriptionWorkflow`, `TextImprovementWorkflow`,
`DampfAblassenWorkflow`, `EmojiTextWorkflow`) besitzen diese Eigenschaft bereits;
sie ist nur noch nicht im Protokoll deklariert.

**4. `AppDelegate` (`BlitztextMacApp.swift`)**

- Hält eine Instanz `OverlayWindowController` (init mit `appState`).
- Im bereits vorhandenen `appState.onMenuBarStatusChange`-Callback zusätzlich
  `overlayController.update(to: status)` aufrufen. Damit bleibt `menuBarStatus`
  die **eine** zentrale Statusquelle für Menüleisten-Icon *und* Overlay — kein
  zweiter Zustand.

### Datenfluss

```
Workflow.phase ──▶ AppState.handleWorkflowPhaseChange ──▶ AppState.menuBarStatus
                                                              │
                          ┌───────────────────────────────────┤ (onMenuBarStatusChange)
                          ▼                                   ▼
            MenuBarStatusController.update          OverlayWindowController.update
            (Menüleisten-Icon)                      (Panel zeigen/ausblenden/timer)

RecordingOverlayView beobachtet AppState live:
  - appState.menuBarStatus           → welcher Zustand
  - appState.activeWorkflow.audioLevel → Live-Waveform
  - appState.activeWorkflow.phase      → Phasentext bei Verarbeitung
```

### Sichtbarkeit & Timing

| `menuBarStatus` | Overlay |
|-----------------|---------|
| `recording`     | einblenden, kein Auto-Hide |
| `processing`    | sichtbar, kein Auto-Hide |
| `success`       | sichtbar, Auto-Hide ~1,2 s |
| `error`         | sichtbar, Auto-Hide ~2,0 s |
| `idle`          | ausblenden |

Hinweis zum bestehenden Verhalten, mit dem das harmoniert:

- Nach `.done` setzt `AppState` `menuBarStatus = .success` und plant
  `scheduleWorkflowCleanup(after: 1.05)` → danach `idle`. Während dieses
  ~1-s-Fensters existiert der Workflow noch.
- Bei `.error` aus dem Hintergrund-Pfad wird `activeWorkflow` sofort auf `nil`
  gesetzt und `menuBarStatus = .error`. Deshalb darf die Overlay-View im
  Fehlerfall **nicht** auf einen vorhandenen Workflow angewiesen sein und zeigt
  einen generischen Fehlertext.

### Positionierung

- Zielbildschirm: `NSScreen.main ?? NSScreen.screens.first`. Bei jedem Einblenden
  neu bestimmen (der aktive Bildschirm kann wechseln).
- Unten mittig innerhalb von `screen.visibleFrame` (bleibt über dem Dock):
  - `x = visibleFrame.midX - panelWidth / 2`
  - `y = visibleFrame.minY + bottomMargin` (Richtwert `bottomMargin ≈ 96`)
- Die reine Rechnung wird in eine **testbare freie Funktion** ausgelagert:
  `overlayFrame(in screenVisibleFrame: CGRect, panelSize: CGSize, bottomMargin: CGFloat) -> CGRect`.

## Fehlerbehandlung / Robustheit

- Schneller Neustart (neue Aufnahme während des „Fertig"-Ausblendens):
  `recording`-Status bricht den Auto-Hide-Timer ab, setzt `alphaValue = 1` und
  positioniert neu.
- Overlay-Fenster wird lazy erzeugt und bei `idle` nur ausgeblendet (nicht
  zerstört), um Flackern bei aufeinanderfolgenden Workflows zu vermeiden.
- Da das Panel nicht-aktivierend und klickdurchlässig ist, bleibt die zuvor
  aktive App vorne → Auto-Paste landet weiterhin im richtigen Fenster.

## Testing

- **Unit-Test:** `overlayFrame(in:panelSize:bottomMargin:)` — korrekte Zentrierung
  und unterer Abstand für gegebene Bildschirm-Frames (inkl. Offset durch
  `visibleFrame.origin` bei externem Monitor / Menüleiste).
- **Manuelle Verifikation** (`./build.sh --run`):
  1. Jeden Workflow per Hotkey im Halten-Modus auslösen; Overlay erscheint unten
     mittig mit Live-Waveform.
  2. Loslassen → Overlay wechselt zu Spinner + Verarbeitungstext.
  3. Nach Abschluss kurz „Eingefügt ✓", dann ausblenden; Text landet im zuvor
     aktiven Fenster (Fokus nicht gestohlen).
  4. Fehlerfall (z. B. sehr kurze Aufnahme) → kurze orange Meldung, blendet aus.
  5. Toggle-Modus: Popover *und* Overlay erscheinen wie erwartet.
  6. Mehrere Workflows hintereinander → kein Hängenbleiben, kein Flackern.

## Dateien

**Neu:**
- `BlitztextMac/App/OverlayWindowController.swift`
- `BlitztextMac/Features/Overlay/RecordingOverlayView.swift`

**Geändert:**
- `BlitztextMac/Features/Workflows/WorkflowProtocol.swift` (+`audioLevel` im Protokoll)
- `BlitztextMac/App/BlitztextMacApp.swift` (Controller anlegen + im Status-Callback aufrufen)

## Offen / später (Out of Scope)

- Konfigurierbare Overlay-Position oder Abschaltbarkeit per Einstellung.
- Detaillierte Fehlermeldung im Overlay statt generischem Text.
- Anpassung der Auto-Hide-Dauer durch den Nutzer.
