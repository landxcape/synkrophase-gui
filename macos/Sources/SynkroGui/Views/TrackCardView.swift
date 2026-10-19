import SwiftUI

public struct TrackCardView: View {
    public let viewModel: SynkroViewModel

    public init(viewModel: SynkroViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Player / Artwork Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.08))

                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .frame(width: 44, height: 44)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
            )

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
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
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
