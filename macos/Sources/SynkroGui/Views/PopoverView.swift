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

                // Now Playing Track Card
                TrackCardView(viewModel: viewModel)

                // Timeline Scrubber
                ScrubberView(viewModel: viewModel)

                // Transport Controls
                ControlsView(viewModel: viewModel)

                Divider()
                    .opacity(0.3)

                // Peer List Drawer
                PeerListView(peers: viewModel.peers)
            } else {
                // Offline Empty State
                OfflineView(viewModel: viewModel)
            }

            Divider()
                .opacity(0.3)

            // Footer Utility Bar
            HStack {
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
        .background(.regularMaterial)
    }
}
