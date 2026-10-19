import SwiftUI

public struct RoomHeaderView: View {
    public let viewModel: SynkroViewModel

    public init(viewModel: SynkroViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Room Code Copy Pill
            Button(action: {
                viewModel.copyRoomCode()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: viewModel.copiedRoomCode ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(viewModel.copiedRoomCode ? .green : .secondary)
                        .contentTransition(.symbolEffect(.replace))

                    Text(viewModel.roomCode.isEmpty ? "NO ROOM" : viewModel.roomCode)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
            }
            .buttonStyle(.plain)
            .help("Click to copy room code")

            Spacer()

            // Role Badge
            Text(viewModel.role.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(roleBadgeBackground)
                .foregroundStyle(roleBadgeForeground)
                .clipShape(Capsule())

            // Peer Count Pill
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                Text("\(viewModel.peers.count)")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.05))
            .foregroundStyle(.secondary)
            .clipShape(Capsule())
        }
    }

    private var roleBadgeBackground: some View {
        switch viewModel.role {
        case .leader:
            return AnyView(
                LinearGradient(
                    colors: [Color.green.opacity(0.18), Color.green.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .moderator:
            return AnyView(
                LinearGradient(
                    colors: [Color.blue.opacity(0.18), Color.blue.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .listener:
            return AnyView(
                LinearGradient(
                    colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private var roleBadgeForeground: Color {
        switch viewModel.role {
        case .leader:
            return .green
        case .moderator:
            return .blue
        case .listener:
            return .secondary
        }
    }
}
