import SwiftUI

struct FanPickerCard: View {
    @ObservedObject var store: ExportStore

    var body: some View {
        SectionCard(number: "01", title: "Choose a fan", subtitle: "Your fan determines the output format and pixel dimensions") {
            HStack(spacing: 14) {
                ForEach(FanProfile.allCases) { profile in
                    Button {
                        withAnimation(.snappy(duration: 0.22)) { store.profile = profile }
                    } label: {
                        FanOption(profile: profile, isSelected: store.profile == profile)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct FanOption: View {
    let profile: FanProfile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: profile == .large42BIN ? "fan.fill" : "circle.hexagongrid.fill")
                .font(.system(size: 24))
                .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name).font(.headline)
                Text(profile.detail)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.75) : .secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color.accentColor.gradient : Color.secondary.opacity(0.07).gradient)
        .foregroundStyle(isSelected ? .white : .primary)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isSelected ? Color.white.opacity(0.18) : Color.secondary.opacity(0.12))
        }
    }
}
