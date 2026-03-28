//
//  OnboardingView.swift
//  liveondesk
//

import SwiftUI
import PhotosUI

// MARK: - Onboarding State

/// Tracks the onboarding flow through its stages.
enum OnboardingStage: Equatable {
    case welcome
    case photoPick
    case processing
    case animalConfirm(detected: AnimalType)
    case nameEntry
    case complete(PetProfile)
}

/// Persistent profile created during onboarding.
struct PetProfile: Equatable {
    let name: String
    let animalType: AnimalType
    let dominantColor: NSColor
    let secondaryColor: NSColor?
    let isolatedImage: NSImage

    static func == (lhs: PetProfile, rhs: PetProfile) -> Bool {
        lhs.name == rhs.name && lhs.animalType == rhs.animalType
    }
}

// MARK: - View Model

@MainActor
@Observable
class OnboardingViewModel {
    var stage: OnboardingStage = .welcome
    var selectedPhoto: PhotosPickerItem?
    var petName: String = ""
    var errorMessage: String?
    var isProcessing = false

    // State preserved across stages
    private var analysisResult: PetAnalysisResult?
    private var confirmedAnimalType: AnimalType?
    private let processor = VisionImageProcessor()

    /// Called when the user picks a photo. Kicks off the Vision pipeline.
    func processSelectedPhoto() {
        guard let item = selectedPhoto else { return }
        isProcessing = true
        errorMessage = nil
        stage = .processing

        Task {
            do {
                // Load image data from PhotosPickerItem
                guard let data = try await item.loadTransferable(type: Data.self),
                      let nsImage = NSImage(data: data) else {
                    errorMessage = "No se pudo cargar la foto seleccionada."
                    stage = .photoPick
                    isProcessing = false
                    return
                }

                let result = try await processor.analyze(image: nsImage)
                analysisResult = result

                // If Vision detected cat or dog, confirm. Otherwise ask.
                if result.animalType != .other {
                    stage = .animalConfirm(detected: result.animalType)
                } else {
                    stage = .animalConfirm(detected: .other)
                }
            } catch {
                errorMessage = error.localizedDescription
                stage = .photoPick
            }
            isProcessing = false
        }
    }

    /// Called when the user confirms or overrides the detected animal type.
    func confirmAnimalType(_ type: AnimalType) {
        confirmedAnimalType = type
        stage = .nameEntry
    }

    /// Called when the user submits their pet name. Creates the profile.
    func finishOnboarding() {
        guard let result = analysisResult,
              let animalType = confirmedAnimalType,
              !petName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let profile = PetProfile(
            name: petName.trimmingCharacters(in: .whitespaces),
            animalType: animalType,
            dominantColor: result.dominantColor,
            secondaryColor: result.secondaryColor,
            isolatedImage: result.isolatedImage
        )
        stage = .complete(profile)
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content area
            Group {
                switch viewModel.stage {
                case .welcome:
                    welcomeStage
                case .photoPick:
                    photoPickStage
                case .processing:
                    processingStage
                case .animalConfirm(let detected):
                    animalConfirmStage(detected: detected)
                case .nameEntry:
                    nameEntryStage
                case .complete(let profile):
                    completeStage(profile: profile)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
        .frame(width: 440, height: 520)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "pawprint.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Text("LiveOnDesk")
                .font(.title2.bold())
            Spacer()
            stageIndicator
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private var stageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(index <= currentStageIndex ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var currentStageIndex: Int {
        switch viewModel.stage {
        case .welcome: return 0
        case .photoPick: return 1
        case .processing: return 2
        case .animalConfirm: return 3
        case .nameEntry: return 4
        case .complete: return 4
        }
    }

    // MARK: - Welcome

    private var welcomeStage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(.orange.gradient)

            Text("Tu mascota, en tu escritorio")
                .font(.title.bold())

            Text("Sube una foto de tu mascota y la convertiremos en un compañero animado que vivirá en tu escritorio, caminando sobre tus ventanas.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Spacer()

            Button(action: { viewModel.stage = .photoPick }) {
                Label("Empezar", systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
        }
    }

    // MARK: - Photo Pick

    private var photoPickStage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.orange.opacity(0.8))

            Text("Sube una foto de tu mascota")
                .font(.title2.bold())

            Text("Funciona mejor con fotos donde se vea completo el animal, desde un ángulo frontal o de perfil.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
            }

            Spacer()

            PhotosPicker(
                selection: $viewModel.selectedPhoto,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Elegir foto", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
            .onChange(of: viewModel.selectedPhoto) { _, _ in
                viewModel.processSelectedPhoto()
            }
        }
    }

    // MARK: - Processing

    private var processingStage: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("Analizando a tu mascota...")
                .font(.title3.bold())

            VStack(spacing: 8) {
                processingStep("Aislando del fondo", done: true)
                processingStep("Detectando especie", done: true)
                processingStep("Extrayendo colores", done: false)
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    private func processingStep(_ label: String, done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundColor(done ? .green : .secondary)
            Text(label)
                .font(.callout)
                .foregroundColor(done ? .primary : .secondary)
            Spacer()
        }
        .padding(.horizontal, 60)
    }

    // MARK: - Animal Confirm

    private func animalConfirmStage(detected: AnimalType) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: detected.symbolName)
                .font(.system(size: 48))
                .foregroundStyle(.orange.gradient)

            if detected != .other {
                Text("¿Tu mascota es un \(detected.rawValue.lowercased())?")
                    .font(.title2.bold())

                HStack(spacing: 16) {
                    Button("Sí, es correcto") {
                        viewModel.confirmAnimalType(detected)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Button("No, es otro") {
                        viewModel.confirmAnimalType(.other)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Text("¿Qué tipo de animal es?")
                    .font(.title2.bold())

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 12) {
                    ForEach(AnimalType.allCases) { type in
                        Button(action: { viewModel.confirmAnimalType(type) }) {
                            VStack(spacing: 6) {
                                Image(systemName: type.symbolName)
                                    .font(.title3)
                                Text(type.rawValue)
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 60)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()
        }
    }

    // MARK: - Name Entry

    private var nameEntryStage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "pencil.and.scribble")
                .font(.system(size: 48))
                .foregroundStyle(.orange.gradient)

            Text("¿Cómo se llama?")
                .font(.title2.bold())

            TextField("Nombre de tu mascota", text: $viewModel.petName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 250)
                .font(.title3)
                .multilineTextAlignment(.center)
                .onSubmit { viewModel.finishOnboarding() }

            Spacer()

            Button(action: { viewModel.finishOnboarding() }) {
                Label("Continuar", systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
            .disabled(viewModel.petName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Complete

    private func completeStage(profile: PetProfile) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green.gradient)

            Text("¡\(profile.name) está listo!")
                .font(.title.bold())

            Text("Tu \(profile.animalType.rawValue.lowercased()) ya vive en tu escritorio. Disfruta de su compañía.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            // Color preview
            HStack(spacing: 12) {
                colorSwatch("Primario", color: profile.dominantColor)
                if let secondary = profile.secondaryColor {
                    colorSwatch("Secundario", color: secondary)
                }
            }

            Spacer()

            Button(action: { dismiss() }) {
                Label("Cerrar", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
        }
    }

    private func colorSwatch(_ label: String, color: NSColor) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: color))
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                )
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    OnboardingView(viewModel: OnboardingViewModel())
}
