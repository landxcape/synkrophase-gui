import SwiftUI
import AppKit

@main
struct SynkroApp: App {
    @State private var viewModel = SynkroViewModel()

    init() {
        // Enforce accessory activation policy: no Dock icon, menu bar agent
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(viewModel: viewModel)
        } label: {
            MenuBarIcon(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
