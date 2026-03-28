//
//  LiveOnDeskApp.swift
//  liveondesk
//

import SwiftUI

@main
struct LiveOnDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showOnboarding = false

    var body: some Scene {
        // Sin WindowGroup — el panel lo gestiona AppDelegate.
        // Settings sirve como punto de entrada a preferencias.
        Settings {
            SettingsView(showOnboarding: $showOnboarding)
        }

        // Onboarding window
        Window("Onboarding", id: "onboarding") {
            OnboardingView(viewModel: OnboardingViewModel())
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 440, height: 520)
        .windowResizability(.contentSize)
    }
}
