//
//  SettingsView.swift
//  liveondesk
//

import SwiftUI

struct SettingsView: View {
    @Binding var showOnboarding: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("LiveOnDesk")
                .font(.title2.bold())

            Text("Preferencias")
                .font(.headline)
                .foregroundColor(.secondary)

            Divider()

            // Onboarding action
            Button(action: {
                openWindow(id: "onboarding")
            }) {
                Label("Configurar mascota", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)

            Spacer()

            Text("v0.1.0 — Fase de desarrollo")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(30)
        .frame(minWidth: 320, minHeight: 280)
    }
}
