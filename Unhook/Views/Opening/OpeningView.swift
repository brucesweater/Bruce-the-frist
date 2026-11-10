import SwiftUI

/// The opening animation, played once each time the app starts cold.
///
/// It tells Unhook's story with the shapes from the app icon: two gold dots circle inside a closed ring (the habit
/// loop), the ring opens, the dots fly out, and the night sky warms into dawn behind the name.
///
/// It is short, a tap skips it, and it never plays when the app is opened for SOS. With Reduce Motion on, the
/// finished picture simply fades in and out.
struct OpeningView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var isFinished = false

    /// Whether this launch plays the opening. UI tests and the screenshot run skip it.
    static var playsOnLaunch: Bool {
        #if DEBUG
        if frozenTime != nil { return true }
        if UITestSupport.isActive { return false }
        #endif
        return true
    }

    /// Debug builds can hold the opening at one moment (`-OpeningTime 0.9`) to check a frame.
    static var frozenTime: Double? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-OpeningTime"), arguments.indices.contains(index + 1) {
            return Double(arguments[index + 1])
        }
        #endif
        return nil
    }

    var body: some View {
        Group {
            if let frozen = Self.frozenTime {
                OpeningScene(time: frozen)
            } else if reduceMotion {
                OpeningScene(time: OpeningScene.length)
            } else {
                TimelineView(.animation) { timeline in
                    OpeningScene(time: timeline.date.timeIntervalSince(start))
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        // Decoration only: VoiceOver goes straight to the app underneath.
        .accessibilityHidden(true)
        .task {
            guard Self.frozenTime == nil else { return }
            if reduceMotion {
                try? await Task.sleep(for: .seconds(1.0))
            } else {
                try? await Task.sleep(for: .seconds(OpeningScene.escapeStart))
                if !isFinished { Haptics.soft() }
                try? await Task.sleep(for: .seconds(OpeningScene.length - OpeningScene.escapeStart))
            }
            finish()
        }
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        onFinished()
    }
}

/// One frame of the opening. Everything is worked out from `time` (seconds since the start), so a frame can be
/// drawn on its own for checking.
struct OpeningScene: View {
    var time: Double

    /// When the dots leave the ring.
    static let escapeStart = 0.8
    /// When the picture is complete and the app can fade in.
    static let length = 1.75

    // Sizes below are in the app icon's own units (the icon is 1024 wide), so the mark matches the icon.
    private static let ringRadius = 250.0
    private static let ringWidth = 110.0
    private static let gapAngle = 60.0
    /// The gap points up and to the right, like the icon.
    private static let gapDirection = -45.0
    private static let bigDot = (radius: 60.0, orbit: 122.0, rest: 359.0)
    private static let smallDot = (radius: 33.0, orbit: 128.0, rest: 467.0)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let unit = min(size.width, size.height) * 0.3 / Self.ringRadius
            ZStack {
                Color("LaunchBackground")
                DawnBackground(glow: dawn)
                    .opacity(Self.ramp(time, 0, 0.3))
                sunrise(in: size)
                mark(unit: unit)
                    .position(x: size.width / 2, y: size.height * 0.42)
                words(unit: unit)
                    .position(x: size.width / 2, y: size.height * 0.42 + (Self.ringRadius + 190) * unit)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Timing

    /// 0 while it's night, 1 once the sun is up.
    private var dawn: Double { Self.smooth(Self.ramp(time, Self.escapeStart, 1.5)) }
    /// How far the ring has opened, 0...1.
    private var opening: Double { Self.smooth(Self.ramp(time, 0.44, 0.64)) }

    /// 0 before `from`, 1 after `to`, a straight line in between.
    private static func ramp(_ time: Double, _ from: Double, _ to: Double) -> Double {
        min(max((time - from) / (to - from), 0), 1)
    }

    /// Slow start and slow stop.
    private static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }

    /// Fast start, then a small overshoot before settling, like a soft spring.
    private static func spring(_ x: Double) -> Double {
        let back = 1.4
        let y = x - 1
        return 1 + (back + 1) * y * y * y + back * y * y
    }

    // MARK: Pieces

    /// Warm light coming up from below the bottom edge.
    private func sunrise(in size: CGSize) -> some View {
        let radius = size.width * 0.95
        return Circle()
            .fill(RadialGradient(
                colors: [Palette.sun.opacity(0.9), Palette.amber.opacity(0.45), Palette.rose.opacity(0.18), .clear],
                center: .center,
                startRadius: 0,
                endRadius: radius
            ))
            .frame(width: radius * 2, height: radius * 2)
            .position(x: size.width / 2, y: size.height * (1.42 - 0.3 * dawn))
            .opacity(dawn)
    }

    /// The ring and its two dots.
    private func mark(unit: Double) -> some View {
        let diameter = Self.ringRadius * 2 * unit
        let gap = Self.gapAngle * opening
        let ring = Circle()
            .trim(from: 0, to: 1 - gap / 360)
            .stroke(style: StrokeStyle(lineWidth: Self.ringWidth * unit, lineCap: .round))
            .rotationEffect(.degrees(Self.gapDirection + gap / 2))
            .frame(width: diameter, height: diameter)
        let appear = Self.smooth(Self.ramp(time, 0, 0.25))
        return ZStack {
            // At night the ring is a dim loop; at dawn it glows like the icon.
            ring
                .foregroundStyle(Color.white.opacity(0.26))
                .opacity(1 - dawn)
            LinearGradient(colors: [.white, Color(hex: 0xFFE4A6)], startPoint: .top, endPoint: .bottom)
                .frame(width: diameter * 1.4, height: diameter * 1.4)
                .mask(ring)
                .shadow(color: Palette.sun.opacity(0.75), radius: 34 * unit)
                .opacity(dawn)
            // The small dot runs ahead and gets out first; the big one follows it.
            dot(Self.smallDot, headStart: 50, leaves: 0.66, unit: unit)
            dot(Self.bigDot, headStart: 0, leaves: Self.escapeStart, unit: unit)
        }
        .scaleEffect(0.9 + 0.1 * appear)
        .opacity(appear)
    }

    /// A gold dot: it circles inside the ring, then flies out through the gap to where it sits in the icon.
    /// `headStart` is how many degrees ahead it begins; `leaves` is when it reaches the gap and flies out.
    private func dot(_ shape: (radius: Double, orbit: Double, rest: Double), headStart: Double, leaves: Double, unit: Double) -> some View {
        let lap = Self.smooth(Self.ramp(time, 0.08, leaves - 0.02))
        let out = Self.spring(Self.ramp(time, leaves, leaves + 0.42))
        // About one and a quarter turns, ending at the gap.
        let angle = Self.gapDirection - (450 - headStart) * (1 - lap)
        let distance = shape.orbit + (shape.rest - shape.orbit) * out
        let radians = angle * .pi / 180
        let grow = Self.spring(Self.ramp(time, 0.05, 0.4))
        return Circle()
            .fill(Color(hex: 0xFFD875))
            .frame(width: shape.radius * 2 * unit, height: shape.radius * 2 * unit)
            .shadow(color: Palette.amber.opacity(0.35 + 0.45 * dawn), radius: (10 + 16 * dawn) * unit)
            .scaleEffect(grow)
            .offset(x: cos(radians) * distance * unit, y: sin(radians) * distance * unit)
    }

    /// The name and the line under it.
    private func words(unit: Double) -> some View {
        let name = Self.smooth(Self.ramp(time, 1.0, 1.35))
        let line = Self.smooth(Self.ramp(time, 1.15, 1.5))
        return VStack(spacing: 22 * unit) {
            Text(verbatim: "Unhook")
                .font(.system(size: 112 * unit, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: Palette.ink.opacity(0.5), radius: 8, y: 3)
                .opacity(name)
                .offset(y: (1 - name) * 14)
            Text("One day at a time.")
                .font(.system(size: 46 * unit, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
                .opacity(line)
                .offset(y: (1 - line) * 10)
        }
        .fixedSize()
    }
}

#Preview("Opening") {
    OpeningView {}
}

#Preview("Dots leaving") {
    OpeningScene(time: 1.0)
}
