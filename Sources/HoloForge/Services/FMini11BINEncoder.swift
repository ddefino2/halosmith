import AVFoundation
import CoreGraphics
import Foundation

struct FMini11BINEncoder {
    static let defaultFramesPerSecond = 10.0

    func export(source: URL, destination: URL, placement: CGSize, brightness: Double) async throws {
        let asset = AVURLAsset(url: source)
        let duration = try await asset.load(.duration)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw ExportFailure.conversionFailed("The selected file does not contain a video track.")
        }

        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw ExportFailure.conversionFailed("The selected video has no playable duration.")
        }

        let nominalFrameRate = Double(try await videoTrack.load(.nominalFrameRate))
        let framesPerSecond = nominalFrameRate.isFinite && nominalFrameRate > 0
            ? min(60, nominalFrameRate)
            : Self.defaultFramesPerSecond
        let frameCount = max(1, Int(ceil(durationSeconds * framesPerSecond)))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 800, height: 800)

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

        try output.write(contentsOf: FMini11Container.header)

        for frameIndex in 0..<frameCount {
            try Task.checkCancellation()
            let seconds = min(Double(frameIndex) / framesPerSecond, max(0, durationSeconds - 0.001))
            let requestedTime = CMTime(seconds: seconds, preferredTimescale: 6000)
            let result = try await generator.image(at: requestedTime)
            let squarePixels = try SquareFrameRenderer.render(
                image: result.image,
                placement: placement,
                brightness: brightness
            )
            try output.write(contentsOf: FMini11FrameEncoder.encode(squarePixels))
        }

        try output.write(contentsOf: FMini11Container.trailer)
        try output.synchronize()
        try output.close()
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        completed = true
    }
}

enum FMini11Container {
    // Shortest known-good type-7 header from the supplied F-mini 11 clips.
    // Headers differ in length but are otherwise the same byte stream under a
    // per-file XOR key, so no video metadata or frame count is stored in them.
    private static let encodedHeader = "7je0pGdkZqRiZGOkoWSgpGhkaaSrZKqkrmSvpG1kbKR8ZH2kv2S+pLpku6R5ZHiksGSxpHNkcqR2ZHektWS0pFRkVaSXZJakkmSTpFFkUKSYZJmkW2RapF5kX6SdZJykjGSNpE9kTqRKZEuk"

    static let header: Data = {
        guard let data = Data(base64Encoded: encodedHeader),
              data.count == 108,
              data.starts(with: [0xEE, 0x37]) else {
            preconditionFailure("The bundled F-mini 11 header is invalid.")
        }
        return data
    }()

    static let trailer = Data(repeating: 0, count: 100_000)
}

enum FMini11FrameEncoder {
    static let rays = 300
    static let radialLEDs = 48
    static let bitPlanes = 5
    static let bytesPerPlane = 18
    static let imageBytes = rays * bitPlanes * bytesPerPlane
    // The final 1,600 bytes hold the frame's audio payload. Manufacturer files
    // use unsigned 8-bit PCM-style silence (0x80); audio preservation can be
    // added separately without changing the recovered image packing.
    static let audioBytesPerFrame = 1_600
    static let frameBytes = imageBytes + audioBytesPerFrame

    // The controller wires each group of eight LEDs as a reversed 24-bit RGB
    // block. This is the same physical ordering used by the 224-LED fan.
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
            // The F-mini controller advances in the opposite angular direction
            // from the large fan. Sampling forward keeps text upright and
            // prevents the horizontal mirroring seen with reverse rotation.
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
            let rowStart = ray * bitPlanes * bytesPerPlane
            for _ in 0..<radialLEDs {
                let sample = samples[sampleIndex]
                sampleIndex += 1
                write(value: displayValue(bgraPixels[sample.pixelOffset + 2]), column: sample.redColumn, rowStart: rowStart, output: &output)
                write(value: displayValue(bgraPixels[sample.pixelOffset + 1]), column: sample.greenColumn, rowStart: rowStart, output: &output)
                write(value: displayValue(bgraPixels[sample.pixelOffset]), column: sample.blueColumn, rowStart: rowStart, output: &output)
            }
        }

        for index in imageBytes..<frameBytes {
            output[index] = 0x80
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

    private static func write(value: UInt8, column: Int, rowStart: Int, output: inout [UInt8]) {
        let fiveBitValue = (Int(value) * 31 + 127) / 255
        let byteOffset = column / 8
        let mask = UInt8(1 << (column % 8))

        for plane in 0..<bitPlanes where fiveBitValue & (1 << (bitPlanes - 1 - plane)) != 0 {
            output[rowStart + plane * bytesPerPlane + byteOffset] |= mask
        }
    }
}
