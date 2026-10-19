import SwiftUI

public struct OfflineView: View {
    public let viewModel: SynkroViewModel

    public init(viewModel: SynkroViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: "waveform.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
            .padding(.top, 6)

            VStack(spacing: 4) {
                Text("Daemon Offline")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Background sync daemon is not running.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                viewModel.launchDaemon()
            }) {
                HStack(spacing: 6) {
                    if viewModel.isStartingDaemon {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "play.circle.fill")
                    }
                    Text(viewModel.isStartingDaemon ? "Starting..." : "Start Daemon")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isStartingDaemon)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}
