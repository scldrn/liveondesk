//
//  AppDelegate.swift
//  liveondesk
//

import AppKit
import SpriteKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel!
    private var skView: SKView!

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildPanel()

        // Reconstruir si cambia la resolución o se conecta/desconecta un monitor
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        buildPanel()
    }

    private func buildPanel() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        // Reusar panel si ya existe, solo actualizar frame
        if let existing = panel {
            existing.setFrame(screenFrame, display: true)
            skView.frame = CGRect(origin: .zero, size: screenFrame.size)
            if let scene = skView.scene {
                scene.size = screenFrame.size
            }
            return
        }

        panel = NSPanel(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.isMovable = false
        panel.hasShadow = false

        skView = SKView(frame: CGRect(origin: .zero, size: screenFrame.size))
        skView.allowsTransparency = true

        let scene = PetScene(size: screenFrame.size)
        skView.presentScene(scene)

        panel.contentView = skView
        panel.orderFrontRegardless()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
