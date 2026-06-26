import AppKit
import AVFoundation

struct VideoPreviewGenerator {
    func firstFrame(for url: URL) async throws -> NSImage {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = NSSize(width: 1600, height: 1600)
        let result = try await generator.image(at: .zero)
        return NSImage(cgImage: result.image, size: .zero)
    }
}
