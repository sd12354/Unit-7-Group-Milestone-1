# Firebase Setup (Auth + Firestore)

This project is currently an iOS SwiftUI app. Firebase Auth and Firestore dependencies are already linked in `StudySync.xcodeproj`, and Firebase is initialized in `StudySync/App/StudySyncApp.swift`.

## Current status

- Firebase core is configured at app startup using `FirebaseApp.configure()`.
- FirebaseAuth and FirebaseFirestore packages are linked in Xcode project settings.
- Firestore models are defined:
  - `StudySync/Models/UserProfile.swift` -> `users/{uid}`
  - `StudySync/Models/StudySession.swift` -> `sessions/{sessionId}`
- Local iOS config file added: `GoogleService-Info.plist` (gitignored).

## Sign-in providers (Google, Phone, email) — iOS checklist

These must be enabled in **Firebase Console → Authentication → Sign-in method** for the corresponding provider. **Sign in with Apple is not implemented** in this app build.

### Google

1. Download **`GoogleService-Info.plist`** from Firebase (Project settings → Your apps → iOS). It must include **`CLIENT_ID`** and **`REVERSED_CLIENT_ID`**. A plist that only has `API_KEY` / `GOOGLE_APP_ID` is not enough for Google Sign-In.
2. Add that file to the **`StudySync`** app target (same folder as the rest of the app sources is fine).
3. **URL scheme for OAuth return:** The root **`URLTypes-Info.plist`** must list your **`REVERSED_CLIENT_ID`** under `CFBundleURLSchemes` (same string as in `GoogleService-Info.plist`). If you rotate Firebase iOS apps, update that plist entry and the **`GOOGLE_REVERSED_CLIENT_ID`** build setting on the **StudySync** target so they stay in sync.
4. **Bundle ID must match Firebase:** The `BUNDLE_ID` inside `GoogleService-Info.plist` must match Xcode’s **Product Bundle Identifier** (e.g. if the plist says `studysync` but Xcode uses `studysync-studysync`, add a Firebase iOS app for the Xcode bundle ID and use its plist—or change Xcode to match the plist). Mismatches often break Google Sign-In after the browser step.
5. The **GoogleSignIn** Swift package is linked in the Xcode project; resolve packages after pulling.

### Phone

1. Enable **Phone** in Firebase Authentication.
2. On a **real device**, silent verification works best when push / APNs is configured per [Firebase phone auth docs](https://firebase.google.com/docs/auth/ios/phone-auth). On **Simulator**, Firebase falls back to **reCAPTCHA**; the app passes an **`AuthUIDelegate`** so the browser sheet can be presented.
3. Enter numbers in **E.164** form (e.g. `+15555550100`). The app normalizes common US 10-digit input to `+1…`.

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

## Troubleshooting: Firestore / `FIRVectorValue.h` “Foundation module is needed…”

**Xcode 26** turns on **Swift explicit modules** for all targets, including Swift packages. That can break Firebase Firestore’s precompiled bridge when generating PCMs (`SwiftExplicitDependencyGeneratePcm` / `FirebaseFirestoreInternalWrapper`).

This repo sets **`SWIFT_ENABLE_EXPLICIT_MODULES = NO`** on the **project** Debug/Release configurations (not only the app target) so Firebase SPM targets build reliably. If you still see the error after pulling, do **Product → Clean Build Folder**, then build again.

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
