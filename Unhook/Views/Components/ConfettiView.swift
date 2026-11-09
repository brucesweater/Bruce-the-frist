import SwiftUI

/// A light confetti burst in dawn colors, drawn with Canvas: no assets, no dependencies. Pieces fall, sway and
/// flip like paper. With Reduce Motion they don't move at all: they appear where they are and fade away.
/// The timeline stops once the burst is over, so a finished burst costs nothing.
struct ConfettiView: View {
    private struct Particle {
        let x: Double
        /// Resting height (share of the screen) for the Reduce Motion version.
        let y: Double
        let delay: Double
        let speed: Double
        let size: Double
        let spin: Double
        let drift: Double
        let isRound: Bool
        let color: Color
    }

    private static let palette: [Color] = [Palette.sun, Palette.amber, Palette.ember, Palette.rose, Palette.violet, Palette.mint]
    /// Long enough for the slowest piece to fall past the bottom edge.
    private static let fallDuration: Double = 4.5
    /// How long the still pieces stay (fading in and out) with Reduce Motion.
    private static let stillDuration: Double = 2.6
    private static let stillCount = 56

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [Particle] = (0..<90).map { _ in ConfettiView.makeParticle() }
    @State private var start = Date.now
    @State private var isFinished = false

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: isFinished)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                if reduceMotion {
                    drawStill(&context, size: size, elapsed: elapsed)
                } else {
                    drawFalling(&context, size: size, elapsed: elapsed)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            let duration = reduceMotion ? Self.stillDuration : Self.fallDuration
            try? await Task.sleep(for: .seconds(duration))
            isFinished = true
        }
    }

    private static func makeParticle() -> Particle {
        Particle(
            x: .random(in: 0...1),
            y: .random(in: 0.04...0.5),
            delay: .random(in: 0...0.5),
            speed: .random(in: 0.45...0.9),
            size: .random(in: 7...12),
            spin: .random(in: 1...4),
            drift: .random(in: -0.08...0.08),
            isRound: Double.random(in: 0...1) < 0.25,
            color: palette.randomElement() ?? Palette.sun
        )
    }

    private func drawFalling(_ context: inout GraphicsContext, size: CGSize, elapsed: Double) {
        guard elapsed < Self.fallDuration else { return }
        let width = Double(size.width)
        let height = Double(size.height)
        for particle in particles {
            let t = elapsed - particle.delay
            guard t > 0 else { continue }
            let y: Double = -20 + t * particle.speed * height * 0.7
            guard y < height + 20 else { continue }
            let x: Double = (particle.x + particle.drift * t) * width + sin(t * particle.spin * 2) * 14
            // Narrows and widens as it turns over, like a falling scrap of paper.
            let flip: Double = 0.2 + 0.8 * abs(cos(t * particle.spin * 2.4))

            var piece = context
            piece.translateBy(x: x, y: y)
            piece.rotate(by: .radians(t * particle.spin * 3))
            piece.scaleBy(x: flip, y: 1)
            piece.fill(path(for: particle), with: .color(particle.color))
        }
    }

    private func drawStill(_ context: inout GraphicsContext, size: CGSize, elapsed: Double) {
        guard elapsed < Self.stillDuration else { return }
        let width = Double(size.width)
        let height = Double(size.height)
        for particle in particles.prefix(Self.stillCount) {
            let fadeIn = min(max((elapsed - particle.delay) / 0.35, 0), 1)
            let fadeOut = min(max((Self.stillDuration - elapsed) / 0.9, 0), 1)
            let alpha = min(fadeIn, fadeOut)
            guard alpha > 0 else { continue }

            var piece = context
            piece.opacity = alpha
            piece.translateBy(x: particle.x * width, y: particle.y * height)
            piece.rotate(by: .radians(particle.spin))
            piece.fill(path(for: particle), with: .color(particle.color))
        }
    }

    private func path(for particle: Particle) -> Path {
        if particle.isRound {
            let diameter = particle.size * 0.6
            return Path(ellipseIn: CGRect(x: -diameter / 2, y: -diameter / 2, width: diameter, height: diameter))
        }
        return Path(CGRect(x: -particle.size / 2, y: -particle.size / 4, width: particle.size, height: particle.size / 2))
    }
}

#Preview {
    ZStack {
        DawnBackground()
        ConfettiView()
    }
}
