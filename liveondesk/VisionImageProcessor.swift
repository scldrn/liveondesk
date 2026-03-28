//
//  VisionImageProcessor.swift
//  liveondesk
//

import Vision
import AppKit
import CoreImage

// MARK: - Processing Results

/// The result of running the full Vision pipeline on a pet photo.
struct PetAnalysisResult {
    let isolatedImage: NSImage         // Pet with background removed
    let animalType: AnimalType         // Detected species
    let dominantColor: NSColor         // Primary fur/body color
    let secondaryColor: NSColor?       // Secondary color (if distinct enough)
    let originalImage: NSImage         // The original input
}

/// Supported animal types, auto-detected for cats and dogs,
/// manual selection for everything else.
enum AnimalType: String, CaseIterable, Identifiable {
    case cat     = "Gato"
    case dog     = "Perro"
    case bird    = "Pájaro"
    case rabbit  = "Conejo"
    case hamster = "Hámster"
    case fish    = "Pez"
    case other   = "Otro"

    var id: String { rawValue }

    /// SF Symbol name for UI display
    var symbolName: String {
        switch self {
        case .cat:     return "cat.fill"
        case .dog:     return "dog.fill"
        case .bird:    return "bird.fill"
        case .rabbit:  return "rabbit.fill"
        case .hamster: return "hare.fill"
        case .fish:    return "fish.fill"
        case .other:   return "pawprint.fill"
        }
    }
}

// MARK: - Errors

enum VisionProcessingError: LocalizedError {
    case noCGImage
    case foregroundMaskFailed
    case noResultsFromMask
    case maskApplicationFailed
    case colorExtractionFailed

    var errorDescription: String? {
        switch self {
        case .noCGImage:             return "No se pudo obtener CGImage de la foto."
        case .foregroundMaskFailed:  return "Vision no pudo generar la máscara de primer plano."
        case .noResultsFromMask:    return "Vision no devolvió resultados de máscara."
        case .maskApplicationFailed: return "No se pudo aplicar la máscara a la imagen."
        case .colorExtractionFailed: return "No se pudo extraer el color dominante."
        }
    }
}

// MARK: - Processor

/// Runs the on-device Vision pipeline to analyze a pet photo:
///
/// 1. **Foreground isolation** (`VNGenerateForegroundInstanceMaskRequest`)
/// 2. **Animal detection** (`VNRecognizeAnimalsRequest`) — cats & dogs auto
/// 3. **Dominant color extraction** (`CIAreaAverage`) on the isolated subject
///
/// All processing happens on-device, no network required, no cost.
actor VisionImageProcessor {

    /// Runs the full analysis pipeline. Call from any thread — the actor
    /// serializes access automatically.
    func analyze(image: NSImage) async throws -> PetAnalysisResult {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionProcessingError.noCGImage
        }

        // Run foreground isolation and animal detection in parallel
        async let isolated = isolateForeground(cgImage: cgImage)
        async let animalType = detectAnimalType(cgImage: cgImage)

        let isolatedImage = try await isolated
        let detectedType = try await animalType

        // Extract colors from the isolated image
        let (primary, secondary) = try extractDominantColors(from: isolatedImage)

        return PetAnalysisResult(
            isolatedImage: isolatedImage,
            animalType: detectedType,
            dominantColor: primary,
            secondaryColor: secondary,
            originalImage: image
        )
    }

    // MARK: - Step 1: Foreground Isolation

    /// Uses VNGenerateForegroundInstanceMaskRequest to separate the pet
    /// from the background. This is the same technology behind macOS
    /// "Lift Subject" — works with any animal, not just cats/dogs.
    private func isolateForeground(cgImage: CGImage) throws -> NSImage {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        try handler.perform([request])

        guard let result = request.results?.first else {
            throw VisionProcessingError.noResultsFromMask
        }

        // Generate the pixel buffer mask at the original image resolution
        let maskPixelBuffer = try result.generateScaledMaskForImage(
            forInstances: result.allInstances,
            from: handler
        )

        // Apply the mask to extract only the foreground pixels
        let ciImage = CIImage(cgImage: cgImage)
        let maskCI  = CIImage(cvPixelBuffer: maskPixelBuffer)

        // Blend: original image where mask is white, transparent where black
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            throw VisionProcessingError.maskApplicationFailed
        }
        blendFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blendFilter.setValue(CIImage(color: .clear).cropped(to: ciImage.extent), forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(maskCI, forKey: kCIInputMaskImageKey)

        guard let outputCI = blendFilter.outputImage else {
            throw VisionProcessingError.maskApplicationFailed
        }

        let context = CIContext()
        guard let outputCG = context.createCGImage(outputCI, from: ciImage.extent) else {
            throw VisionProcessingError.maskApplicationFailed
        }

        return NSImage(cgImage: outputCG, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    // MARK: - Step 2: Animal Type Detection

    /// Uses VNRecognizeAnimalsRequest to detect cats and dogs.
    /// Returns .other for unrecognized animals — the UI will prompt
    /// the user to select manually.
    private func detectAnimalType(cgImage: CGImage) throws -> AnimalType {
        let request = VNRecognizeAnimalsRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            return .other
        }

        // Take the highest confidence observation
        let topLabel = observations
            .flatMap { $0.labels }
            .max(by: { $0.confidence < $1.confidence })

        switch topLabel?.identifier.lowercased() {
        case "cat":  return .cat
        case "dog":  return .dog
        default:     return .other
        }
    }

    // MARK: - Step 3: Dominant Color Extraction

    /// Uses CIAreaAverage on the isolated (background-removed) image
    /// to extract the dominant fur/body color.
    ///
    /// Also attempts to find a secondary color by splitting the image
    /// into quadrants and finding the most distinct average.
    private func extractDominantColors(from image: NSImage) throws -> (NSColor, NSColor?) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw VisionProcessingError.colorExtractionFailed
        }

        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()

        // Primary: average of the entire image
        guard let primary = averageColor(of: ciImage, context: context) else {
            throw VisionProcessingError.colorExtractionFailed
        }

        // Secondary: find the most distinct quadrant average
        let w = ciImage.extent.width
        let h = ciImage.extent.height
        let quadrants = [
            CGRect(x: 0,     y: 0,     width: w/2, height: h/2),
            CGRect(x: w/2,   y: 0,     width: w/2, height: h/2),
            CGRect(x: 0,     y: h/2,   width: w/2, height: h/2),
            CGRect(x: w/2,   y: h/2,   width: w/2, height: h/2),
        ]

        var mostDistinct: NSColor?
        var maxDistance: CGFloat = 0

        for rect in quadrants {
            if let qColor = averageColor(of: ciImage.cropped(to: rect), context: context) {
                let dist = colorDistance(primary, qColor)
                if dist > maxDistance && dist > 0.15 {
                    maxDistance = dist
                    mostDistinct = qColor
                }
            }
        }

        return (primary, mostDistinct)
    }

    /// Returns the average color of a CIImage region.
    private func averageColor(of image: CIImage, context: CIContext) -> NSColor? {
        guard let filter = CIFilter(name: "CIAreaAverage") else { return nil }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: image.extent), forKey: "inputExtent")

        guard let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output,
                       toBitmap: &pixel,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpaceCreateDeviceRGB())

        return NSColor(
            red:   CGFloat(pixel[0]) / 255.0,
            green: CGFloat(pixel[1]) / 255.0,
            blue:  CGFloat(pixel[2]) / 255.0,
            alpha: 1.0
        )
    }

    /// Simple Euclidean distance in RGB space for comparing colors.
    private func colorDistance(_ a: NSColor, _ b: NSColor) -> CGFloat {
        guard let ac = a.usingColorSpace(.deviceRGB),
              let bc = b.usingColorSpace(.deviceRGB) else { return 0 }
        let dr = ac.redComponent   - bc.redComponent
        let dg = ac.greenComponent - bc.greenComponent
        let db = ac.blueComponent  - bc.blueComponent
        return sqrt(dr*dr + dg*dg + db*db)
    }
}
