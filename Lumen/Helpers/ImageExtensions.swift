//
//  ImageExtensions.swift
//  Lumen
//
//  AI Skincare Assistant - Image Processing Utilities
//

import UIKit
import CoreImage
import VideoToolbox

extension UIImage {

    // MARK: - Image Preprocessing

    /// Resize image to target size maintaining aspect ratio
    func resized(to targetSize: CGSize) -> UIImage? {
        let size = self.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height

        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Crop image to square from center
    func croppedToSquare() -> UIImage? {
        let originalSize = self.size
        let sideLength = min(originalSize.width, originalSize.height)

        let x = (originalSize.width - sideLength) / 2
        let y = (originalSize.height - sideLength) / 2

        let cropRect = CGRect(x: x, y: y, width: sideLength, height: sideLength)

        guard let cgImage = self.cgImage?.cropping(to: cropRect) else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: self.scale, orientation: self.imageOrientation)
    }

    /// Convert to CVPixelBuffer for ML model input
    func toCVPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(buffer)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()

        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))

        return buffer
    }

    // MARK: - Image Quality Analysis

    /// Calculate average brightness of the image
    var averageBrightness: Double {
        guard let cgImage = self.cgImage else { return 0.5 }

        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent

        let context = CIContext()
        let filter = CIFilter(name: "CIAreaAverage")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter?.outputImage,
              let bitmap = context.createCGImage(outputImage, from: outputImage.extent) else {
            return 0.5
        }

        let data = bitmap.dataProvider?.data
        let ptr = CFDataGetBytePtr(data)

        let r = Double(ptr?[0] ?? 128) / 255.0
        let g = Double(ptr?[1] ?? 128) / 255.0
        let b = Double(ptr?[2] ?? 128) / 255.0

        return (r + g + b) / 3.0
    }

    /// Check if image is blurry using Laplacian variance
    var isBlurry: Bool {
        guard let cgImage = self.cgImage else { return false }

        let ciImage = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: "CIEdges")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)

        guard let outputImage = filter?.outputImage else { return false }

        let context = CIContext()
        let extent = outputImage.extent

        guard let bitmap = context.createCGImage(outputImage, from: extent) else {
            return false
        }

        // Calculate variance - low variance indicates blur
        // This is a simplified check
        let data = bitmap.dataProvider?.data
        guard let ptr = CFDataGetBytePtr(data) else { return false }

        var sum: Double = 0
        let pixelCount = min(1000, bitmap.width * bitmap.height)

        for i in 0..<pixelCount {
            sum += Double(ptr[i])
        }

        let average = sum / Double(pixelCount)
        var variance: Double = 0

        for i in 0..<pixelCount {
            let diff = Double(ptr[i]) - average
            variance += diff * diff
        }

        variance /= Double(pixelCount)

        // Lower variance = more blurry
        return variance < 100
    }

    // MARK: - Image Compression

    /// Compress image for storage while maintaining quality
    func compressed(quality: CGFloat = 0.8) -> Data? {
        return self.jpegData(compressionQuality: quality)
    }

    /// Optimize image size for analysis (smaller = faster processing)
    func optimizedForAnalysis() -> UIImage? {
        // Resize to max 1024x1024 for processing
        let maxDimension: CGFloat = 1024

        if size.width <= maxDimension && size.height <= maxDimension {
            return self
        }

        let targetSize = CGSize(width: maxDimension, height: maxDimension)
        return resized(to: targetSize)
    }
}

// MARK: - CIImage Extensions

extension CIImage {

    /// Convert CIImage to UIImage
    func toUIImage() -> UIImage? {
        let context = CIContext()
        guard let cgImage = context.createCGImage(self, from: self.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Image Processing Utilities

struct ImageProcessor {

    /// Enhance image for better analysis
    static func enhanceForAnalysis(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)

        // Apply filters to improve quality
        let filters = [
            ("CIColorControls", [
                kCIInputBrightnessKey: 0.05,
                kCIInputContrastKey: 1.1,
                kCIInputSaturationKey: 1.0
            ]),
            ("CISharpenLuminance", [
                kCIInputSharpnessKey: 0.4
            ])
        ]

        var outputImage = ciImage

        for (filterName, parameters) in filters {
            guard let filter = CIFilter(name: filterName) else { continue }
            filter.setValue(outputImage, forKey: kCIInputImageKey)

            for (key, value) in parameters {
                filter.setValue(value, forKey: key)
            }

            if let result = filter.outputImage {
                outputImage = result
            }
        }

        return outputImage.toUIImage()
    }

    /// Check if image meets quality requirements
    static func validateImageQuality(_ image: UIImage) -> (isValid: Bool, issues: [String]) {
        var issues: [String] = []

        // Check resolution
        if image.size.width < 480 || image.size.height < 480 {
            issues.append("Image resolution too low. Please use a higher quality camera.")
        }

        // Check brightness
        let brightness = image.averageBrightness
        if brightness < 0.2 {
            issues.append("Image too dark. Please ensure good lighting.")
        } else if brightness > 0.9 {
            issues.append("Image too bright. Reduce lighting or move away from direct light.")
        }

        // Check blur
        if image.isBlurry {
            issues.append("Image appears blurry. Hold camera steady and focus on your face.")
        }

        return (issues.isEmpty, issues)
    }
}
