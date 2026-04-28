import SwiftUI

enum AppTheme {
    static let background = Color(hex: "D6E9F8")
    /// Screen corners: light cyan — dark navy — dark navy — light cyan (matches app gradient art).
    static let gradientLight = Color(hex: "98DDFE")
    static let gradientDark = Color(hex: "283655")
    /// Bottom shelf: leading navy → trailing sky (horizontal strip behind custom tab bar).
    static let tabShelfGradient = LinearGradient(
        colors: [gradientDark, gradientLight],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let surface = Color(hex: "FFFFFF")
    static let card = surface
    static let primary = Color(hex: "2D3A65")
    static let accent = Color(hex: "84ADD0")
    static let secondaryAccent = Color(hex: "B8DFFF")
    static let tertiaryAccent = Color(hex: "D3EBFF")
    static let error = Color(hex: "EF4444")
    static let textPrimary = Color(hex: "1E2A44")
    static let textSecondary = Color(hex: "4F6780")

    static let titleFont: Font = .system(size: 40, weight: .bold)
    static let sectionTitleFont: Font = .system(size: 30, weight: .bold)
    static let bodyFont: Font = .system(size: 18, weight: .regular)
    static let labelFont: Font = .system(size: 20, weight: .semibold)
    static let smallFont: Font = .system(size: 15, weight: .medium)
}

struct AppBackgroundView: View {
    var body: some View {
        Image("AppGradientBackground")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)
        let r, g, b: UInt64
        switch sanitized.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (248, 250, 252)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

struct PressEffectModifier: ViewModifier {
    @GestureState private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
            )
    }
}

struct CardLiftModifier: ViewModifier {
    @GestureState private var isPressed = false

    func body(content: Content) -> some View {
        content
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.primary.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: AppTheme.primary.opacity(0.14), radius: 8, y: 4)
            .offset(y: isPressed ? -1 : 0)
            .animation(.easeOut(duration: 0.2), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, state, _ in
                        state = true
                    }
            )
    }
}

extension View {
    /// Use with gradient screens: `toolbarBackground(.hidden)` lets `ScrollView` / `List` slide under the status bar.
    /// A **visible** bar with a **clear** background keeps the layout slot for the nav + safe area while staying visually transparent.
    func navigationBarTransparentKeepsLayout() -> some View {
        toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.clear, for: .navigationBar)
    }

    func appPressEffect() -> some View {
        modifier(PressEffectModifier())
    }

    func appCardLift() -> some View {
        modifier(CardLiftModifier())
    }

    /// Same card border/fill as `appCardLift()` without shadow (e.g. list rows where shadow reads as a line under the cell).
    func appCardSurface() -> some View {
        background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.primary.opacity(0.35), lineWidth: 1)
            )
    }

    func appBackground() -> some View {
        background(AppBackgroundView())
    }
}

struct LoadingSkeletonRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 5)
                .fill(AppTheme.textSecondary.opacity(0.18))
                .frame(height: 16)
            RoundedRectangle(cornerRadius: 5)
                .fill(AppTheme.textSecondary.opacity(0.14))
                .frame(height: 14)
                .frame(maxWidth: 180)
            RoundedRectangle(cornerRadius: 5)
                .fill(AppTheme.textSecondary.opacity(0.1))
                .frame(height: 12)
                .frame(maxWidth: 240)
        }
        .padding(.vertical, 8)
        .redacted(reason: .placeholder)
    }
}
