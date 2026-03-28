//
//  ThoughtEngine.swift
//  liveondesk
//

import Foundation
import AppKit

// MARK: - Thought Context

/// Rich context passed to thought providers so they can generate
/// contextually relevant thoughts.
struct ThoughtContext {
    let petState: PetState
    let petName: String
    let activeAppBundleID: String?
    let activeAppName: String?
    let hourOfDay: Int
    let minutesSinceLastUserActivity: Int // 0 = just active
}

// MARK: - Provider Protocol (Strategy Pattern)

/// Any source of pet thoughts must conform to this protocol.
/// Implementations range from static phrase banks to cloud LLM APIs.
protocol ThoughtProviding {
    /// A human-readable name for logging/debugging.
    var name: String { get }

    /// Whether this provider is currently available.
    /// (e.g., a cloud provider with no API key would return false)
    func isAvailable() async -> Bool

    /// Generate a thought given the current context.
    /// Returns nil if the provider declines to produce one (e.g., random gate).
    func generateThought(context: ThoughtContext) async throws -> String?
}

// MARK: - Thought Engine

/// Orchestrates thought generation using a priority chain of providers.
///
/// The chain tries providers in order:
/// 1. **CloudProvider** (GPT-4o-mini) — best quality, requires API key
/// 2. **StaticProvider** — always available, curated phrase bank
///
/// Apple Foundation Models and MLX will be added when macOS 26 ships.
/// For now, the architecture supports dropping them in without changes.
actor ThoughtEngine {
    private let providers: [ThoughtProviding]
    private let petName: String

    /// Minimum interval between thoughts (spec: 30s).
    private let minInterval: TimeInterval = 30.0
    private var lastThoughtTime: Date = .distantPast

    init(petName: String = "Mascota", apiKey: String? = nil) {
        self.petName = petName

        var chain: [ThoughtProviding] = []

        // Cloud provider goes first — best quality when available
        if let key = apiKey, !key.isEmpty {
            chain.append(CloudThoughtProvider(apiKey: key))
        }

        // Static provider is always the final fallback
        chain.append(StaticThoughtProvider())

        self.providers = chain
    }

    /// Attempts to generate a thought using the provider chain.
    /// Respects the minimum interval between thoughts.
    /// Returns nil if it's too soon or all providers decline.
    func generateThought(for state: PetState) async -> String? {
        // Rate limiting
        guard Date().timeIntervalSince(lastThoughtTime) >= minInterval else {
            return nil
        }

        // Sleeping pets don't think
        guard state != .sleeping else { return nil }

        let context = buildContext(state: state)

        for provider in providers {
            guard await provider.isAvailable() else { continue }

            do {
                if let thought = try await provider.generateThought(context: context) {
                    lastThoughtTime = Date()
                    return thought
                }
            } catch {
                // Log and try next provider
                print("[ThoughtEngine] \(provider.name) failed: \(error.localizedDescription)")
                continue
            }
        }

        return nil
    }

    private func buildContext(state: PetState) -> ThoughtContext {
        let frontApp = NSWorkspace.shared.frontmostApplication
        let hour = Calendar.current.component(.hour, from: Date())

        return ThoughtContext(
            petState: state,
            petName: petName,
            activeAppBundleID: frontApp?.bundleIdentifier,
            activeAppName: frontApp?.localizedName,
            hourOfDay: hour,
            minutesSinceLastUserActivity: 0 // TODO: integrate CGEventSource
        )
    }
}
