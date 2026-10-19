import SwiftUI

public struct PeerListView: View {
    public let peers: [PeerInfo]
    @State private var isExpanded: Bool = false

    public init(peers: [PeerInfo]) {
        self.peers = peers
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Disclosure Toggle
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("Connected Peers")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(peers.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.fill.quaternary))
                }
            }
            .buttonStyle(.plain)

            // Collapsible Peer Rows
            if isExpanded {
                VStack(spacing: 4) {
                    if peers.isEmpty {
                        Text("No peers in room")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(peers) { peer in
                            peerRow(peer)
                        }
                    }
                }
                .padding(.leading, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func peerRow(_ peer: PeerInfo) -> some View {
        HStack {
            Circle()
                .fill(abs(peer.clockOffsetUs) < 5_000 ? Color.green : Color.orange)
                .frame(width: 5, height: 5)

            Text(peer.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Text(peer.role.rawValue)
                .font(.system(size: 9, weight: .semibold))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(Capsule().fill(.fill.quaternary))
                .foregroundStyle(.secondary)

            Text(formatOffset(peer.clockOffsetUs))
                .font(.system(size: 9, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func formatOffset(_ us: Int64) -> String {
        let ms = Double(us) / 1000.0
        if abs(ms) < 1.0 {
            return String(format: "%+dµs", us)
        } else {
            return String(format: "%+.1fms", ms)
        }
    }
}
