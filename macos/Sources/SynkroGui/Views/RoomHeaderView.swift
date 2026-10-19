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
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help("Click to copy room code")

            Spacer()

            // Role Badge
            Text(viewModel.role.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
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
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.05))
            )
        }
    }

    private var roleBadgeBackground: Color {
        switch viewModel.role {
        case .leader:
            return Color.blue.opacity(0.15)
        case .moderator:
            return Color.purple.opacity(0.15)
        case .listener:
            return Color.secondary.opacity(0.15)
        }
    }

    private var roleBadgeForeground: Color {
        switch viewModel.role {
        case .leader:
            return .blue
        case .moderator:
            return .purple
        case .listener:
            return .secondary
        }
    }
}
