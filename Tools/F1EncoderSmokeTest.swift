import Foundation

@main
struct F1EncoderSmokeTest {
    static func main() async throws {
        guard CommandLine.arguments.count == 3 else {
            fputs("usage: F1EncoderSmokeTest INPUT_VIDEO OUTPUT_BIN\n", stderr)
            exit(2)
        }

        let source = URL(fileURLWithPath: CommandLine.arguments[1])
        let destination = URL(fileURLWithPath: CommandLine.arguments[2])
        try await F1BINEncoder().export(
            source: source,
            destination: destination,
            placement: .zero,
            brightness: 0.75
        )

        let data = try Data(contentsOf: destination)
        let bodySize = data.count - F1LegacyHeader.data.count
        guard data.starts(with: F1LegacyHeader.data),
              bodySize > 0,
              bodySize.isMultiple(of: F1FrameEncoder.frameBytes) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let frames = bodySize / F1FrameEncoder.frameBytes
        print("validated \(frames) frames, \(data.count) bytes")
    }
}
