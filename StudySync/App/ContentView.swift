import SwiftUI

// MARK: - Tab shell

private enum AppTab: Int, CaseIterable, Hashable {
    case home = 0
    case create
    case sessions
    case profile

    var title: String {
        switch self {
        case .home: return "Home"
        case .create: return "Create"
        case .sessions: return "My Sessions"
        case .profile: return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .create: return "plus.circle.fill"
        case .sessions: return "calendar"
        case .profile: return "person.fill"
        }
    }
}

/// Root view — hosts the 4-tab bottom navigation bar.
/// Each tab is a stub that will be filled in by its respective issue.
struct ContentView: View {

    @State private var selectedTab: AppTab = .home

    var body: some View {
        ZStack {
            HomeView()
                .opacity(selectedTab == .home ? 1 : 0)
                .allowsHitTesting(selectedTab == .home)
                .accessibilityHidden(selectedTab != .home)

            CreateView()
                .opacity(selectedTab == .create ? 1 : 0)
                .allowsHitTesting(selectedTab == .create)
                .accessibilityHidden(selectedTab != .create)

            MySessionsView()
                .opacity(selectedTab == .sessions ? 1 : 0)
                .allowsHitTesting(selectedTab == .sessions)
                .accessibilityHidden(selectedTab != .sessions)

            ProfileView()
                .opacity(selectedTab == .profile ? 1 : 0)
                .allowsHitTesting(selectedTab == .profile)
                .accessibilityHidden(selectedTab != .profile)
        }
        .tint(AppTheme.primary)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selection: $selectedTab)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
        }
        .appBackground()
    }
}

// MARK: - Custom tab bar (tight selection highlight; height-bounded so it cannot fill the screen)

private struct FloatingTabBar: View {
    @Binding var selection: AppTab

    private let rowHeight: CGFloat = 52

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = selection == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                            .symbolRenderingMode(.hierarchical)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(AppTheme.primary.opacity(0.22))
                                .padding(.horizontal, 2)
                                .padding(.vertical, 1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelected ? AppTheme.primary : AppTheme.textSecondary)
            }
        }
        .frame(height: rowHeight)
        .padding(5)
        .background(AppTheme.surface.opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 3)
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 0)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
