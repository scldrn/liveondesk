//
//  WindowDetector.swift
//  liveondesk
//

import CoreGraphics
import AppKit

struct WindowPlatform: Equatable {
    let windowID: CGWindowID
    let topEdgeY: CGFloat   // coordenada Y en sistema SpriteKit (origen abajo-izquierda)
    let minX: CGFloat
    let maxX: CGFloat
}

class WindowDetector {
    var onWindowsChanged: (([WindowPlatform]) -> Void)?
    private var timer: Timer?
    private var lastPlatforms: [CGWindowID: WindowPlatform] = [:]

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard let screen = NSScreen.main else { return }
        let screenHeight = screen.frame.height
        let ourPID = NSRunningApplication.current.processIdentifier

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return }

        var platforms: [WindowPlatform] = []

        for info in infoList {
            if let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID == ourPID { continue }

            guard
                let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                let alpha    = info[kCGWindowAlpha as String] as? Double, alpha > 0,
                let layer    = info[kCGWindowLayer as String] as? Int,    layer == 0
            else { continue }

            var bounds = CGRect.zero
            guard let boundsObj = info[kCGWindowBounds as String] as? NSDictionary,
                  CGRectMakeWithDictionaryRepresentation(boundsObj as CFDictionary, &bounds)
            else { continue }

            guard bounds.width > 80 && bounds.height > 40 else { continue }

            // Quartz (origen arriba-izquierda, Y crece hacia abajo) → SpriteKit (origen abajo-izquierda)
            let topEdgeY = screenHeight - bounds.minY

            platforms.append(WindowPlatform(
                windowID: windowID,
                topEdgeY: topEdgeY,
                minX: bounds.minX,
                maxX: bounds.maxX
            ))
        }

        // Solo notificar si algo cambió — evita recrear physics bodies innecesariamente
        let newMap = Dictionary(uniqueKeysWithValues: platforms.map { ($0.windowID, $0) })
        guard newMap != lastPlatforms else { return }
        lastPlatforms = newMap
        onWindowsChanged?(platforms)
    }
}
