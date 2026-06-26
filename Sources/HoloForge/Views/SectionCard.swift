import SwiftUI

struct SectionCard<Content: View>: View {
    let number: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(number: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.number = number
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Text(number)
                    .font(.caption.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(.tint)
                    .padding(.top, 3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.title3.weight(.semibold))
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07))
        }
        .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
    }
}
