# StudySync

## Table of Contents

1. [Overview](#Overview)
2. [Product Spec](#Product-Spec)
3. [Wireframes](#Wireframes)
4. [Schema](#Schema)

## Overview

### Description

**StudySync** helps students discover and organize in-person study sessions. Users can post a session with a subject, time, meeting place, and capacity; browse upcoming sessions; join or leave a session; and keep a simple profile so others know who they are studying with. The app reduces back-and-forth in group chats and makes it easier to find accountability partners and quiet study blocks on campus.

### App Evaluation

- **Category:** Education / Productivity / Social (light coordination)
- **Mobile:** Yes—core value is on the go: quick browse, one-tap join, push reminders before a session, and optional map links to the meeting spot. A web companion could exist later but is not required for the story.
- **Story:** “Find your study people and show up prepared.” The app tells a story of belonging and academic momentum—turning vague “we should study” messages into concrete plans.
- **Market:** College and high-school students, coding bootcamps, and anyone studying for certifications in cohorts. Early adopters might be friend groups or a single club before expanding campus-wide.
- **Habit:** Weekly or seasonally heavy (midterms/finals). Some power users may host recurring sessions; others dip in when they need a group. Push notifications support the habit without requiring daily opens.
- **Scope:** Medium for MVP (sessions + profiles + join/leave). Optional features (chat, recurring sessions, school verification) can be phased in without breaking the core loop.

## Product Spec

### 1. User Stories (Required and Optional)

**Required Must-have Stories**

* User can register an account and log in.
* User can create a study session with title, subject/tag, date/time, location (text), optional max attendees, and description.
* User can browse a list of upcoming study sessions (chronological or by date).
* User can open a session to see details and a list of attendees.
* User can join a session if capacity allows and leave a session they joined.
* User can view and edit their own profile (display name, short bio, optional photo).
* User sees their own sessions (hosted and joined) in one place.

**Optional Nice-to-have Stories**

* User receives a push notification before a session they joined (e.g., 1 hour before).
* User can filter sessions by subject or location keyword.
* User can mark a session as recurring (weekly).
* User can open the meeting location in Maps from a structured address or lat/long.
* User can report inappropriate sessions or block another user.
* Host can cancel a session and notify joined users.

### 2. Screen Archetypes

- [ ] **Login / Sign Up Screen**
  * Required: User can register and log in.

- [ ] **Home — Session Feed**
  * Required: User can browse upcoming sessions and pull to refresh.

- [ ] **Session Detail Screen**
  * Required: User can view full session info, attendee list, join or leave.

- [ ] **Create / Edit Session Screen**
  * Required: User can create a new session (host); optional: edit/cancel if host.

- [ ] **Profile Screen**
  * Required: User can view and edit display name, bio, optional photo.

- [ ] **My Sessions Screen (or tab)**
  * Required: User can see sessions they host and sessions they joined.

### 3. Navigation

**Tab Navigation** (Tab to Screen)

- [ ] **Home** — Session feed (upcoming sessions).
- [ ] **Create** — New session form (could be a tab or a modal from Home; tab keeps flow obvious for milestone planning).
- [ ] **My Sessions** — Hosted and joined sessions.
- [ ] **Profile** — Current user profile and settings / log out.

**Flow Navigation** (Screen to Screen)

- [ ] **Session Feed**
  * Leads to **Session Detail** (tap row).
- [ ] **Session Detail**
  * Leads to **Profile** (tap attendee) — optional MVP; can be stubbed.
  * Leads back to **Feed** or **My Sessions** after join/leave.
- [ ] **Create Session**
  * On success, leads to **Session Detail** or **My Sessions**.

## Wireframes
<img width="589" height="799" alt="Screenshot 2026-03-30 at 6 55 05 PM" src="https://github.com/user-attachments/assets/a7f0b5fb-9013-43b9-b91a-a18d52d3fdb5" />

Suggested sketches (one flow per sheet helps):

1. Tab bar: Home | Create | My Sessions | Profile.
2. Home: list cells (title, time, location line, spots left).
3. Detail: title, metadata, description, join button, attendee avatars/names.
4. Create: form fields + save.
5. Profile: avatar, name, bio, edit affordance.

Example Markdown image (replace with your committed image path or URL after you add files):

```markdown
![](wireframes/home-feed-sketch.jpg)
```

### [BONUS] Digital Wireframes & Mockups

Figma Mockups

<img width="276" height="585" alt="Screenshot 2026-03-30 at 6 41 24 PM" src="https://github.com/user-attachments/assets/0157554a-aef4-4f73-ba3b-7b32316ab27c" />

<img width="278" height="587" alt="Screenshot 2026-03-30 at 6 41 37 PM" src="https://github.com/user-attachments/assets/fd35c0d3-cac0-4675-9da4-1938e4b7f556" />

<img width="274" height="584" alt="Screenshot 2026-03-30 at 6 42 11 PM" src="https://github.com/user-attachments/assets/35c2bb51-26ed-4b8b-9aa8-322263db42df" />

<img width="276" height="582" alt="Screenshot 2026-03-30 at 6 42 28 PM" src="https://github.com/user-attachments/assets/979e5a03-5034-4eb7-8611-7d65eab9b7bc" />

<img width="278" height="583" alt="Screenshot 2026-03-30 at 6 42 42 PM" src="https://github.com/user-attachments/assets/8e41d982-7a44-4c35-b422-274f1e416856" />

<img width="274" height="577" alt="Screenshot 2026-03-30 at 6 45 47 PM" src="https://github.com/user-attachments/assets/d2d28006-0fd7-4022-bae7-c3673eea1a74" />







### [BONUS] Interactive Prototype

_Add link or embed GIF/video of tap-through prototype._

## Schema

### Models

**User**

| Property   | Type    | Description                                      |
|------------|---------|--------------------------------------------------|
| objectId   | String  | Unique Parse/backend id                          |
| username   | String  | Login identifier                                 |
| email      | String  | Optional; for password reset if implemented      |
| displayName| String  | Shown on sessions and profile                    |
| bio        | String  | Short about text                                 |
| profileImage | File or URL | Optional avatar                            |
| createdAt  | Date    | Account creation                                 |

**StudySession**

| Property     | Type     | Description                                |
|--------------|----------|--------------------------------------------|
| objectId     | String   | Unique id                                  |
| title        | String   | Session title                              |
| subjectTag   | String   | e.g., “CS 101”, “Calculus”                 |
| startTime    | Date     | When the session starts                    |
| endTime      | Date     | Optional end time                          |
| locationText | String   | Human-readable place (“Library 3rd floor”) |
| locationGeo  | GeoPoint | Optional for map features                  |
| description  | String   | Longer notes                               |
| maxAttendees | Number   | Optional cap; null = unlimited             |
| host         | Pointer → User | Creator                              |
| attendeeIds  | Array    | Or relation to User for joined users       |
| createdAt    | Date     |                                            |
| updatedAt    | Date     |                                            |

### Networking

_Assume Parse or similar BaaS; adjust paths to your backend._

- **Login / Sign Up** — `POST` sign up, `POST` log in (Parse User).
- **Session Feed** — `[GET] /classes/StudySession` with query: `startTime >= now`, order by `startTime`, include `host`.
- **Session Detail** — `[GET] /classes/StudySession/:id` with `include=host` and attendees relation/array.
- **Create Session** — `[POST] /classes/StudySession` with fields above; set `host` to current user.
- **Join Session** — `[PUT] /classes/StudySession/:id` append current user to attendees, or `[POST]` to a Join table linking User + Session.
- **Leave Session** — Remove user from attendees relation/array.
- **Profile** — `[GET] /users/me`, `[PUT] /users/me` for displayName, bio, profileImage.
- **My Sessions** — Query sessions where `host = currentUser` OR current user in `attendees`, sorted by `startTime`.

Example Parse-style patterns (pseudo):

```swift
// Fetch upcoming sessions
let query = PFQuery(className: "StudySession")
query.whereKey("startTime", greaterThan: Date())
query.order(byAscending: "startTime")
query.includeKey("host")
```

```swift
// Create session
let session = PFObject(className: "StudySession")
session["title"] = title
session["startTime"] = start
session["host"] = PFUser.current()
try await session.save()
```

---

_Group members: add your names, course section, and GitHub org link in a short “Team” section at the top when your instructor asks for it._
