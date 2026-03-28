//
//  ThoughtProvider.swift
//  liveondesk
//

import AppKit
import Foundation

/// Provides contextual phrases for the pet's thought bubbles.
///
/// Uses a layered strategy:
/// 1. State-specific mandatory phrases (e.g., falling always gets a reaction)
/// 2. Contextual phrases based on the active application
/// 3. Time-of-day phrases
/// 4. State-specific fallback phrases
///
/// A probability gate ensures the pet doesn't over-think — roughly 65% of
/// non-mandatory calls produce a phrase, the rest return nil.
struct ThoughtProvider {

    static func phrase(for state: PetState) -> String? {
        // States with guaranteed phrases
        switch state {
        case .sleeping:
            return nil  // No thoughts while sleeping
        case .falling:
            return ["¡AAAH!", "¡Weeeee!", "¡Gravedad!", "¡No otra vez!", "¡Mi ventanaaaa!"].randomElement()!
        case .jumping:
            return ["¡Allá voy!", "¡Salto!", "¡Wheee!", "¡Arriba!", "¡Parkour!"].randomElement()!
        case .dancing:
            return ["♪ ♫ ♪", "¡A bailar!", "¡Música!", "🎵 Groovy 🎵", "¡Buena canción!", "Sube el volumen 🎶"].randomElement()!
        case .hiding:
            return ["Shhh...", "No me ven 👀", "Escondido", "🤫", "Aquí nadie me encuentra", "Modo ninja"].randomElement()!
        default:
            break
        }

        // Probability gate — not every moment needs a thought
        guard Double.random(in: 0...1) < 0.65 else { return nil }

        if let phrase = contextualPhrase() { return phrase }
        return stateFallback(for: state)
    }

    // MARK: - Contextual Intelligence

    private static func contextualPhrase() -> String? {
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        let hour = Calendar.current.component(.hour, from: Date())

        let byApp: [String: [String]] = [
            // Apple dev tools
            "com.apple.dt.Xcode":               ["¿Compilando otra vez?", "Ese bug no se va solo...", "¿Build succeeded?", "¡Xcode se colgó otra vez!", "SwiftUI previews... paciencia"],
            "com.apple.dt.instruments":          ["Hmm, ¿memory leak?", "Profiling... suena serio"],
            "com.apple.Terminal":                ["Los comandos me dan respeto", "¿rm -rf?", "Eso suena peligroso...", "¿Sudo?"],
            "com.apple.finder":                  ["¿Buscando algo?", "Orden en el escritorio...", "Muchas ventanas de Finder..."],
            "com.apple.Safari":                  ["Mucho scroll hoy...", "¿Investigando algo?", "Otra pestaña más..."],
            "com.apple.Music":                   ["♪ Esto suena bien...", "¡Música!"],
            "com.apple.Preview":                 ["¿Revisando algo?"],
            "com.apple.Notes":                   ["Apuntando ideas...", "Buenas notas"],

            // Browsers
            "com.google.Chrome":                 ["¿Cuántas pestañas tienes?", "Memoria RAM: RIP", "Otra pestaña más..."],
            "org.mozilla.firefox":               ["Firefox, clásico", "¿Modo privado?"],
            "company.thebrowser.Browser":        ["Arc es bonito", "¿Cuántos espacios tienes?"],

            // Code editors
            "com.microsoft.VSCode":              ["¿Cuántas extensiones tienes?", "Command palette al rescate", "Copilot pensando..."],
            "com.todesktop.230313mzl4w4u92":     ["Cursor AI al mando", "¿El AI terminó tu código?"],
            "com.jetbrains.intellij":            ["JetBrains, serio", "¿Refactorizando?"],
            "com.sublimetext.4":                 ["Sublime Text, clásico"],

            // Terminal alternatives
            "com.googlecode.iterm2":             ["iTerm, el terminal serio", "¿Tmux o sin tmux?"],
            "com.mitchellh.ghostty":             ["Ghostty, elegante", "Terminal moderno"],

            // Communication
            "com.tinyspeck.slackmacgap":         ["¿Otro mensaje?", "Notificaciones infinitas...", "¿Thread o canal?"],
            "com.microsoft.teams":               ["Teams otra vez...", "¿Meeting?", "Cámara apagada, ¿verdad?"],
            "com.hnc.Discord":                   ["¿Gaming o trabajo?", "Discord siempre abierto"],
            "ru.keepcoder.Telegram":             ["Telegram pita", "¿Cuántos grupos?"],

            // Productivity
            "com.figma.Desktop":                 ["¿Diseñando algo bonito?", "Ese padding está raro 👀", "¿Auto layout?"],
            "com.notion.id":                     ["Muchas notas hoy...", "¿Eso es productividad?"],
            "com.linear.app":                    ["Issues pendientes...", "¿Cuántos tickets hoy?"],

            // Music & Video
            "com.spotify.client":                ["¡Buena canción!", "¡Modo baile activado!", "Sube el volumen 🎵"],
            "us.zoom.xos":                       ["¿Otro Zoom?", "Fondo virtual activado", "Mute, por favor"],
        ]

        let byTime: [(range: ClosedRange<Int>, phrases: [String])] = [
            (0...5,   ["Son las tantas...", "¿No duermes?", "Yo también soy de noche 🌙"]),
            (6...8,   ["¡Buenos días!", "¿Café antes que código?", "Mañana mañana..."]),
            (9...11,  ["Buen ritmo de trabajo", "¿Cómo va la mañana?"]),
            (12...14, ["¿Ya comiste?", "Hora de comer...", "Yo también tengo hambre"]),
            (15...17, ["Buena tarde", "¿Cómo va el día?", "Ya pasó lo peor"]),
            (18...20, ["Ya casi terminas...", "¿Qué queda pendiente?", "Últimos commits del día"]),
            (21...23, ["Es tarde ya...", "Deberías descansar...", "Mañana con más energía"]),
        ]

        // App-based phrase (55% chance when matched)
        if Double.random(in: 0...1) < 0.55,
           let phrases = byApp[bundleID],
           let phrase = phrases.randomElement() {
            return phrase
        }

        // Time-based phrase (35% chance when matched)
        if Double.random(in: 0...1) < 0.35,
           let bucket = byTime.first(where: { $0.range.contains(hour) }),
           let phrase = bucket.phrases.randomElement() {
            return phrase
        }

        return nil
    }

    private static func stateFallback(for state: PetState) -> String {
        let byState: [PetState: [String]] = [
            .walking: ["¡A explorar!", "¿Qué hay por aquí?", "Patrullando 🐾", "Hmm...", "¿Alguien me ve?", "Día tranquilo"],
            .idle:    ["...", "Hmm...", "¿Todo bien?", "Contemplando...", "Aburrido", "Modo zen"],
        ]
        return byState[state]?.randomElement() ?? "..."
    }
}
