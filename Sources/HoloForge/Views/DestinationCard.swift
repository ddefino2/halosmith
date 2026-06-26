import SwiftUI

struct DestinationCard: View {
    @ObservedObject var store: ExportStore

    var body: some View {
        SectionCard(number: "04", title: "Choose where to save", subtitle: "Pick a folder, SD card, or connected drive") {
            HStack(spacing: 14) {
                Image(systemName: "externaldrive.fill.badge.plus")
                    .font(.system(size: 24))
                    .foregroundStyle(.tint)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.destinationURL?.lastPathComponent ?? "No destination selected")
                        .font(.headline)
                        .lineLimit(1)
                    Text(store.destinationURL?.deletingLastPathComponent().path(percentEncoded: false) ?? "You will choose the final filename too")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("Choose…", action: store.chooseDestination)
                    .controlSize(.large)
            }
            .padding(17)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
