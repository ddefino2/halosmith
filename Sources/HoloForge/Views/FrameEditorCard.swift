import SwiftUI

struct FrameEditorCard: View {
    @ObservedObject var store: ExportStore
    @State private var dragStart: CGSize?

    var body: some View {
        SectionCard(
            number: "03",
            title: "Frame the video",
            subtitle: "Drag to choose the 1:1 crop used for the entire clip"
        ) {
            HStack(alignment: .center, spacing: 28) {
                preview
                    .frame(width: 320, height: 320)

                VStack(alignment: .leading, spacing: 16) {
                    Label(store.profile.outputSizeLabel, systemImage: "aspectratio.fill")
                        .font(.headline)
                    Text("The video fills the square without stretching. Anything outside the frame is cropped.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Position applies to every frame", systemImage: "film.stack")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Brightness", systemImage: "sun.max.fill")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(store.brightness, format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $store.brightness, in: 0.10...1, step: 0.05)
                            .accessibilityLabel("Export brightness")
                    }
                    Button("Center Video") {
                        withAnimation(.snappy) { store.resetPlacement() }
                    }
                    .disabled(store.placement == .zero)
                    Button("Reset Brightness") {
                        withAnimation(.snappy) { store.resetBrightness() }
                    }
                    .disabled(abs(store.brightness - 0.75) < 0.001)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 290)
            }
        }
    }

    private var preview: some View {
        GeometryReader { geometry in
            let box = geometry.size
            ZStack {
                Color.black
                if store.isLoadingPreview {
                    ProgressView("Loading first frame…")
                        .tint(.white)
                        .foregroundStyle(.white)
                } else if let image = store.previewImage {
                    let imageSize = image.size
                    let scale = max(box.width / imageSize.width, box.height / imageSize.height)
                    let rendered = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
                    let overflow = CGSize(
                        width: max(0, rendered.width - box.width),
                        height: max(0, rendered.height - box.height)
                    )

                    Image(nsImage: image)
                        .resizable()
                        .frame(width: rendered.width, height: rendered.height)
                        .colorMultiply(Color(
                            red: store.brightness,
                            green: store.brightness,
                            blue: store.brightness
                        ))
                        .offset(
                            x: store.placement.width * overflow.width / 2,
                            y: store.placement.height * overflow.height / 2
                        )
                        .gesture(dragGesture(overflow: overflow))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "rectangle.dashed")
                            .font(.system(size: 30))
                        Text("Choose a video to preview its crop")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
            }
            .clipped()
            .overlay(alignment: .topLeading) {
                Text("1:1 PREVIEW")
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(10)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.22))
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func dragGesture(overflow: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragStart == nil { dragStart = store.placement }
                let start = dragStart ?? .zero
                store.placement = CGSize(
                    width: normalized(start.width, translation: value.translation.width, overflow: overflow.width),
                    height: normalized(start.height, translation: value.translation.height, overflow: overflow.height)
                )
            }
            .onEnded { _ in dragStart = nil }
    }

    private func normalized(_ start: CGFloat, translation: CGFloat, overflow: CGFloat) -> CGFloat {
        guard overflow > 0 else { return 0 }
        return min(1, max(-1, start + translation * 2 / overflow))
    }
}
