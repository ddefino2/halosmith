import SwiftUI
import UniformTypeIdentifiers

struct SourceCard: View {
    @ObservedObject var store: ExportStore
    @State private var isTargeted = false

    var body: some View {
        SectionCard(number: "02", title: "Choose your video", subtitle: "MP4, MOV, M4V, or another macOS video format") {
            Button(action: store.chooseSource) {
                HStack(spacing: 16) {
                    Image(systemName: store.sourceURL == nil ? "film.stack" : "checkmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(store.sourceURL == nil ? Color.accentColor : .green)
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.sourceURL?.lastPathComponent ?? "Drop a video here or choose a file")
                            .font(.headline)
                            .lineLimit(1)
                        Text(store.sourceURL.map(fileSummary) ?? "Your original file is never modified")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(store.sourceURL == nil ? "Choose…" : "Replace…")
                        .foregroundStyle(.tint)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(isTargeted ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [7]))
                }
            }
            .buttonStyle(.plain)
            .onDrop(of: [UTType.movie.identifier, UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
                guard let provider = providers.first else { return false }
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    let url: URL?
                    if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    } else {
                        url = item as? URL
                    }
                    if let url { Task { @MainActor in store.acceptDroppedFile(url) } }
                }
                return true
            }
        }
    }

    private func fileSummary(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        let bytes = Int64(values?.fileSize ?? 0)
        return "\(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)) · \(url.pathExtension.uppercased())"
    }
}
