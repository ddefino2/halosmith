import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var store = ExportStore()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.accentColor.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    FanPickerCard(store: store)
                    SourceCard(store: store)
                    FrameEditorCard(store: store)
                    DestinationCard(store: store)
                    exportFooter
                }
                .padding(44)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
        }
        .alert("Export problem", isPresented: errorBinding) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "Unknown error")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            if let logoImage = Self.logoImage {
                Image(nsImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .cyan.opacity(0.2), radius: 18, y: 8)
                    .accessibilityLabel("Halosmith")
            } else {
                Text("Halosmith")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
            }

            Text("Prepare video for your holographic fan")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Text(AppVersion.displayName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                Text("MACOS")
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private static let logoImage: NSImage? = {
        let filename = "halosmith-logo-hologram"
        if let bundledURL = Bundle.main.url(forResource: filename, withExtension: "png") {
            return NSImage(contentsOf: bundledURL)
        }

        let developmentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("\(filename).png")
        return NSImage(contentsOf: developmentURL)
    }()

    private var exportFooter: some View {
        HStack(spacing: 14) {
            if store.isExporting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: store.didFinish ? "checkmark.circle.fill" : "circle.dotted")
                    .foregroundStyle(store.didFinish ? .green : .secondary)
            }
            Text(store.progressText)
                .foregroundStyle(.secondary)
            Spacer()
            if store.didFinish {
                Button("Show in Finder") { store.revealExport() }
            }
            Button {
                store.export()
            } label: {
                Label("Export for Fan", systemImage: "arrow.up.forward.app.fill")
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!store.canExport)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )
    }
}

enum AppVersion {
    private static let fallbackVersion = "0.2.3"

    static var displayName: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "Halosmith v\(version ?? fallbackVersion)"
    }
}
