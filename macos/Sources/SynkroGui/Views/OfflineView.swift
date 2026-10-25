import SwiftUI

public struct OfflineView: View {
    public let viewModel: SynkroViewModel
    @State private var joinRoomCode: String = ""
    @State private var joinLeaderAddr: String = ""
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
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
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
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(viewModel.isStartingDaemon)
                } else {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            TextField("ROOM CODE", text: $joinRoomCode)
                                .textFieldStyle(.plain)
                                .font(.system(.subheadline, design: .monospaced))
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .onChange(of: joinRoomCode) { _, newValue in
                                    handleRoomInput(newValue)
                                }

                            Button(action: {
                                withAnimation(.snappy(duration: 0.2)) {
                                    showJoinSection = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Cancel")
                        }

                        TextField("LEADER IP:PORT (OPTIONAL)", text: $joinLeaderAddr)
                            .textFieldStyle(.plain)
                            .font(.system(.caption, design: .monospaced))
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .onChange(of: joinLeaderAddr) { _, newValue in
                                if newValue.contains("synkro join") || newValue.contains("synkro://") {
                                    handleRoomInput(newValue)
                                }
                            }

                        Button(action: {
                            let cleanCode = joinRoomCode.trimmingCharacters(in: .whitespaces)
                            let cleanAddr = joinLeaderAddr.trimmingCharacters(in: .whitespaces)
                            guard !cleanCode.isEmpty else { return }
                            viewModel.launchDaemon(mode: .join(
                                roomCode: cleanCode,
                                leaderAddr: cleanAddr.isEmpty ? nil : cleanAddr
                            ))
                        }) {
                            HStack(spacing: 6) {
                                if viewModel.isStartingDaemon {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                                Text(viewModel.isStartingDaemon ? "Joining..." : "Join Room")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(joinRoomCode.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isStartingDaemon)
                    }
                    .padding(4)
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func handleRoomInput(_ input: String) {
        if input.contains("synkro join") || input.contains("synkro://") || input.contains("@") {
            let parsed = SynkroViewModel.JoinCredentials.parse(input)
            joinRoomCode = parsed.roomCode
            if let addr = parsed.leaderAddr {
                joinLeaderAddr = addr
            }
        } else {
            joinRoomCode = input.uppercased()
        }
    }
}
