import AppKit
import SwiftUI

/// Pure positioning helper: horizontally centered within the screen's visible
/// area, sitting a fixed margin above its bottom edge (which is already above
/// the Dock because `visibleFrame` excludes it). Kept free of AppKit window
/// state so it can be unit-tested in isolation.
func overlayFrame(
    in screenVisibleFrame: CGRect,
    panelSize: CGSize,
    bottomMargin: CGFloat
) -> CGRect {
    let x = screenVisibleFrame.midX - (panelSize.width / 2)
    let y = screenVisibleFrame.minY + bottomMargin
    return CGRect(x: x, y: y, width: panelSize.width, height: panelSize.height)
}

/// Owns the floating, non-activating panel that shows the on-screen recording /
/// processing HUD. The panel never becomes key and ignores mouse events, so it
/// can never steal focus from the app the user is dictating into — which keeps
/// `AppState`'s auto-paste targeting intact.
@MainActor
final class OverlayWindowController {
    private static let panelSize = NSSize(width: 520, height: 96)
    private static let bottomMargin: CGFloat = 96
    private static let fadeDuration: TimeInterval = 0.18
    private static let successHideDelay: TimeInterval = 1.2
    private static let errorHideDelay: TimeInterval = 2.0

    private let appState: AppState
    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    init(appState: AppState) {
        self.appState = appState
    }

    /// Drives the panel purely from the shared `MenuBarStatus`, so the menu bar
    /// icon and this overlay always reflect the same single source of truth.
    func update(to status: MenuBarStatus) {
        switch status {
        case .recording, .processing:
            cancelScheduledHide()
            show()
        case .success:
            show()
            scheduleHide(after: Self.successHideDelay)
        case .error:
            show()
            scheduleHide(after: Self.errorHideDelay)
        case .idle:
            hide()
        }
    }

    private func show() {
        let panel = ensurePanel()
        positionPanel(panel)
        panel.orderFrontRegardless()
        fade(panel, to: 1)
    }

    private func hide() {
        cancelScheduledHide()
        guard let panel, panel.isVisible else { return }
        fade(panel, to: 0) { [weak panel] in
            panel?.orderOut(nil)
        }
    }

    private func scheduleHide(after delay: TimeInterval) {
        cancelScheduledHide()
        let workItem = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelScheduledHide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.alphaValue = 0

        let hosting = NSHostingView(rootView: RecordingOverlayView(appState: appState))
        hosting.frame = NSRect(origin: .zero, size: Self.panelSize)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        self.panel = panel
        return panel
    }

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = overlayFrame(
            in: screen.visibleFrame,
            panelSize: Self.panelSize,
            bottomMargin: Self.bottomMargin
        )
        panel.setFrame(frame, display: false)
    }

    private func fade(_ panel: NSPanel, to alpha: CGFloat, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            panel.animator().alphaValue = alpha
        } completionHandler: {
            completion?()
        }
    }
}
