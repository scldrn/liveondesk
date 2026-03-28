//
//  WindowDetector.swift
//  liveondesk
//

import CoreGraphics
import AppKit

// MARK: - Window Classification

/// Geometric classification of a window based on aspect ratio.
///
/// The spec defines five distinct window shapes that trigger different pet behaviors:
/// - **wide**: ratio > 2.5:1 → walking platform (the pet patrols edge-to-edge)
/// - **square**: ratio ~1:1 (0.6–1.4) → jump-on block (the pet leaps onto it)
/// - **small + corner**: area < threshold & near screen edge → hiding spot
/// - **normal**: everything else → standard walking platform
enum WindowShape: Equatable {
    case wide       // >2.5 aspect ratio — dedicated walking platform
    case square     // ~1:1 — jump target
    case small      // small area in a corner — hiding spot
    case normal     // standard platform
}

struct WindowPlatform: Equatable {
    let windowID: CGWindowID
    let topEdgeY: CGFloat       // Y in SpriteKit coords (origin bottom-left)
    let minX: CGFloat
    let maxX: CGFloat
    let width: CGFloat
    let height: CGFloat
    let shape: WindowShape
    let ownerBundleID: String?  // Used for contextual behaviors (music detection, etc.)

    /// The center X coordinate of this platform.
    var centerX: CGFloat { (minX + maxX) / 2 }
}

// MARK: - Music Detection

/// Bundle IDs of known music applications.
/// Used to detect if the frontmost or owning app is a music player,
/// which triggers the pet's dancing behavior.
private let musicBundleIDs: Set<String> = [
    "com.apple.Music",
    "com.spotify.client",
    "com.tidal.desktop",
    "com.amazon.Amazon-Music",
    "com.apple.Safari",           // Could be playing YouTube
]

/// Checks if the currently frontmost application is a known music player.
func isMusicAppActive() -> Bool {
    guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
        return false
    }
    return musicBundleIDs.contains(bundleID)
}

// MARK: - Window Detector

class WindowDetector {
    var onWindowsChanged: (([WindowPlatform]) -> Void)?
    private var pollTask: Task<Void, Never>?
    private var lastPlatforms: [CGWindowID: WindowPlatform] = [:]

    @MainActor
    func start() {
        stop()
        pollTask = Task { @MainActor [weak self] in
            self?.poll()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { break }
                self?.poll()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    @MainActor
    private func poll() {
        guard let screen = NSScreen.main else { return }
        let screenFrame  = screen.frame
        let screenHeight = screenFrame.height
        let screenWidth  = screenFrame.width
        let ourPID = NSRunningApplication.current.processIdentifier

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        var platforms: [WindowPlatform] = []

        for info in infoList {
            // Skip our own windows
            if let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
               ownerPID == ourPID { continue }

            guard
                let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                let alpha    = info[kCGWindowAlpha as String] as? Double, alpha > 0,
                let layer    = info[kCGWindowLayer as String] as? Int,    layer == 0
            else { continue }

            var bounds = CGRect.zero
            guard let boundsObj = info[kCGWindowBounds as String] as? NSDictionary,
                  CGRectMakeWithDictionaryRepresentation(boundsObj as CFDictionary, &bounds)
            else { continue }

            // Filter out tiny windows (toolbars, popovers, etc.)
            guard bounds.width > 80 && bounds.height > 40 else { continue }

            let ownerBundleID = info[kCGWindowOwnerName as String] as? String

            // Quartz coords (origin top-left, Y grows down) → SpriteKit (origin bottom-left)
            let topEdgeY = screenHeight - bounds.minY

            // --- Geometric classification ---
            let aspectRatio = bounds.width / max(bounds.height, 1)
            let area = bounds.width * bounds.height
            let screenArea = screenWidth * screenHeight

            let shape: WindowShape
            if area < screenArea * 0.02 && isInCorner(bounds, screenFrame: screenFrame) {
                // Small window tucked into a corner → hiding spot
                shape = .small
            } else if aspectRatio > 2.5 {
                // Very wide → dedicated patrol platform
                shape = .wide
            } else if aspectRatio >= 0.6 && aspectRatio <= 1.4 {
                // Roughly square → jump-on block
                shape = .square
            } else {
                shape = .normal
            }

            platforms.append(WindowPlatform(
                windowID: windowID,
                topEdgeY: topEdgeY,
                minX: bounds.minX,
                maxX: bounds.maxX,
                width: bounds.width,
                height: bounds.height,
                shape: shape,
                ownerBundleID: ownerBundleID
            ))
        }

        // Only notify when something actually changed
        let newMap = Dictionary(uniqueKeysWithValues: platforms.map { ($0.windowID, $0) })
        guard newMap != lastPlatforms else { return }
        lastPlatforms = newMap
        onWindowsChanged?(platforms)
    }

    // MARK: - Helpers

    /// Returns true if the window's center is within 15% of any screen corner.
    private func isInCorner(_ rect: CGRect, screenFrame: CGRect) -> Bool {
        let cx = rect.midX
        let cy = rect.midY
        let marginX = screenFrame.width * 0.15
        let marginY = screenFrame.height * 0.15

        let nearLeft   = cx < screenFrame.minX + marginX
        let nearRight  = cx > screenFrame.maxX - marginX
        let nearTop    = cy < screenFrame.minY + marginY
        let nearBottom = cy > screenFrame.maxY - marginY

        return (nearLeft || nearRight) && (nearTop || nearBottom)
    }
}
