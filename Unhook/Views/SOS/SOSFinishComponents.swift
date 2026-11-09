import SwiftUI

/// A sun rising over a soft horizon, for the moment a craving is beaten. Set `risen` inside an animation to watch
/// it come up. With Reduce Motion it fades in at its risen height instead of moving.
struct SOSRisingSun: View {
    var risen: Bool
    /// The sun's diameter.
    var size: CGFloat = 116

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sceneWidth: CGFloat { size * 2.6 }
    /// Height of the sky above the horizon, with room for the sun's glow.
    private var horizonHeight: CGFloat { size * 1.2 }

    /// How far below its fully risen spot the sun sits: mostly hidden at first, two thirds up once risen.
    private var sunOffset: CGFloat {
        risen || reduceMotion ? size * 0.32 : size * 0.95
    }

    var body: some View {
        VStack(spacing: 0) {
            sky
            reflection
        }
        .frame(width: sceneWidth)
        .accessibilityHidden(true)
    }

    private var sky: some View {
        ZStack(alignment: .bottom) {
            // Morning light spreading from behind the horizon.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Palette.amber.opacity(0.55), Palette.rose.opacity(0.22), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 1.25
                    )
                )
                .frame(width: sceneWidth, height: size * 1.5)
                .offset(y: size * 0.6)
                .blur(radius: 10)
                .opacity(risen ? 1 : 0.15)

            sun
                .offset(y: sunOffset)
                .opacity(risen ? 1 : 0)
                .frame(width: sceneWidth, height: horizonHeight, alignment: .bottom)
                .clipped()

            horizon
        }
        .frame(width: sceneWidth, height: horizonHeight)
    }

    private var sun: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white, Palette.sun, Palette.amber, Palette.ember],
                    center: UnitPoint(x: 0.5, y: 0.38),
                    startRadius: 0,
                    endRadius: size * 0.62
                )
            )
            .frame(width: size, height: size)
            .shadow(color: Palette.amber.opacity(0.8), radius: 28)
    }

    private var horizon: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, Palette.sun.opacity(0.9), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1.5)
            .opacity(risen ? 1 : 0.4)
    }

    /// The sun's glow on the water below the horizon.
    private var reflection: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [Palette.amber.opacity(0.5), Palette.rose.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size * 0.7, height: size * 0.34)
            .blur(radius: 6)
            .opacity(risen ? 1 : 0)
    }
}

/// A glass chip the user can pick. Picked chips turn dawn gold with dark text.
struct SOSChoiceChip: View {
    let title: String
    var emoji: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji {
                    Text(emoji)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundStyle(isSelected ? Palette.inkText : Palette.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background { chipBackground }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var chipBackground: some View {
        if isSelected {
            Capsule()
                .fill(Brand.gradient)
                .shadow(color: Palette.amber.opacity(0.35), radius: 8, y: 2)
        } else {
            Capsule()
                .fill(Palette.surfaceRaised.opacity(0.65))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        }
    }
}

/// A glass chip with one idea to try while a craving fades. Not tappable.
struct SOSIdeaChip: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Palette.amber)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Palette.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Palette.surfaceRaised.opacity(0.65), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Lays chips out left to right and wraps them onto new rows, like words in a paragraph. A chip wider than the row
/// gets the full row and wraps its own text.
struct SOSFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(of: subviews, maxWidth: proposal.width ?? .infinity).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrangement(of: subviews, maxWidth: bounds.width).frames
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrangement(of subviews: Subviews, maxWidth: CGFloat) -> (size: CGSize, frames: [CGRect]) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            if size.width > maxWidth {
                size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
                size.width = min(size.width, maxWidth)
            }
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (CGSize(width: widest, height: y + rowHeight), frames)
    }
}
