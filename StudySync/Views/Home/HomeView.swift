import SwiftUI
import FirebaseAuth

/// Home — upcoming session feed (Milestone 2 — Issue 7).
struct HomeView: View {

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var sessions: [StudySession] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var selectedFilter = "All"
    @State private var showCreateSheet = false
    @State private var editingSession: StudySession?
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var navigationPath = NavigationPath()

    private let filters = [
        "All",
        "Today",
        "This Week",
        "Math",
        "Computer Science",
        "Biology",
        "Chemistry",
        "Physics",
        "Statistics",
        "Data Science",
        "Engineering",
        "Psychology",
        "Sociology",
        "Political Science",
        "Philosophy",
        "Art",
        "Music",
        "Business",
        "Accounting",
        "Finance",
        "Marketing",
        "Nursing",
        "Pre-Med",
        "History",
        "English",
        "Economics"
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Image("AppGradientBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    VStack(spacing: 10) {
                        Label {
                            Text("\(greetingText), \(homeDisplayName)")
                        } icon: {
                            Image(systemName: greetingIconName)
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 14)
                        .padding(.top, 152)

                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(AppTheme.primary.opacity(0.85))
                            TextField("Search sessions", text: $searchText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(AppTheme.primary)
                                .focused($isSearchFocused)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSearchFocused ? AppTheme.accent : AppTheme.primary.opacity(0.55), lineWidth: isSearchFocused ? 2.5 : 1.5)
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                        ZStack(alignment: .trailing) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(filters, id: \.self) { filter in
                                        Button {
                                            selectedFilter = filter
                                        } label: {
                                            Text(filter)
                                                .font(AppTheme.smallFont)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 9)
                                                .background(selectedFilter == filter ? AppTheme.primary : AppTheme.surface)
                                                .foregroundStyle(selectedFilter == filter ? AppTheme.surface : AppTheme.textPrimary)
                                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .stroke(AppTheme.primary.opacity(0.45), lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .padding(.trailing, 24)
                            }
                            .frame(height: 56)

                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Circle().stroke(Color.white.opacity(0.55), lineWidth: 1)
                                    )
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(AppTheme.primary)
                            }
                            .padding(.trailing, 10)
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 12)

                        if isLoading && sessions.isEmpty {
                            List(0..<4, id: \.self) { _ in
                                LoadingSkeletonRow()
                                    .listRowBackground(Color.clear)
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        } else if let loadError {
                            ContentUnavailableView("Could not refresh", systemImage: "wifi.exclamationmark", description: Text(loadError))
                                .foregroundStyle(.white)
                        } else if filteredSessions.isEmpty {
                            ContentUnavailableView("No sessions", systemImage: "calendar.badge.clock", description: Text("Try another filter or create a new session."))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .offset(y: -46)
                        } else {
                            List(filteredSessions) { session in
                                if let id = session.id {
                                    Button {
                                        if session.hostId == authViewModel.currentUser?.uid {
                                            editingSession = session
                                        } else {
                                            navigationPath.append(id)
                                        }
                                    } label: {
                                        SessionRowView(session: session)
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .listSectionSeparator(.hidden)
                        }
                    }
                }
                .overlay(alignment: .top) {
                    HStack(alignment: .bottom, spacing: 0) {
                        Image("StudySyncLogoTransparent")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(.trailing, -10)
                        Text("tudySync")
                            .font(AppTheme.titleFont)
                            .foregroundStyle(.white)
                            .padding(.bottom, -8)
                    }
                    .padding(.top, 78)
                }
            }
            .refreshable { await loadSessions() }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Circle()
                        .fill(AppTheme.primary)
                        .frame(width: 56, height: 56)
                        .overlay(Image(systemName: "plus").font(.title2.bold()).foregroundStyle(AppTheme.surface))
                        .shadow(color: AppTheme.primary.opacity(0.35), radius: 10, y: 6)
                }
                .buttonStyle(.plain)
                .appPressEffect()
                .padding(.trailing, 18)
                // Keep FAB above the custom tab bar capsule.
                .padding(.bottom, 146)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(AppTheme.textPrimary)
            .navigationDestination(for: String.self) { sessionId in
                SessionDetailView(sessionId: sessionId)
            }
        }
        .task { await loadSessions() }
        .sheet(isPresented: $showCreateSheet) {
            CreateView()
                .environmentObject(authViewModel)
        }
        .sheet(item: $editingSession) { session in
            CreateView(editingSession: session)
                .environmentObject(authViewModel)
        }
    }

    private var filteredSessions: [StudySession] {
        let base: [StudySession]
        switch selectedFilter {
        case "All":
            base = sessions
        case "Today":
            base = sessions.filter { Calendar.current.isDateInToday($0.startTime) }
        case "This Week":
            let calendar = Calendar.current
            guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return sessions }
            base = sessions.filter { week.contains($0.startTime) }
        default:
            base = sessions.filter { $0.subjectTag.localizedCaseInsensitiveContains(selectedFilter) }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let active = base.filter { !$0.isCancelled }
        guard !query.isEmpty else { return active }
        return active.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subjectTag.localizedCaseInsensitiveContains(query) ||
            $0.locationText.localizedCaseInsensitiveContains(query)
        }
    }

    @MainActor
    private func loadSessions() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        do {
            sessions = try await SessionRepository.getSessions()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private var homeDisplayName: String {
        if let name = authViewModel.currentUser?.displayName, !name.isEmpty { return name }
        if let email = authViewModel.currentUser?.email, !email.isEmpty {
            return email.components(separatedBy: "@").first?.capitalized ?? "Friend"
        }
        return "Friend"
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good night"
        }
    }

    private var greetingIconName: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "sunrise.fill"
        case 12..<17:
            return "sun.max.fill"
        default:
            return "moon.stars.fill"
        }
    }
}

private struct SessionRowView: View {
    let session: StudySession

    private static let rowDate: Date.FormatStyle =
        .dateTime
        .month(.abbreviated)
        .day()
        .hour()
        .minute()

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(session.title)
                        .font(AppTheme.labelFont)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(session.subjectTag)
                        .font(AppTheme.smallFont)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.tertiaryAccent.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .foregroundStyle(AppTheme.textPrimary)

                Label(session.startTime.formatted(Self.rowDate), systemImage: "calendar")
                    .font(AppTheme.bodyFont)
                Label(session.locationText, systemImage: "mappin.and.ellipse")
                    .font(AppTheme.bodyFont)
                    .lineLimit(2)

                HStack {
                    Circle().fill(Color.black.opacity(0.14)).frame(width: 20, height: 20)
                    Text("Host")
                    Spacer()
                    Text(spotsText)
                        .font(AppTheme.smallFont)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.secondaryAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .foregroundStyle(AppTheme.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.55))
                .accessibilityHidden(true)
        }
        .padding(16)
        .foregroundStyle(AppTheme.textPrimary)
        .appCardSurface()
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
    }

    private var spotsText: String {
        if let spots = session.spotsRemaining {
            return spots <= 0 ? "Full" : "\(spots) spots left"
        }
        return "Open"
    }
}

#Preview {
    HomeView()
}
