import SwiftUI

public struct TrackCardView: View {
    public let viewModel: SynkroViewModel

    public init(viewModel: SynkroViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Liquid Glass Artwork Container
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.18),
                                Color.accentColor.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "music.note")
                    .font(.title3)
                    .foregroundStyle(.tint)
            }
            .frame(width: 46, height: 46)
            .shadow(color: Color.accentColor.opacity(0.12), radius: 6, x: 0, y: 3)

            // Metadata Titles
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.trackTitle)
                    .font(.system(.subheadline, design: .default))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)

                Text(viewModel.trackArtist.isEmpty ? "Unknown Artist" : viewModel.trackArtist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Micro Drift Badge
                if viewModel.driftOffsetUs != 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(abs(viewModel.driftOffsetUs) < 50_000 ? Color.green : Color.orange)
                            .frame(width: 5, height: 5)

                        Text(formattedDrift)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.20), location: 0.0),
                            .init(color: .clear, location: 0.5),
                            .init(color: .black.opacity(0.06), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
    }

    private var formattedDrift: String {
        let us = viewModel.driftOffsetUs
        let ms = Double(us) / 1000.0
        if abs(ms) < 1.0 {
            return String(format: "%+dµs", us)
        } else {
            return String(format: "%+.1fms", ms)
        }
    }
}
