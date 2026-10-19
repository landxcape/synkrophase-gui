import SwiftUI
import AppKit

public struct AboutView: View {
    @Binding public var isPresented: Bool
    @State private var updateChecker = UpdateChecker()
    @State private var copiedCommand = false

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        VStack(spacing: 14) {
            // Header bar
            HStack {
                Text("About")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Return to Synkrophase")
            }

            // App Identity Card
            VStack(spacing: 6) {
                if let appIcon = NSImage(named: "AppIcon") {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    Image(systemName: "waveform")
                        .font(.system(size: 36))
                        .foregroundStyle(.cyan)
                        .frame(width: 64, height: 64)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Text("Synkrophase")
                    .font(.title3.weight(.bold))

                Text("LAN Playback Controller Synchronizer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            // Version and Metadata Box
            VStack(spacing: 6) {
                HStack {
                    Text("GUI Version")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("v\(updateChecker.currentVersion)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                }

                HStack {
                    Text("Core Engine")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("synkro v0.8.2")
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                }

                HStack {
                    Text("License")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("MIT / Apache-2.0")
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Update Engine Card
            VStack(spacing: 8) {
                switch updateChecker.status {
                case .idle:
                    Button(action: {
                        Task {
                            await updateChecker.checkForUpdates()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Check for Updates")
                        }
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)

                case .checking:
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking GitHub Releases...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)

                case .upToDate(let version):
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Synkrophase is up to date (v\(version))")
                                .font(.caption.weight(.medium))
                        }

                        Button("Check Again") {
                            Task {
                                await updateChecker.checkForUpdates()
                            }
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)

                case .updateAvailable(let current, let latest, let releaseUrl):
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(.cyan)
                            Text("Update Available: v\(latest)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.primary)
                        }

                        Text("Current: v\(current)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        // Action 1: Copy Homebrew Upgrade Command
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("brew upgrade --cask synkrophase", forType: .string)
                            copiedCommand = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                copiedCommand = false
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: copiedCommand ? "checkmark" : "doc.on.doc")
                                Text(copiedCommand ? "Copied Command!" : "Copy brew upgrade")
                            }
                            .font(.caption2.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)

                        // Action 2: Open GitHub Release in browser
                        Button(action: {
                            NSWorkspace.shared.open(releaseUrl)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square")
                                Text("View on GitHub")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.cyan.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                case .error(let message):
                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Check Failed")
                                .font(.caption.weight(.medium))
                        }

                        Text(message)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            Task {
                                await updateChecker.checkForUpdates()
                            }
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundStyle(.cyan)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Divider()
                .opacity(0.2)

            // Links Bar
            HStack(spacing: 16) {
                Button(action: {
                    if let url = URL(string: "https://github.com/landxcape/synkrophase-gui") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("GitHub")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: {
                    if let url = URL(string: "https://github.com/landxcape/synkrophase") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("CLI Engine")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("© 2026 Purna Kalyan Shakya")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
