import SwiftUI

public struct ControlsView: View {
    public let viewModel: SynkroViewModel

    public init(viewModel: SynkroViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Transport Action Row
            HStack(spacing: 24) {
                Spacer()

                // Skip Previous
                Button(action: {
                    viewModel.skipPrev()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                        .foregroundStyle(viewModel.role == .listener ? .tertiary : .primary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.role == .listener)

                // Play / Pause
                Button(action: {
                    viewModel.togglePlayPause()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 36, height: 36)

                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.role == .listener)
                .opacity(viewModel.role == .listener ? 0.6 : 1.0)

                // Skip Next
                Button(action: {
                    viewModel.skipNext()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundStyle(viewModel.role == .listener ? .tertiary : .primary)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.role == .listener)

                Spacer()
            }

            // Control Center Style Volume Capsule Slider
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.1))
                            .frame(height: 6)

                        Capsule()
                            .fill(Color.primary.opacity(0.7))
                            .frame(width: geometry.size.width * CGFloat(viewModel.volume / 100.0), height: 6)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard viewModel.role != .listener else { return }
                                let ratio = min(max(value.location.x / geometry.size.width, 0.0), 1.0)
                                viewModel.setVolume(Double(ratio * 100.0))
                            }
                    )
                }
                .frame(height: 12)
                .opacity(viewModel.role == .listener ? 0.6 : 1.0)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}
