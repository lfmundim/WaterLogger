import SwiftUI

struct SplashView: View {
    var onFinished: () -> Void

    @State private var iconScale: CGFloat = 0.82
    @State private var iconOpacity: Double = 0
    @State private var nameOpacity: Double = 0
    @State private var nameOffset: CGFloat = 10
    @State private var exitScale: CGFloat = 1.0
    @State private var exitOpacity: Double = 1.0

    var body: some View {
        ZStack {
            // Same dark gradient as AppBackground so the transition is invisible
            LinearGradient(
                colors: [Color(hex: "060912"), Color(hex: "0b1a38"), Color(hex: "060f1c")],
                startPoint: UnitPoint(x: 0.3, y: 0),
                endPoint: UnitPoint(x: 0.7, y: 1)
            )
            .ignoresSafeArea()

            // Ambient halo behind icon
            RadialGradient(
                colors: [Color.iosBlue.opacity(0.22), .clear],
                center: .center, startRadius: 0, endRadius: 150
            )
            .frame(width: 300, height: 300)
            .offset(y: -30)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                // Official app icon
                Image("AppIconImage")
                    .resizable()
                    .frame(width: 104, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color(hex: "1a64e8").opacity(0.52), radius: 32, y: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)

                // Wordmark
                Text("WaterLogger")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.white)
                    .kerning(-0.6)
                    .padding(.top, 24)
                    .opacity(nameOpacity)
                    .offset(y: nameOffset)

                Text("Stay hydrated")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.36))
                    .kerning(0.4)
                    .padding(.top, 8)
                    .opacity(nameOpacity)
                    .offset(y: nameOffset)

                Spacer()
            }
        }
        .scaleEffect(exitScale)
        .opacity(exitOpacity)
        .onAppear { animate() }
    }

    private func animate() {
        // Icon springs in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.08)) {
            iconScale = 1.0
            iconOpacity = 1
        }
        // Wordmark slides up
        withAnimation(.easeOut(duration: 0.4).delay(0.28)) {
            nameOpacity = 1
            nameOffset = 0
        }

        // After 1.9 s: scale up + fade out (matches HTML: scale 1.05, opacity 0, 0.6 s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation(.easeIn(duration: 0.6)) {
                exitScale = 1.05
                exitOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                onFinished()
            }
        }
    }
}


#Preview {
    SplashView(onFinished: {})
}
