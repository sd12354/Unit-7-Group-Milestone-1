import SwiftUI
import MapKit
import Combine

/// Create session form (Milestone 2 — Issue 6).
struct CreateView: View {

    @State private var title = ""
    @State private var subjectTag = ""
    @State private var customSubject = ""
    @State private var useCustomSubject = false
    @State private var dateTime = Date().addingTimeInterval(3600)
    @State private var location = ""
    @State private var maxAttendees: Int?
    @State private var description = ""

    @StateObject private var locationSearch = LocationAutocomplete()
    @State private var navigationPath = NavigationPath()
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var scrollResetToken = UUID()
    @FocusState private var focusedField: Field?
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    private let fieldTitleFont: Font = .system(size: 14, weight: .medium)
    private let editingSessionId: String?

    private enum Field: Hashable {
        case title
        case location
        case description
        case customSubject
    }

    init(editingSession: StudySession? = nil) {
        _title = State(initialValue: editingSession?.title ?? "")
        _subjectTag = State(initialValue: editingSession?.subjectTag ?? "")
        _customSubject = State(initialValue: "")
        _useCustomSubject = State(initialValue: editingSession.map { !SubjectOption.defaults.contains($0.subjectTag) } ?? false)
        _dateTime = State(initialValue: editingSession?.startTime ?? Date().addingTimeInterval(3600))
        _location = State(initialValue: editingSession?.locationText ?? "")
        _maxAttendees = State(initialValue: editingSession?.maxAttendees)
        _description = State(initialValue: editingSession?.description ?? "")
        _locationSearch = StateObject(wrappedValue: LocationAutocomplete())
        editingSessionId = editingSession?.id

        if let editingSession, !SubjectOption.defaults.contains(editingSession.subjectTag) {
            _subjectTag = State(initialValue: SubjectOption.customTag)
            _customSubject = State(initialValue: editingSession.subjectTag)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Image("AppGradientBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                    labeled("Session Title", systemImage: "textformat") {
                        TextField(
                            "",
                            text: $title,
                            prompt: Text("e.g., Calculus Study Group")
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.82))
                        )
                            .focused($focusedField, equals: .title)
                            .foregroundStyle(AppTheme.primary)
                            .tint(AppTheme.primary)
                            .padding(12)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(focusedField == .title ? AppTheme.accent : AppTheme.primary.opacity(0.5), lineWidth: focusedField == .title ? 2.5 : 1.5)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    }

                    labeled("Subject / Tag", systemImage: "tag.fill") {
                        subjectPicker
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.primary.opacity(0.35), lineWidth: 1))
                            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        labeled("Date", systemImage: "calendar") {
                            DatePicker("", selection: $dateTime, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(AppTheme.primary)
                                .foregroundStyle(AppTheme.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(AppTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.primary.opacity(0.35), lineWidth: 1))
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        labeled("Time", systemImage: "clock.fill") {
                            DatePicker("", selection: $dateTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(AppTheme.primary)
                                .foregroundStyle(AppTheme.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(AppTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.primary.opacity(0.35), lineWidth: 1))
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    labeled("Location", systemImage: "mappin.and.ellipse") {
                        TextField(
                            "",
                            text: $location,
                            prompt: Text("Building, room, or address")
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.82)),
                            axis: .vertical
                        )
                            .lineLimit(1...3)
                            .focused($focusedField, equals: .location)
                            .foregroundStyle(AppTheme.primary)
                            .tint(AppTheme.primary)
                            .padding(12)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(focusedField == .location ? AppTheme.accent : AppTheme.primary.opacity(0.5), lineWidth: focusedField == .location ? 2.5 : 1.5)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                            .onChange(of: location) { _, newValue in
                                locationSearch.update(query: newValue)
                            }
                    }
                    if focusedField == .location && !locationSearch.suggestions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(locationSearch.suggestions, id: \.self) { suggestion in
                                Button {
                                    location = suggestion
                                    locationSearch.clear()
                                    focusedField = nil
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "mappin.and.ellipse")
                                        Text(suggestion)
                                            .lineLimit(2)
                                        Spacer()
                                    }
                                    .padding(12)
                                    .foregroundStyle(AppTheme.textPrimary)
                                }
                                .buttonStyle(.plain)
                                Divider()
                            }
                        }
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.primary.opacity(0.35), lineWidth: 1))
                    }

                    labeled("Max Attendees", systemImage: "person.3.fill") {
                        HStack {
                            Button { decrementCapacity() } label: {
                                Image(systemName: "minus")
                                    .foregroundStyle(maxAttendees == nil ? Color(hex: "94A3B8") : AppTheme.primary)
                                    .frame(width: 40, height: 40)
                                    .background(maxAttendees == nil ? Color(hex: "EEF2F7") : AppTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(maxAttendees == nil ? Color(hex: "CBD5E1") : AppTheme.primary.opacity(0.45), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(maxAttendees == nil)
                            Spacer()
                            Text(maxAttendees.map(String.init) ?? "Unlimited")
                                .font(AppTheme.smallFont.weight(.semibold))
                                .foregroundStyle(maxAttendees == nil ? Color(hex: "2D3A65") : .white)
                                .padding(.horizontal, 12)
                                .frame(height: 40)
                                .background(maxAttendees == nil ? .white : AppTheme.primary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(AppTheme.primary.opacity(0.4), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                            Spacer()
                            Button { incrementCapacity() } label: {
                                Image(systemName: "plus")
                                    .frame(width: 40, height: 40)
                                    .background(AppTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.primary.opacity(0.45), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    labeled("Description", systemImage: "text.alignleft") {
                        TextField(
                            "",
                            text: $description,
                            prompt: Text("What will you cover in this session?")
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.82)),
                            axis: .vertical
                        )
                            .lineLimit(2...5)
                            .focused($focusedField, equals: .description)
                            .foregroundStyle(AppTheme.primary)
                            .tint(AppTheme.primary)
                            .padding(12)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(focusedField == .description ? AppTheme.accent : AppTheme.primary.opacity(0.5), lineWidth: focusedField == .description ? 2.5 : 1.5)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    }

                    Button(action: { Task { await saveSession() } }) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                if editingSessionId == nil {
                                    Text("Save")
                                        .font(.headline)
                                } else {
                                    Label("Save Changes", systemImage: "square.and.pencil")
                                        .font(.headline)
                                }
                            }
                            Spacer()
                        }
                        .frame(height: 54)
                        .background(isFormValid && !isSaving ? AppTheme.primary : Color(hex: "A8AFBF"))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .appPressEffect()
                    .disabled(isSaving || !isFormValid)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 92)
                    .padding(.bottom, 120)
                }
            }
            .id(scrollResetToken)
            .safeAreaPadding(.top, 28)
            .safeAreaPadding(.bottom, 48)
            .scrollContentBackground(.hidden)
            .foregroundStyle(AppTheme.textPrimary)
            .navigationTitle(editingSessionId == nil ? "New Session" : "Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTransparentKeepsLayout()
            .animation(.easeInOut(duration: 0.2), value: locationSearch.suggestions)
            .navigationDestination(for: String.self) { sessionId in
                SessionDetailView(sessionId: sessionId)
            }
            .alert("Could not create session", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
            .onAppear {
                scrollResetToken = UUID()
            }
        }
    }

    private func labeled<Content: View>(_ text: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldTitleRow(text, systemImage: systemImage)
            content()
        }
    }

    private func fieldTitleRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "9ED7FF"))
            Text(title)
                .font(fieldTitleFont)
                .foregroundStyle(Color.white.opacity(0.96))
        }
    }

    @ViewBuilder
    private var subjectPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                ForEach(SubjectOption.defaults, id: \.self) { option in
                    Button(option) {
                        subjectTag = option
                        useCustomSubject = false
                    }
                }
                Button("Custom…") {
                    subjectTag = SubjectOption.customTag
                    useCustomSubject = true
                }
            } label: {
                HStack {
                    Text(subjectPlaceholderText)
                        .foregroundStyle(subjectSelectionEmpty ? AppTheme.textSecondary.opacity(0.82) : AppTheme.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.primary.opacity(0.8))
                }
                .font(.system(size: 16, weight: .medium))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !subjectSelectionEmpty {
                Text(resolvedSubject.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(subjectColor.opacity(0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(subjectColor.opacity(0.16))
                    .clipShape(Capsule())
            }

            if useCustomSubject {
                TextField(
                    "",
                    text: $customSubject,
                    prompt: Text("Custom subject (e.g. CS 101)")
                        .foregroundStyle(AppTheme.textSecondary.opacity(0.82))
                )
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .customSubject)
                    .foregroundStyle(AppTheme.primary)
                    .tint(AppTheme.primary)
            }
        }
    }

    private var subjectSelectionEmpty: Bool {
        resolvedSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var subjectPlaceholderText: String {
        subjectSelectionEmpty ? "Select a subject" : "Selected subject"
    }

    private var subjectColor: Color {
        switch resolvedSubject.lowercased() {
        case let value where value.contains("math"):
            return Color(hex: "3B82F6")
        case let value where value.contains("biology"):
            return Color(hex: "10B981")
        case let value where value.contains("chemistry"):
            return Color(hex: "06B6D4")
        case let value where value.contains("physics"):
            return Color(hex: "6366F1")
        case let value where value.contains("computer science"), let value where value.contains("data"):
            return Color(hex: "4F46E5")
        default:
            return Color(hex: "64748B")
        }
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !resolvedSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var resolvedSubject: String {
        useCustomSubject ? customSubject : subjectTag
    }

    private func incrementCapacity() {
        if let cap = maxAttendees {
            maxAttendees = min(cap + 1, 50)
        } else {
            maxAttendees = 1
        }
    }

    private func decrementCapacity() {
        guard let cap = maxAttendees else { return }
        let updated = cap - 1
        maxAttendees = updated <= 0 ? nil : updated
    }

    @MainActor
    private func saveSession() async {
        guard isFormValid else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            if let editingSessionId {
                try await SessionRepository.updateSession(
                    sessionId: editingSessionId,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    subjectTag: resolvedSubject.trimmingCharacters(in: .whitespacesAndNewlines),
                    dateTime: dateTime,
                    location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                    capacity: maxAttendees,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                dismiss()
            } else {
                let id = try await SessionRepository.createSession(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    subjectTag: resolvedSubject.trimmingCharacters(in: .whitespacesAndNewlines),
                    dateTime: dateTime,
                    location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                    capacity: maxAttendees,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                navigationPath.append(id)
                clearFormAfterSuccess()
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func clearFormAfterSuccess() {
        title = ""
        subjectTag = ""
        customSubject = ""
        useCustomSubject = false
        dateTime = Date().addingTimeInterval(3600)
        location = ""
        maxAttendees = nil
        description = ""
        locationSearch.clear()
    }
}

private enum SubjectOption {
    static let customTag = "__custom__"
    static let defaults: [String] = [
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
}

private final class LocationAutocomplete: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [String] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            return
        }
        completer.queryFragment = trimmed
    }

    func clear() {
        suggestions = []
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results.map { result in
            let subtitle = result.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            return subtitle.isEmpty ? result.title : "\(result.title), \(subtitle)"
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}

#Preview {
    CreateView()
}
