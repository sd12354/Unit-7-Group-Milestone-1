import SwiftUI

/// Create session form (Milestone 2 — Issue 6).
struct CreateView: View {

    @State private var title = ""
    @State private var subjectTag = ""
    @State private var dateTime = Date().addingTimeInterval(3600)
    @State private var location = ""
    @State private var maxAttendeesText = ""
    @State private var description = ""

    @State private var navigationPath = NavigationPath()
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Form {
                Section("Session") {
                    TextField("Title", text: $title)
                    TextField("Subject / tag (e.g. CS 101)", text: $subjectTag)
                    DatePicker("Date & time", selection: $dateTime)
                    TextField("Location", text: $location, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Capacity") {
                    TextField("Max attendees (optional)", text: $maxAttendeesText)
                        .keyboardType(.numberPad)
                    Text("Leave blank for unlimited.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Details") {
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    Button(action: { Task { await saveSession() } }) {
                        if isSaving {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Create session")
                        }
                    }
                    .disabled(isSaving || !isFormValid)
                }
            }
            .navigationTitle("New Session")
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
        }
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !subjectTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var parsedCapacity: Int? {
        let t = maxAttendeesText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        guard let n = Int(t), n > 0 else { return nil }
        return n
    }

    @MainActor
    private func saveSession() async {
        guard isFormValid else { return }
        isSaving = true
        defer { isSaving = false }

        let cap = parsedCapacity
        if !maxAttendeesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, cap == nil {
            saveError = "Max attendees must be a positive number, or leave the field empty."
            return
        }

        do {
            let id = try await SessionRepository.createSession(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                subjectTag: subjectTag.trimmingCharacters(in: .whitespacesAndNewlines),
                dateTime: dateTime,
                location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                capacity: cap,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            navigationPath.append(id)
            clearFormAfterSuccess()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func clearFormAfterSuccess() {
        title = ""
        subjectTag = ""
        dateTime = Date().addingTimeInterval(3600)
        location = ""
        maxAttendeesText = ""
        description = ""
    }
}

#Preview {
    CreateView()
}
