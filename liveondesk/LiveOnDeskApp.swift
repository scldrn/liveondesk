//
//  LiveOnDeskApp.swift
//  liveondesk
//

import SwiftUI

@main
struct LiveOnDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Sin WindowGroup — el panel lo gestiona AppDelegate.
        // Settings sirve como punto de entrada a preferencias futuras.
        Settings {
            EmptyView()
        }
    }
}
