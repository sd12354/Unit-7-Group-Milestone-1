# Firebase Setup (Auth + Firestore)

This project is currently an iOS SwiftUI app. Firebase Auth and Firestore dependencies are already linked in `StudySync.xcodeproj`, and Firebase is initialized in `StudySync/App/StudySyncApp.swift`.

## Current status

- Firebase core is configured at app startup using `FirebaseApp.configure()`.
- FirebaseAuth and FirebaseFirestore packages are linked in Xcode project settings.
- Firestore models are defined:
  - `StudySync/Models/UserProfile.swift` -> `users/{uid}`
  - `StudySync/Models/StudySession.swift` -> `sessions/{sessionId}`
- Local iOS config file added: `GoogleService-Info.plist` (gitignored).

## Android initialization checklist

There is no Android project folder in this repository yet (no `android/`, `build.gradle`, or `settings.gradle`).  
To complete Android setup once that module exists:

1. Add Firebase Gradle plugins in project-level and app-level Gradle files.
2. Add dependencies:
   - `com.google.firebase:firebase-auth`
   - `com.google.firebase:firebase-firestore`
   - (optional BOM) `com.google.firebase:firebase-bom`
3. Place `google-services.json` in the Android app module root (typically `android/app/google-services.json`).
4. Sync Gradle and run the app build.

## Firestore schema (baseline)

### `users` collection

Document id: `uid` from Firebase Auth

Suggested fields:

- `displayName` (string, required)
- `bio` (string, optional, default `""`)
- `photoURL` (string, optional)
- `email` (string, optional)
- `createdAt` (timestamp, server timestamp)
- `updatedAt` (timestamp, server timestamp)

### `sessions` collection

Document id: auto-generated (`sessionId`)

Suggested fields:

- `title` (string, required)
- `subjectTag` (string, required)
- `startTime` (timestamp, required)
- `endTime` (timestamp, optional)
- `locationText` (string, required)
- `description` (string, required)
- `maxAttendees` (number, optional)
- `hostId` (string, required, references `users/{uid}`)
- `attendeeIds` (array<string>, required, default `[]`)
- `createdAt` (timestamp, server timestamp)
- `updatedAt` (timestamp, server timestamp)

## Recommended Firestore security rules (starter)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read: if request.auth != null;
      allow create, update: if request.auth != null && request.auth.uid == uid;
    }

    match /sessions/{sessionId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
                    && request.resource.data.hostId == request.auth.uid;
      allow update, delete: if request.auth != null
                            && resource.data.hostId == request.auth.uid;
    }
  }
}
```
