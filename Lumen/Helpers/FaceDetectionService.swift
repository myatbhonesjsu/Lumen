//
//  FaceDetectionService.swift
//  Lumen
//
//  Face detection using Apple's Vision framework
//

import Foundation
import UIKit
import Vision

class FaceDetectionService {
    static let shared = FaceDetectionService()

    private init() {}

    /// Detects faces in an image
    /// - Parameter image: The image to analyze
    /// - Returns: Number of faces detected and face quality score (0-1)
    func detectFaces(in image: UIImage) -> (faceCount: Int, quality: Double) {
        guard let cgImage = image.cgImage else {
            return (0, 0.0)
        }

        // Use more advanced face detection with landmarks for better accuracy
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3  // Latest version
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            guard let results = request.results, !results.isEmpty else {
                return (0, 0.0)
            }

            // Calculate quality score based on face size and position
            let quality = calculateFaceQuality(results: results, imageSize: CGSize(width: cgImage.width, height: cgImage.height))

            return (results.count, quality)
        } catch {
            print("Face detection error: \(error)")
            return (0, 0.0)
        }
    }

    /// Validates that an image is suitable for skin analysis
    /// - Parameter image: The image to validate
    /// - Returns: Validation result with face detection info
    func validateImage(_ image: UIImage) -> ValidationResult {
        let (faceCount, quality) = detectFaces(in: image)

        print("🔍 Face Detection: Found \(faceCount) faces, quality: \(String(format: "%.2f", quality))")

        if faceCount == 0 {
            print("❌ No face detected in image")
            return ValidationResult(
                isValid: false,
                message: "No face detected. Please take a clear photo of your face in good lighting.",
                faceCount: 0,
                quality: 0.0
            )
        }

        if faceCount > 1 {
            return ValidationResult(
                isValid: false,
                message: "Multiple faces detected. Please ensure only one face is in the frame.",
                faceCount: faceCount,
                quality: quality
            )
        }

        // Very lenient quality check - accept almost any detected face
        if quality < 0.05 {
            print("⚠️ Face quality too low: \(String(format: "%.2f", quality)) (minimum: 0.05)")
            return ValidationResult(
                isValid: false,
                message: "Face is too small or far away. Please move closer and center your face.",
                faceCount: faceCount,
                quality: quality
            )
        }

        print("✅ Face validation passed: \(faceCount) face(s), quality: \(String(format: "%.2f", quality))")
        return ValidationResult(
            isValid: true,
            message: "Face detected successfully",
            faceCount: faceCount,
            quality: quality
        )
    }

    /// Calculates face quality based on size and position
    private func calculateFaceQuality(results: [VNFaceObservation], imageSize: CGSize) -> Double {
        guard let face = results.first else { return 0.0 }

        // Calculate face size relative to image
        let faceSize = face.boundingBox.width * face.boundingBox.height

        // Calculate center position (ideal is centered)
        let faceCenterX = face.boundingBox.midX
        let faceCenterY = face.boundingBox.midY
        let centerDistance = sqrt(pow(faceCenterX - 0.5, 2) + pow(faceCenterY - 0.5, 2))

        // Quality factors - very lenient scoring:
        // - Size: Accept faces from 5% to 95% of image
        let sizeScore = min(1.0, max(0.0, (faceSize - 0.05) / 0.90))

        // - Position: More lenient on position (doesn't need to be perfectly centered)
        let positionScore = max(0.0, 1.0 - centerDistance)

        // - Confidence from Vision framework
        let confidenceScore = Double(face.confidence)

        // Weighted average - confidence is most important
        let quality = (sizeScore * 0.3) + (positionScore * 0.2) + (confidenceScore * 0.5)

        print("📊 Face Quality Details: size=\(String(format: "%.2f", faceSize)), sizeScore=\(String(format: "%.2f", sizeScore)), posScore=\(String(format: "%.2f", positionScore)), confScore=\(String(format: "%.2f", confidenceScore)), final=\(String(format: "%.2f", quality))")

        return quality
    }

    /// Result of image validation
    struct ValidationResult {
        let isValid: Bool
        let message: String
        let faceCount: Int
        let quality: Double
    }
}
