//
//  CloudThoughtProvider.swift
//  liveondesk
//

import Foundation

/// Cloud-based thought provider using OpenAI's GPT-4o-mini API.
///
/// This is the highest-quality thought source but requires an API key and
/// network connectivity. Costs roughly $0.014 per 1,000 thoughts
/// (~$14/month for 1,000 DAU with 10 thoughts/session).
///
/// The provider constructs a system prompt with the pet's personality
/// and context, then requests a short, in-character response.
struct CloudThoughtProvider: ThoughtProviding {
    let name = "CloudProvider (GPT-4o-mini)"
    private let apiKey: String
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o-mini"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func isAvailable() async -> Bool {
        !apiKey.isEmpty
    }

    func generateThought(context: ThoughtContext) async throws -> String? {
        // Don't call the API for sleeping or falling — static phrases are fine
        guard context.petState != .sleeping,
              context.petState != .falling else {
            return nil
        }

        let systemPrompt = buildSystemPrompt(context: context)
        let userPrompt = buildUserPrompt(context: context)

        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "max_tokens": 40,
            "temperature": 0.9,
            "top_p": 0.95
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 8.0  // Fast timeout — we don't want to block the pet

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil  // Fail silently and fall through to next provider
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return nil
        }

        // Clean up the response — remove quotes, trim whitespace
        let cleaned = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        // Enforce max length for the bubble UI
        return cleaned.count > 60 ? String(cleaned.prefix(57)) + "..." : cleaned
    }

    // MARK: - Prompt Construction

    private func buildSystemPrompt(context: ThoughtContext) -> String {
        """
        Eres \(context.petName), una mascota virtual que vive en el escritorio de macOS de tu dueño. \
        Eres adorable, curioso y un poco sarcástico. Hablas en español. \
        Generas pensamientos cortos (máximo 50 caracteres) que aparecen en una burbuja de pensamiento. \
        NO uses hashtags. NO uses emojis excesivos (máximo 1). \
        Sé breve, gracioso y contextual. Responde SOLO con el pensamiento, nada más.
        """
    }

    private func buildUserPrompt(context: ThoughtContext) -> String {
        var parts: [String] = []

        parts.append("Estado actual: \(stateDescription(context.petState))")

        if let appName = context.activeAppName {
            parts.append("App activa del usuario: \(appName)")
        }

        parts.append("Hora: \(context.hourOfDay):00")

        return parts.joined(separator: ". ") + ". Genera un pensamiento corto."
    }

    private func stateDescription(_ state: PetState) -> String {
        switch state {
        case .falling:  return "cayendo por el escritorio"
        case .walking:  return "caminando sobre una ventana"
        case .idle:     return "quieto, contemplando"
        case .sleeping: return "dormido"
        case .jumping:  return "saltando entre ventanas"
        case .dancing:  return "bailando porque hay música"
        case .hiding:   return "escondido en una esquina"
        }
    }
}
