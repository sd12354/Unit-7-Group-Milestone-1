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
        case .sessions: return "calendar.circle.fill"
        case .profile: return "person.fill"
        }
    }

    var inactiveSystemImage: String {
        switch self {
        case .home: return "house"
        case .create: return "plus.circle"
        case .sessions: return "calendar.circle"
        case .profile: return "person"
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
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .appBackground()
    }
}

// MARK: - Custom tab bar (tight selection highlight; height-bounded so it cannot fill the screen)

private struct FloatingTabBar: View {
    @Binding var selection: AppTab

    private let rowHeight: CGFloat = 54
    private let inactiveTint = Color(hex: "8C95A8")

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isSelected = selection == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(AppTheme.primary)
                                    .frame(width: 30, height: 30)
                            }
                            Image(systemName: isSelected ? tab.systemImage : tab.inactiveSystemImage)
                                .font(.system(size: 19, weight: isSelected ? .semibold : .regular))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(isSelected ? AppTheme.surface : inactiveTint)
                        }
                        .frame(height: 30)
                        Text(tab.title)
                            .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.86)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(isSelected ? AppTheme.primary : inactiveTint)
                    }
                    .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: rowHeight)
        .padding(.horizontal, 5)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(AppTheme.surface)
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(hex: "DDE3EE"))
                .frame(height: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: -2)
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 0)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
