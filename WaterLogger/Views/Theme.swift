import SwiftUI

// MARK: - Color helpers

extension Color {
    static let oceanDeep    = Color(hex: "070a1e")
    static let oceanMid     = Color(hex: "0c1830")
    static let oceanDark    = Color(hex: "071520")
    static let iosBlue      = Color(hex: "3b9eff")
    static let iosBlueLight = Color(hex: "62c3ff")
    static let iosBlueDark  = Color(hex: "1a7fe8")

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Glass card

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var tintColor: Color?

    func body(content: Content) -> some View {
        content
            .background { glassBackground }
    }

    private var glassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(tintColor.map { $0.opacity(0.10) } ?? Color.white.opacity(0.075))
            // Top refraction shine
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.white.opacity(0.055), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(maxHeight: 60)
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            // Border
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    tintColor.map { $0.opacity(0.27) } ?? Color.white.opacity(0.14),
                    lineWidth: 0.5
                )
        }
        .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, tint: Color? = nil) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, tintColor: tint))
    }
}

// MARK: - Beverage dot

struct BevDotView: View {
    let bevType: BeverageType
    var size: CGFloat = 38
    var emojiMode: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(bevType.accentColor.opacity(0.12))
                .overlay(
                    Circle().strokeBorder(bevType.accentColor.opacity(0.33), lineWidth: 1.5)
                )
            if emojiMode {
                Text(bevType.emoji)
                    .font(.system(size: size * 0.52))
            } else {
                Text(bevType.initial)
                    .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                    .foregroundStyle(bevType.accentColor)
                    .kerning(-0.5)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Progress ring

struct ProgressRingView: View {
    var progress: Double
    var consumed: Int
    var goal: Int

    @State private var animProgress: Double = 0
    @State private var hasAnimatedEntrance = false

    private let size: CGFloat = 214
    private let lineWidth: CGFloat = 17

    var body: some View {
        ZStack {
            // Outer ambient glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.iosBlue.opacity(animProgress * 0.12), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size + 16, height: size + 16)

            // Track
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: lineWidth)

            // Halo (wider, dimmer)
            Circle()
                .trim(from: 0, to: animProgress)
                .stroke(Color.iosBlue.opacity(0.12), style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Progress arc
            Circle()
                .trim(from: 0, to: animProgress)
                .stroke(
                    LinearGradient(
                        colors: [Color.iosBlueLight, Color.iosBlueDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.iosBlue.opacity(0.5), radius: 8)

            // Center text
            VStack(spacing: 4) {
                Text(consumed.formatted())
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                    .kerning(-2)

                Text("of \(goal.formatted()) ml")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
                    .kerning(-0.2)

                Text("\(Int(min(progress, 1) * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.iosBlue)
                    .kerning(0.4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .background {
                        Capsule()
                            .fill(Color.iosBlue.opacity(0.16))
                            .overlay(Capsule().strokeBorder(Color.iosBlue.opacity(0.38), lineWidth: 0.5))
                    }
                    .padding(.top, 4)
            }
        }
        .frame(width: size, height: size)
        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 1.3), value: animProgress)
        .onAppear {
            // If data was already loaded before the view appeared, animate immediately.
            if progress > 0 && !hasAnimatedEntrance {
                hasAnimatedEntrance = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    animProgress = min(progress, 1)
                }
            }
        }
        .onChange(of: progress) { _, newVal in
            if !hasAnimatedEntrance {
                // First real data — use the slow entrance timing curve (no withAnimation wrapper,
                // so the .animation modifier above applies).
                hasAnimatedEntrance = true
                animProgress = min(newVal, 1)
            } else {
                withAnimation(.easeInOut(duration: 0.8)) {
                    animProgress = min(newVal, 1)
                }
            }
        }
    }
}

// MARK: - Circle reveal shape (FAB → log sheet)

struct CircleReveal: Shape {
    var progress: CGFloat
    var center: CGPoint

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let maxR = hypot(
            max(center.x, rect.width  - center.x),
            max(center.y, rect.height - center.y)
        ) + 10
        let r = maxR * progress
        return Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }
}

// MARK: - App background

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.oceanDeep, Color.oceanMid, Color.oceanDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
