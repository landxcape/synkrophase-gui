import SwiftUI

public struct PopoverView: View {
    public let viewModel: SynkroViewModel

    public init(viewModel: SynkroViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 12) {
            if viewModel.connectionState == .connected {
                // Room Header
                RoomHeaderView(viewModel: viewModel)

                // Now Playing Track Card with layered glass depth
                TrackCardView(viewModel: viewModel)

                // Timeline Scrubber
                ScrubberView(viewModel: viewModel)

                // Transport Controls & Volume
                ControlsView(viewModel: viewModel)

                softDivider

                // Peer List Drawer
                PeerListView(peers: viewModel.peers)
            } else {
                // Offline State with Dual Host/Join Actions
                OfflineView(viewModel: viewModel)
            }

            softDivider

            // Footer Utility Bar
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        await viewModel.fetchStatus()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh Status")

                if viewModel.connectionState == .connected {
                    Button(action: {
                        viewModel.stopDaemon()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "power")
                            Text("Stop")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Stop background sync daemon")
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.35), location: 0.0),
                            .init(color: .white.opacity(0.06), location: 0.4),
                            .init(color: .black.opacity(0.10), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private var softDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, Color.primary.opacity(0.08), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}
