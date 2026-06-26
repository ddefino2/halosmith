import AVFoundation
import CoreGraphics
import Foundation

struct F1BINEncoder {
    static let framesPerSecond = 10.0

    func export(source: URL, destination: URL, placement: CGSize, brightness: Double) async throws {
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw ExportFailure.conversionFailed("The selected file does not contain a video track.")
        }

        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw ExportFailure.conversionFailed("The selected video has no playable duration.")
        }

        let frameCount = max(1, Int(ceil(durationSeconds * Self.framesPerSecond)))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1600, height: 1600)

        let temporaryURL = destination.deletingLastPathComponent()
            .appendingPathComponent(".halosmith-\(UUID().uuidString).bin")
        try? FileManager.default.removeItem(at: temporaryURL)
        FileManager.default.createFile(atPath: temporaryURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: temporaryURL)
        var completed = false

        defer {
            try? output.close()
            if !completed { try? FileManager.default.removeItem(at: temporaryURL) }
        }

        try output.write(contentsOf: F1LegacyHeader.data)

        for frameIndex in 0..<frameCount {
            try Task.checkCancellation()
            let seconds = min(Double(frameIndex) / Self.framesPerSecond, max(0, durationSeconds - 0.001))
            let requestedTime = CMTime(seconds: seconds, preferredTimescale: 6000)
            let result = try await generator.image(at: requestedTime)
            let squarePixels = try SquareFrameRenderer.render(
                image: result.image,
                placement: placement,
                brightness: brightness
            )
            try output.write(contentsOf: F1FrameEncoder.encode(squarePixels))
        }

        try output.synchronize()
        try output.close()
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        completed = true
    }
}

enum SquareFrameRenderer {
    static let size = 450

    static func render(image: CGImage, placement: CGSize, brightness: Double) throws -> [UInt8] {
        let bytesPerRow = size * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * size)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue
            | CGImageAlphaInfo.premultipliedFirst.rawValue

        let didRender = pixels.withUnsafeMutableBytes { storage -> Bool in
            guard let context = CGContext(
                data: storage.baseAddress,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else { return false }

            let canvas = CGFloat(size)
            let sourceWidth = CGFloat(image.width)
            let sourceHeight = CGFloat(image.height)
            let scale = max(canvas / sourceWidth, canvas / sourceHeight)
            let renderedWidth = sourceWidth * scale
            let renderedHeight = sourceHeight * scale
            let overflowX = max(0, renderedWidth - canvas)
            let overflowY = max(0, renderedHeight - canvas)
            let originX = (canvas - renderedWidth) / 2 + placement.width * overflowX / 2
            let originY = (canvas - renderedHeight) / 2 + placement.height * overflowY / 2

            context.interpolationQuality = .high
            context.setFillColor(CGColor.black)
            context.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))
            context.setAlpha(min(1, max(0.1, brightness)))
            context.translateBy(x: 0, y: canvas)
            context.scaleBy(x: 1, y: -1)
            context.draw(
                image,
                in: CGRect(x: originX, y: originY, width: renderedWidth, height: renderedHeight)
            )
            return true
        }

        guard didRender else {
            throw ExportFailure.conversionFailed("A square video frame could not be rendered.")
        }
        return pixels
    }
}

enum F1FrameEncoder {
    static let rays = 2700
    static let radialLEDs = 112
    static let bytesPerRay = 42
    static let imageBytes = rays * bytesPerRay
    static let paddingBytes = 1288
    static let frameBytes = imageBytes + paddingBytes

    private static let redBits = [16, 19, 22, 9, 12, 15, 2, 5]
    private static let greenBits = [17, 20, 23, 10, 13, 0, 3, 6]
    private static let blueBits = [18, 21, 8, 11, 14, 1, 4, 7]

    private struct Sample {
        let pixelOffset: Int
        let redColumn: Int
        let greenColumn: Int
        let blueColumn: Int
    }

    private static let samples: [Sample] = {
        let canvasSize = SquareFrameRenderer.size
        let center = Double(canvasSize - 1) / 2
        let radialStep = Double(canvasSize - 1) / Double(radialLEDs * 2 - 1)
        var result = [Sample]()
        result.reserveCapacity(rays * radialLEDs)

        for ray in 0..<rays {
            let angle = Double.pi * 2 * Double(ray) / Double(rays)
            let cosine = cos(angle)
            let sine = sin(angle)

            for led in 0..<radialLEDs {
                let radius = (Double(led) + 0.5) * radialStep
                let x = min(canvasSize - 1, max(0, Int((center + radius * cosine).rounded())))
                let y = min(canvasSize - 1, max(0, Int((center + radius * sine).rounded())))
                let groupBase = radialLEDs * 3 - 24 - (led / 8) * 24
                let slot = led % 8
                result.append(Sample(
                    pixelOffset: (y * canvasSize + x) * 4,
                    redColumn: groupBase + redBits[slot],
                    greenColumn: groupBase + greenBits[slot],
                    blueColumn: groupBase + blueBits[slot]
                ))
            }
        }
        return result
    }()

    static func encode(_ bgraPixels: [UInt8]) -> Data {
        precondition(bgraPixels.count == SquareFrameRenderer.size * SquareFrameRenderer.size * 4)
        var output = [UInt8](repeating: 0, count: frameBytes)
        var sampleIndex = 0

        for ray in 0..<rays {
            let rowStart = ray * bytesPerRay
            for _ in 0..<radialLEDs {
                let sample = samples[sampleIndex]
                sampleIndex += 1
                setBit(value: displayValue(bgraPixels[sample.pixelOffset + 2]), column: sample.redColumn, ray: ray, rowStart: rowStart, output: &output)
                setBit(value: displayValue(bgraPixels[sample.pixelOffset + 1]), column: sample.greenColumn, ray: ray, rowStart: rowStart, output: &output)
                setBit(value: displayValue(bgraPixels[sample.pixelOffset]), column: sample.blueColumn, ray: ray, rowStart: rowStart, output: &output)
            }
        }

        return Data(output)
    }

    private static func displayValue(_ value: UInt8) -> UInt8 {
        let blackPoint = 36
        let integerValue = Int(value)
        guard integerValue > blackPoint else { return 0 }

        let normalized = Double(integerValue - blackPoint) / Double(255 - blackPoint)
        let contrasted = pow(normalized, 1.65)
        return UInt8(min(255, max(0, Int((contrasted * 255).rounded()))))
    }

    private static func setBit(
        value: UInt8,
        column: Int,
        ray: Int,
        rowStart: Int,
        output: inout [UInt8]
    ) {
        let brightnessLevel = (Int(value) * 12 + 127) / 255
        let phase = column.isMultiple(of: 2) ? 0 : 6
        guard (ray + phase) % 12 < brightnessLevel else { return }
        output[rowStart + column / 8] |= UInt8(1 << (column % 8))
    }
}
