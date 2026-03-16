import SwiftUI
import AppKit
import Combine
import QuartzCore

class HUDWindowManager: NSObject {
    static let shared = HUDWindowManager()

    final class DisplayState: ObservableObject {
        enum Kind {
            case volume
            case brightness
        }

        @Published var kind: Kind = .volume
        @Published var volume: Float = 0.0
        @Published var isMuted: Bool = false
        @Published var brightness: Float = 0.0
    }
    
    private var window: NSPanel?
    private var hideWorkItem: DispatchWorkItem?
    private let displayState = DisplayState()
    private var lastShownKind: DisplayState.Kind?
    private var lastShownPrimaryStep: Int?
    private var lastShownMuteState: Bool?
    private var lastShowTimestamp: CFTimeInterval = 0
    
    private override init() {
        super.init()
    }
    
    func showHUD(volumeManager: VolumeManager) {
        DispatchQueue.main.async {
            let volumeStep = Int(round(Double(volumeManager.volume) * 64.0))
            let now = CACurrentMediaTime()
            let isDuplicateFrame =
                self.lastShownKind == .volume &&
                self.lastShownPrimaryStep == volumeStep &&
                self.lastShownMuteState == volumeManager.isMuted &&
                (now - self.lastShowTimestamp) < 0.08
            if isDuplicateFrame {
                return
            }
            self.displayState.kind = .volume
            self.displayState.volume = volumeManager.volume
            self.displayState.isMuted = volumeManager.isMuted
            self.lastShownKind = .volume
            self.lastShownPrimaryStep = volumeStep
            self.lastShownMuteState = volumeManager.isMuted
            self.lastShowTimestamp = now

            self.presentHUD()
        }
    }

    func showBrightnessHUD(brightness: Float) {
        DispatchQueue.main.async {
            let brightnessStep = Int(round(Double(brightness) * 64.0))
            let now = CACurrentMediaTime()
            let isDuplicateFrame =
                self.lastShownKind == .brightness &&
                self.lastShownPrimaryStep == brightnessStep &&
                (now - self.lastShowTimestamp) < 0.08
            if isDuplicateFrame {
                return
            }

            self.displayState.kind = .brightness
            self.displayState.brightness = brightness
            self.lastShownKind = .brightness
            self.lastShownPrimaryStep = brightnessStep
            self.lastShownMuteState = nil
            self.lastShowTimestamp = now

            self.presentHUD()
        }
    }
    
    private func beginFadeOut() {
        guard let win = window else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            win.animator().alphaValue = 0.0
        }, completionHandler: {
            win.orderOut(nil)
            win.alphaValue = 1.0
        })
    }
    
    private func presentHUD() {
        let savedSize = UserDefaults.standard.string(forKey: "hudSize") ?? "Medium"
        let scale: CGFloat
        switch savedSize {
        case "Small": scale = 0.75
        case "Large": scale = 1.25
        default: scale = 1.0
        }
        let scaledSize = 210 * scale

        if let currentWindow = self.window, currentWindow.frame.width != scaledSize {
            currentWindow.orderOut(nil)
            self.window = nil
        }

        if self.window == nil {
            self.createWindow()
        }

        guard let win = self.window else { return }

        self.hideWorkItem?.cancel()
        self.hideWorkItem = nil

        if !win.isVisible {
            win.alphaValue = 1.0
            win.orderFrontRegardless()
        } else if win.alphaValue < 1.0 {
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0
            win.animator().alphaValue = 1.0
            NSAnimationContext.endGrouping()
        }

        let hideWorkItem = DispatchWorkItem { [weak self] in
            self?.beginFadeOut()
        }
        self.hideWorkItem = hideWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: hideWorkItem)
    }

    private func createWindow() {
        let savedSize = UserDefaults.standard.string(forKey: "hudSize") ?? "Medium"
        let scale: CGFloat
        switch savedSize {
        case "Small": scale = 0.75
        case "Large": scale = 1.25
        default: scale = 1.0
        }
        
        let baseSize: CGFloat = 210
        let scaledSize = baseSize * scale
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: scaledSize, height: scaledSize), 
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.animationBehavior = .none
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: scaledSize, height: scaledSize))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.layer?.actions = disabledLayerActions

        let backgroundView = HUDBackgroundView(frame: containerView.bounds, scale: scale)
        backgroundView.autoresizingMask = [.width, .height]
        containerView.addSubview(backgroundView)

        let hostingView = NSHostingView(rootView: RetroHUDView(hudState: displayState))
        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.actions = disabledLayerActions

        containerView.addSubview(hostingView)
        panel.contentView = containerView
        
        updateWindowPosition(panel, scaledSize: scaledSize)
        self.window = panel
    }
    
    private func updateWindowPosition(_ panel: NSPanel, scaledSize: CGFloat) {
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.origin.x + (screenRect.width - scaledSize) / 2
            let y = screenRect.origin.y + (screenRect.height / 5)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    private var disabledLayerActions: [String: CAAction] {
        [
            "bounds": NSNull(),
            "position": NSNull(),
            "frame": NSNull(),
            "contents": NSNull(),
            "transform": NSNull(),
            "shadowPath": NSNull(),
            "shadowOpacity": NSNull(),
            "shadowRadius": NSNull(),
        ]
    }
}

private final class HUDBackgroundView: NSView {
    private let scale: CGFloat
    
    init(frame frameRect: NSRect, scale: CGFloat) {
        self.scale = scale
        super.init(frame: frameRect)
        wantsLayer = true
        setupLayer()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLayer() {
        guard let layer else { return }
        layer.backgroundColor = NSColor(calibratedRed: 0.78, green: 0.78, blue: 0.78, alpha: 0.99).cgColor
        layer.borderColor = NSColor(calibratedWhite: 0.0, alpha: 0.12).cgColor
        layer.borderWidth = 0.8 * scale
        layer.cornerRadius = 24 * scale
        layer.masksToBounds = false
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 8 * scale
        layer.shadowOffset = NSSize(width: 0, height: -1)
        layer.actions = [
            "bounds": NSNull(),
            "position": NSNull(),
            "frame": NSNull(),
            "shadowPath": NSNull(),
            "shadowOpacity": NSNull(),
            "shadowRadius": NSNull(),
        ]
        updateShadowPath()
    }

    override func layout() {
        super.layout()
        updateShadowPath()
    }

    private func updateShadowPath() {
        guard let layer else { return }
        layer.shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: 24 * scale,
            cornerHeight: 24 * scale,
            transform: nil
        )
    }
}
