# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This App Does

A real-time WhatsApp group monitoring platform. A WhatsApp bot pushes messages and media into Firebase (Firestore + Storage), and this Flutter app surfaces them in a structured viewer with role-based access control. Admins manage users and restrict which groups each user can see.

---

## Commands

```bash
# Install dependencies
flutter pub get

# Run app
flutter run

# Regenerate Freezed/build_runner code (after editing any @freezed or @riverpod annotated files)
flutter pub run build_runner build --delete-conflicting-outputs

# Lint
flutter analyze

# Tests
flutter test

# Run a single test file
flutter test test/unit/shifts_test.dart
```

**Firebase Functions (from `functions/` directory):**
```bash
npm run serve    # local emulator
npm run deploy   # deploy to Firebase
npm run logs     # tail logs
```

---

## Architecture

Clean architecture with strict feature separation. Each feature under `lib/features/<name>/` has three layers:

```
presentation/   → Pages, Widgets, Riverpod Providers, Controllers (AsyncNotifier/Notifier)
domain/         → Entities (Freezed), Repository interfaces, Helper functions
data/           → Repository implementations, DataSources (Firestore), Models
```

App-level wiring lives in `lib/app/`:
- `router.dart` — GoRouter with auth guards (redirects to login if unauthenticated, to `/chats` if admin tries unauthorized route)
- `providers.dart` — Riverpod providers that inject `FirebaseAuth` and `FirebaseFirestore`
- `app.dart` — `MaterialApp.router`, locale hardcoded to Spanish (`es`)

**Dependency flow:** `providers.dart` → datasources → repository impls → domain repositories → notifiers → UI.

---

## Features

| Feature | Purpose |
|---|---|
| `auth` | Email/password login, Firebase custom claims (admin, superAdmin) |
| `chats` | Real-time group list with search; backed by `group_stats` Firestore collection |
| `messages` | Paginated message list (50/page), image viewer with pinch-to-zoom, day separators, shift labels |
| `admin` | SuperAdmin/Admin panel: create/delete users, assign groups, toggle roles |
| `home` | Responsive layout shell (split-view desktop, animated drawer on mobile) |

---

## State Management

Riverpod throughout. Patterns used:
- `AsyncNotifierProvider` for async data with loading/error states (chats list, messages)
- `NotifierProvider` for sync UI state (login form, admin actions)
- `StreamProvider` for real-time Firestore listeners
- `listen` in `ConsumerWidget.build` for side-effect navigation (post-login redirect)

Errors are modeled as sealed Freezed unions in `lib/core/errors/failures.dart` — always return `Either<Failure, T>` from repository methods, never throw.

---

## Firebase

**Project ID:** `whatsapp-pro-3d483`

**Firestore Collections:**
- `group_stats` — Chat group metadata (`chatJid`, `groupName`, `lastMessageAt`, `totalImages`)
- `whatsapp_messages` — Messages (`chatJid`, `senderName`, `messageTimestamp`, `hasMedia`, `storagePath`, `isEdited`, `messageDate`)
- `users` — User documents (`uid`, `email`, `allowedGroups[]`, `isAdmin`, `isSuperAdmin`, `disabled`)
- `edit_attempts` — Audit trail for edited WhatsApp messages

**Cloud Functions** (`functions/index.js`) handle all privileged user-management operations: `createUser`, `setUserRole`, `updateUserPassword`, `deleteUser`, `listUsers`, `toggleUserStatus`, `updateUserGroups`, `listGroups`. All callable from Flutter via `FirebaseFunctions.instance.httpsCallable(name)`.

Role enforcement uses Firebase custom claims (`admin`, `superAdmin`) set server-side by Cloud Functions — never set client-side.

---

## Key Conventions

- **Freezed everywhere** — all domain entities and error types use `@freezed`. Run build_runner after changing them.
- **Spanish locale** — UI strings are in Spanish. Keep new UI text in Spanish.
- **Shifts** — `lib/core/time/shifts.dart` defines 6 work shifts per day used to classify messages. The `Shift` enum and its time-range logic are tested in `test/unit/shifts_test.dart`.
- **Image URLs** — constructed client-side from `storagePath` using Firebase Storage public URL pattern; images are not stored as full URLs in Firestore.
- **Responsive breakpoint** — 700px width separates mobile (drawer navigation) from desktop (side-by-side panel) layout.
- **Pagination** — messages load 50 at a time; scroll to top triggers `loadMore()` on the `MessagesNotifier`.
