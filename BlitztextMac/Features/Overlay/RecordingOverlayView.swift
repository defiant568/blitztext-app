import SwiftUI

/// Translucent HUD content shown by `OverlayWindowController`. Reads the shared
/// `AppState` so the live waveform, processing text and result state stay in
/// sync with the active workflow, exactly like the popover does.
struct RecordingOverlayView: View {
    @Bindable var appState: AppState

    var body: some View {
        ZStack {
            switch appState.menuBarStatus {
            case .idle:
                EmptyView()
            case .recording(let type):
                pill { recordingContent(type: type) }
            case .processing(let type):
                pill { processingContent(type: type) }
            case .success:
                pill { successContent }
            case .error:
                pill { errorContent }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.18), value: appState.menuBarStatus)
    }

    // MARK: - Pill Container

    private func pill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            .fixedSize()
    }

    // MARK: - State Content

    private func recordingContent(type: WorkflowType) -> some View {
        HStack(spacing: 12) {
            workflowBadge(type)

            Text(appState.displayName(for: type))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            WaveformView(
                audioLevel: appState.activeWorkflow?.audioLevel ?? 0,
                isRecording: true,
                accentColor: accentColor(type)
            )
            .frame(width: 180, height: 32)
        }
    }

    private func processingContent(type: WorkflowType) -> some View {
        HStack(spacing: 12) {
            workflowBadge(type)

            Text(appState.displayName(for: type))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.8)

            Text(processingMessage)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
        }
    }

    private var successContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(.green)

            Text("Eingef\u{00FC}gt")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }

    private var errorContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange)

            Text(errorMessage)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    // MARK: - Helpers

    private func workflowBadge(_ type: WorkflowType) -> some View {
        Image(systemName: type.icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(accentColor(type))
            .frame(width: 20, height: 20)
    }

    /// Uses the active workflow's running message ("Wird transkribiert …",
    /// "Text wird verbessert …") when available, with a generic fallback.
    private var processingMessage: String {
        if case .running(let message)? = appState.activeWorkflow?.phase {
            return message
        }
        return "Wird verarbeitet \u{2026}"
    }

    /// Background hotkey errors clear `activeWorkflow` immediately, so the HUD
    /// shows a generic line; the popover path still carries the exact message.
    private var errorMessage: String {
        if case .error(let message)? = appState.activeWorkflow?.phase {
            return message
        }
        return "Etwas ist schiefgelaufen"
    }

    private func accentColor(_ type: WorkflowType) -> Color {
        switch type {
        case .transcription: return .blue
        case .localTranscription: return .green
        case .textImprover: return .purple
        case .dampfAblassen: return .orange
        case .emojiText: return .cyan
        }
    }
}
