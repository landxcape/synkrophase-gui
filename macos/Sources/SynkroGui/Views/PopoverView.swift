import SwiftUI

private struct ContentHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

public struct PopoverView: View {
    public let viewModel: SynkroViewModel
    @State private var measuredHeight: CGFloat = 0
    @State private var isShowingAbout: Bool = false

    public init(viewModel: SynkroViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 12) {
            if isShowingAbout {
                AboutView(isPresented: $isShowingAbout)
                    .transition(.opacity)
            } else {
                if viewModel.connectionState == .connected {
                    // Room Header
                    RoomHeaderView(viewModel: viewModel)

                    // Now Playing Track Card
                    TrackCardView(viewModel: viewModel)

                    // Timeline Scrubber
                    ScrubberView(viewModel: viewModel)

                    // Transport Controls & Volume
                    ControlsView(viewModel: viewModel)

                    Divider()
                        .opacity(0.2)

                    // Peer List Drawer
                    PeerListView(peers: viewModel.peers)
                } else {
                    // Offline State with Dual Host/Join Actions
                    OfflineView(viewModel: viewModel)
                }

                Divider()
                    .opacity(0.2)

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

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingAbout = true
                        }
                    }) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("About Synkrophase & Updates")

                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ContentHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
            MainActor.assumeIsolated {
                measuredHeight = height
            }
        }
        .background(
            VisualEffectBackground(material: .popover, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(
            DynamicWindowResizer(contentHeight: measuredHeight)
        )
    }
}
