import SwiftUI
import AppKit

public struct VisualEffectBackground: NSViewRepresentable {
    public var material: NSVisualEffectView.Material = .popover
    public var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    public init(
        material: NSVisualEffectView.Material = .popover,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 16
        view.layer?.masksToBounds = true
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
        nsView.wantsLayer = true
        nsView.layer?.cornerRadius = 16
        nsView.layer?.masksToBounds = true

        DispatchQueue.main.async {
            if let window = nsView.window {
                window.isOpaque = false
                window.backgroundColor = .clear
                window.contentView?.wantsLayer = true
                window.contentView?.layer?.backgroundColor = .clear
                window.hasShadow = true
                window.invalidateShadow()
            }
        }
    }
}

public struct DynamicWindowResizer: NSViewRepresentable {
    public let contentHeight: CGFloat

    public init(contentHeight: CGFloat) {
        self.contentHeight = contentHeight
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window, contentHeight > 50 else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.backgroundColor = .clear

            let currentFrame = window.frame
            let targetHeight = ceil(contentHeight)
            if abs(currentFrame.height - targetHeight) > 2 {
                let deltaY = targetHeight - currentFrame.height
                let newOriginY = currentFrame.origin.y - deltaY
                let newFrame = NSRect(
                    x: currentFrame.origin.x,
                    y: newOriginY,
                    width: currentFrame.width,
                    height: targetHeight
                )
                window.setFrame(newFrame, display: true, animate: true)
                window.invalidateShadow()
            }
        }
    }
}
