import SwiftUI

public struct ScrubberView: View {
    public let viewModel: SynkroViewModel
    @State private var dragPositionSec: Double?

    public init(viewModel: SynkroViewModel) {
        self.viewModel = viewModel
    }

    private var currentPosition: Double {
        dragPositionSec ?? viewModel.positionSec
    }

    private var progress: Double {
        guard viewModel.durationSec > 0 else { return 0.0 }
        return min(max(currentPosition / viewModel.durationSec, 0.0), 1.0)
    }

    public var body: some View {
        VStack(spacing: 4) {
            // Interactive Capsule Track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track Background
                    Capsule()
                        .fill(.fill.quaternary)
                        .frame(height: 5)

                    // Active Progress
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * progress, height: 5)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard viewModel.role != .listener, viewModel.durationSec > 0 else { return }
                            let ratio = min(max(value.location.x / geometry.size.width, 0.0), 1.0)
                            dragPositionSec = ratio * viewModel.durationSec
                            viewModel.isScrubbing = true
                        }
                        .onEnded { value in
                            guard viewModel.role != .listener, viewModel.durationSec > 0 else { return }
                            let ratio = min(max(value.location.x / geometry.size.width, 0.0), 1.0)
                            let targetSec = ratio * viewModel.durationSec
                            dragPositionSec = nil
                            viewModel.seek(to: targetSec)
                        }
                )
            }
            .frame(height: 10)
            .opacity(viewModel.role == .listener ? 0.6 : 1.0)

            // Timestamps
            HStack {
                Text(formatTime(currentPosition))
                    .font(.system(size: 10, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatTime(viewModel.durationSec))
                    .font(.system(size: 10, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "00:00" }
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}
