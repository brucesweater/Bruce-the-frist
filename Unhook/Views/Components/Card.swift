import SwiftUI

/// The app's standard container: a frosted glass card with an optional tinted header.
struct Card<Content: View>: View {
    var title: LocalizedStringKey?
    var systemImage: String?
    var tint: Color = Palette.amber
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                HStack(spacing: 10) {
                    if let systemImage {
                        IconBadge(systemImage: systemImage, tint: tint, size: 28)
                    }
                    Text(title)
                        .font(.cardTitle)
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassSurface(cornerRadius: 24)
    }
}

/// A compact stat: a tinted symbol, a big rounded number and a small label.
struct StatTile: View {
    let title: LocalizedStringKey
    let value: String
    let systemImage: String
    var tint: Color = Palette.amber

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            IconBadge(systemImage: systemImage, tint: tint, size: 30)
            Text(value)
                .font(.display(24))
                .foregroundStyle(Palette.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            // The label wraps instead of cutting off at larger text sizes. Unit names are typed by the
            // user and can be long, so accessibility sizes get as many lines as they need.
            Text(title)
                .microLabel()
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassSurface(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }
}
