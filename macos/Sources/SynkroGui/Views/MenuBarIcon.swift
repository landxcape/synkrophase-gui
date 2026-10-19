import SwiftUI

public struct MenuBarIcon: View {
    public let viewModel: SynkroViewModel

    public init(viewModel: SynkroViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if viewModel.connectionState != .connected {
                Image(systemName: "waveform.slash")
            } else if viewModel.isPlaying {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            } else {
                Image(systemName: "waveform")
            }
        }
    }
}
