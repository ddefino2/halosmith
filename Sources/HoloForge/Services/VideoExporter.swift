import AVFoundation
import Foundation

enum ExportFailure: LocalizedError {
    case conversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .conversionFailed(let message):
            message.isEmpty ? "The video converter could not create the export." : message
        }
    }
}

struct VideoExporter {
    func export(
        source: URL,
        destination: URL,
        profile: FanProfile,
        placement: CGSize,
        brightness: Double
    ) async throws {
        switch profile {
        case .fMini11:
            try await FMini11BINEncoder().export(
                source: source,
                destination: destination,
                placement: placement,
                brightness: brightness
            )
        case .large42BIN:
            try await F1BINEncoder().export(
                source: source,
                destination: destination,
                placement: placement,
                brightness: brightness
            )
        }
    }
}
