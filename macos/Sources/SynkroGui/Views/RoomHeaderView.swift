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
                .background(.fill.tertiary, in: Capsule())
            }
            .buttonStyle(.plain)
            .help("Click to copy invite command (with leader address)")

            Spacer()

            // Role Badge
            Text(viewModel.role.rawValue.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(roleBadgeBackground, in: Capsule())
                .foregroundStyle(roleBadgeForeground)

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
            .background(.fill.quaternary, in: Capsule())
            .foregroundStyle(.secondary)
        }
    }

    private var roleBadgeBackground: Color {
        switch viewModel.role {
        case .leader:
            return Color.green.opacity(0.15)
        case .moderator:
            return Color.blue.opacity(0.15)
        case .listener:
            return Color.secondary.opacity(0.15)
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
