import SwiftUI

public struct OfflineView: View {
    public let viewModel: SynkroViewModel
    @State private var joinRoomCode: String = ""
    @State private var showJoinSection: Bool = false

    public init(viewModel: SynkroViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: "waveform.badge.exclamationmark")
                    .font(.title3)
                    .foregroundStyle(.orange)
            }
            .padding(.top, 4)

            VStack(spacing: 3) {
                Text("Synkrophase Offline")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Host a synchronized session or join peers on your local network.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMsg = viewModel.launchErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)

                    Text(errorMsg)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(spacing: 8) {
                // Primary: Host Session
                Button(action: {
                    viewModel.launchDaemon(mode: .host())
                }) {
                    HStack(spacing: 6) {
                        if viewModel.isStartingDaemon && !showJoinSection {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                        }
                        Text(viewModel.isStartingDaemon && !showJoinSection ? "Starting Host..." : "Host Session")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isStartingDaemon)

                // Secondary: Join Room
                if !showJoinSection {
                    Button(action: {
                        withAnimation(.snappy(duration: 0.2)) {
                            showJoinSection = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                            Text("Join Room...")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.primary.opacity(0.06))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isStartingDaemon)
                } else {
                    HStack(spacing: 8) {
                        TextField("ROOM CODE", text: $joinRoomCode)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.center)
                            .onChange(of: joinRoomCode) { _, newValue in
                                joinRoomCode = newValue.uppercased()
                            }
                            .frame(maxWidth: .infinity)

                        Button(action: {
                            let cleanCode = joinRoomCode.trimmingCharacters(in: .whitespaces)
                            guard !cleanCode.isEmpty else { return }
                            viewModel.launchDaemon(mode: .join(roomCode: cleanCode))
                        }) {
                            HStack(spacing: 4) {
                                if viewModel.isStartingDaemon {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Join")
                                        .fontWeight(.semibold)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(joinRoomCode.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isStartingDaemon)

                        Button(action: {
                            withAnimation(.snappy(duration: 0.2)) {
                                showJoinSection = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }
}
