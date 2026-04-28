import SwiftUI

/// Startup loading screen with animated transparent logo over app gradient.
struct AppLoadingView: View {
    @State private var animatePulse = false
    @State private var animateFloat = false

    var body: some View {
        ZStack {
            Image("AppGradientBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image("StudySyncLogoTransparent")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 124, height: 124)
                    .scaleEffect(animatePulse ? 1.06 : 0.94)
                    .offset(y: animateFloat ? -5 : 5)
                    .shadow(color: Color.white.opacity(0.35), radius: 10, y: 4)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animatePulse)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: animateFloat)

                Text("StudySync")
                    .font(AppTheme.sectionTitleFont)
                    .foregroundStyle(.white.opacity(0.95))
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            animatePulse = true
            animateFloat = true
        }
    }
}

#Preview {
    AppLoadingView()
}
