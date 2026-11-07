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

            if let repairMsg = viewModel.autoRepairMessage {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)

                    Text(repairMsg)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

            // Diagnostics & Auto-Repair
            VStack(spacing: 6) {
                Button(action: {
                    Task {
                        await viewModel.runDoctor(fix: true)
                    }
                }) {
                    HStack(spacing: 6) {
                        if viewModel.isRunningDoctor {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "wrench.and.screwdriver")
                        }
                        Text(viewModel.isRunningDoctor ? "Diagnosing & Repairing..." : "Run Diagnostics & Repair")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isRunningDoctor || viewModel.isStartingDaemon)

                if let report = viewModel.doctorReport {
                    doctorReportCard(report)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func doctorReportCard(_ report: DoctorReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(report.hasFailures ? Color.red : (report.hasWarnings ? Color.orange : Color.green))
                        .frame(width: 8, height: 8)
                    Text(report.hasFailures ? "Issues Detected" : (report.hasWarnings ? "Ready with Warnings" : "System Healthy"))
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                Spacer()

                Button(action: {
                    viewModel.clearDoctorReport()
                }) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if !report.repairsApplied.isEmpty {
                ForEach(report.repairsApplied, id: \.self) { repair in
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text(repair)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                    }
                }
            }

            ForEach(report.checks.filter { $0.status != .passed }) { check in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: check.status == .failed ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(check.status == .failed ? Color.red : Color.orange)
                        Text(check.name)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    Text(check.message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if let remediation = check.remediation {
                        Text("Fix: \(remediation)")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
