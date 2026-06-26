import AppKit
import Foundation

@MainActor
final class ExportStore: ObservableObject {
    @Published var sourceURL: URL?
    @Published var destinationURL: URL?
    @Published var profile: FanProfile = .fMini11 {
        didSet { refreshDestinationExtension() }
    }
    @Published var isExporting = false
    @Published var isLoadingPreview = false
    @Published var previewImage: NSImage?
    @Published var placement: CGSize = .zero
    @Published var brightness = 0.75
    @Published var progressText = "Ready"
    @Published var errorMessage: String?
    @Published var didFinish = false

    var canExport: Bool {
        sourceURL != nil && destinationURL != nil && profile.isExportAvailable && !isExporting
    }

    func chooseSource() {
        let panel = NSOpenPanel()
        panel.title = "Choose a video"
        panel.prompt = "Choose Video"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setSource(url)
    }

    func acceptDroppedFile(_ url: URL) {
        setSource(url)
    }

    func chooseDestination() {
        let panel = NSSavePanel()
        panel.title = "Choose export destination"
        panel.prompt = "Use This Location"
        panel.nameFieldStringValue = suggestedFilename
        panel.allowedContentTypes = [.data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        destinationURL = url.deletingPathExtension().appendingPathExtension(profile.outputExtension)
        didFinish = false
    }

    func export() {
        guard let sourceURL, let destinationURL else { return }
        isExporting = true
        didFinish = false
        errorMessage = nil
        progressText = "Encoding…"

        Task {
            do {
                try await VideoExporter().export(
                    source: sourceURL,
                    destination: destinationURL,
                    profile: profile,
                    placement: placement,
                    brightness: brightness
                )
                progressText = "Export complete"
                didFinish = true
            } catch {
                progressText = "Export failed"
                errorMessage = error.localizedDescription
            }
            isExporting = false
        }
    }

    func revealExport() {
        guard let destinationURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
    }

    func resetPlacement() {
        placement = .zero
    }

    func resetBrightness() {
        brightness = 0.75
    }

    private var suggestedFilename: String {
        let stem = sourceURL?.deletingPathExtension().lastPathComponent ?? "hologram"
        return "\(stem)-\(profile == .fMini11 ? "f-mini11" : "large-42cm").\(profile.outputExtension)"
    }

    private func setSource(_ url: URL) {
        sourceURL = url
        previewImage = nil
        placement = .zero
        isLoadingPreview = true
        destinationURL = nil
        errorMessage = nil
        didFinish = false
        progressText = "Ready to configure"

        Task {
            do {
                let image = try await VideoPreviewGenerator().firstFrame(for: url)
                guard sourceURL == url else { return }
                previewImage = image
            } catch {
                guard sourceURL == url else { return }
                errorMessage = "The first video frame could not be loaded: \(error.localizedDescription)"
            }
            if sourceURL == url { isLoadingPreview = false }
        }
    }

    private func refreshDestinationExtension() {
        guard let destinationURL else { return }
        self.destinationURL = destinationURL
            .deletingPathExtension()
            .appendingPathExtension(profile.outputExtension)
        didFinish = false
    }
}
