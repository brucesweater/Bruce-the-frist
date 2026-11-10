import SwiftUI

/// The main call to action. By default it's warm dawn gold with dark text; pass a gradient to use a habit's or a
/// screen's own colors (white text).
struct PrimaryButtonStyle: ButtonStyle {
    var gradient: LinearGradient
    var foreground: Color
    var glow: Color

    /// The default call to action: dawn gold with dark text and a soft glow.
    init() {
        gradient = Brand.gradient
        foreground = Palette.inkText
        glow = Palette.amber
    }

    /// A call to action in custom colors.
    init(gradient: LinearGradient, foreground: Color = .white, glow: Color = .clear) {
        self.gradient = gradient
        self.foreground = foreground
        self.glow = glow
    }

    func makeBody(configuration: Configuration) -> some View {
        PrimaryButton(configuration: configuration, gradient: gradient, foreground: foreground, glow: glow)
    }

    private struct PrimaryButton: View {
        let configuration: ButtonStyleConfiguration
        let gradient: LinearGradient
        let foreground: Color
        let glow: Color
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(gradient, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
                .shadow(color: glow.opacity(isEnabled ? 0.45 : 0), radius: 16, y: 6)
                .opacity(isEnabled ? 1 : 0.45)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
        }
    }
}

/// A quieter action: a frosted glass capsule with white text.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.semibold))
            .foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Palette.surfaceRaised.opacity(0.7), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
