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

# Tests live in test/unit/ (shifts, format_day_label, map_failure_to_message, to_domain)
# and test/widget/ (message_bubble, message_list, custom_message_group, format_time)
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

Shared code lives in `lib/core/` (`errors/`, `responsive/`, `theme/`, `time/`, `loading/`, `shared/widget/`) and `lib/helpers/` (`format_time.dart`, `map_failure_to_message.dart`).

App-level wiring lives in `lib/app/`:
- `router.dart` — GoRouter routes; the redirect *decision* (auth/role guards) is not inline here, see `auth_redirect.dart`
- `auth_redirect.dart` — `computeAuthRedirect`: pure redirect logic (login/home/admin/matches/summary guards), called from `router.dart`'s `redirect:`; kept in its own file because `router.dart` itself can't be imported in a VM test (pulls in `HomePage` → `MessageList`/`MessageBubble` → `package:web`)
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
| `summary` | `/summary` (`SummaryPage`): entry point for the per-shift summary/reconciliation — reads REAL data (step 7, piece d): `summaryRepositoryProvider` returns `realSummaryRepositoryProvider` (`FirestoreSummaryRepository` + three datasources: `image_reviews` records, `shift_image_counts` counters, `group_stats` names), not run against Firestore yet; `MockSummaryRepository` stays unwired (tests and reference only); a failed read logs `[RESUMEN] falló (...)` with `debugPrint` (reads of `image_reviews` are admin/superAdmin only: the rule is published (2026-10-01, copy in `firestore.rules.draft`); a non-admin read is denied in the rules playground, a real admin read is not verified yet); results go through an in-memory `SummaryCache` (5-minute TTL per date, successes only, max 10 dates) with an "Actualizar" button that reloads from the source; admin/superAdmin only (`canViewSummary`, decided; Revisor and Sumador don't see it), opened from the "Resumen" item of the chat-list menu |
| `matches` | `/matches` (`MatchesPage`): winning-numbers matches screen — reads REAL data (step 7, piece c): `matchesRepositoryProvider` returns `realMatchesRepositoryProvider` (`FirestoreMatchesRepository`: the day's winners from `winning_numbers/{date}` — PROVISIONAL name and shape, the collection doesn't exist yet, the bridge function will write it — compared against the Revisor's numbers of ALL jornadas and groups of that date, number only; one list per jornada, "Todavía no hay ganadores" when empty; each match reads its message and group name); opened without errors with an admin account on 2026-10-02; `MockMatchesRepository` stays unwired; a failed read logs `[COINCIDENCIAS] falló (...)`; "Ver imagen" loads the real image (not tested with a real image yet); admin/superAdmin only (`canViewMatches`), opened from the "Coincidencias" item of the chat-list menu |
| `home` | Responsive layout shell (split-view desktop, animated drawer on mobile); `custom_message_group.dart` renders each group tile |

**Image review feature status** — in active development, built layer by layer: roles + (group, shift) assignment, the capture form, local persistence (`hive_ce`), the Resumen (real data since step 7 piece d), and Coincidencias (`/matches`, admin/superAdmin only, real data since step 7 piece c) are done, and the per-jornada upload is now REAL (`reviewUploaderProvider` → `FirestoreReviewUploader`, step 7 layer 6), and the Firestore rules were published by hand on 2026-10-01; the first real write worked (4 TEST documents in production, jornadas `2026-10-01_afternoon2` and `2026-10-01_night1`, that must be deleted from the console before deploying hosting or letting anyone else use the Resumen). The record has ONE `codigo` per image (`ImageReviewForm.codigo`, required for both roles) and each comprobante is `{numeros, total, loteria}` with an optional free-text `loteria` (where the ticket was bought; not related to winning numbers); records saved before that change have `codigo: null` and aren't uploaded until re-saved (local schema still v1). The rest of step 7 is still pending. See `image-review-workflow` (in "Project Skills" below) for the step-by-step detail — not repeated here.

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
- `users` — User documents (`uid`, `email`, `displayName`, `allowedGroups[]`, `disabled`, `createdAt`, and `isAdmin` as a mirror written by `setUserRole`; the source of truth for roles is the custom claims). `isSuperAdmin` is NOT stored here: it only exists as a custom claim (set with `functions/set-admin.js`)
- `edit_attempts` — Audit trail for edited WhatsApp messages
- `image_reviews` — **PROVISIONAL**, image review records (Revisor/Sumador), structured group -> jornada -> registros: `image_reviews/{chatJid}/jornadas/{fechaJornada}_{shiftKey}/registros/{messageId}_{rol}`. **The upload is real** (`FirestoreReviewUploader`, built only when "Subir" is confirmed; each failure logs the messageId and failure type with `debugPrint`); `SimulatedReviewUploader` is no longer wired (candidate for removal). **The Firestore rules are PUBLISHED** (by hand in the console, verified by the user on 2026-10-01; the 7:37 p.m. version). `firestore.rules.draft` (repo root) is the copy of what was published: **not referenced in `firebase.json`**, published by hand in the console, which replaces the whole ruleset, so it starts with an exact copy of the console rules that were already there. It has the write rules for `registros` and the admin-only READ rules (`isAdmin()`, a recursive `match /{path=**}/registros/{registroId}` for the collection-group query, and `shift_image_counts` read for admins with writes denied). Its header comment still says "BORRADOR... no se despliega" (also in the published version): outdated, to fix in the repo and publish with the next rule change. The first real write is done: 4 TEST documents in production that must be deleted from the console before deploying hosting or letting anyone else use the Resumen. A real admin read and the real collection-group query are not verified yet. Names and wiring the reads are pending — see `image-review-offline-sync` ("Ruta de la subida")
- `winning_numbers` — **PROVISIONAL** name and shape, one document per date (`winning_numbers/{yyyy-MM-dd}`, field `numbers`, list of strings) read by Coincidencias. **The collection doesn't exist yet**: the bridge Cloud Function (its rule is decided, not implemented) will write it. Its rule (read for `isAdmin()`, writes denied) is **PUBLISHED since 2026-10-02**; the header of `firestore.rules.draft` still says that block isn't published (to fix)

**Cloud Functions** (`functions/index.js`) handle all privileged user-management operations: `createUser`, `setUserRole`, `updateUserPassword`, `deleteUser`, `listUsers`, `toggleUserStatus`, `updateUserGroups`, `listGroups`, `setReviewRole`, `updateReviewShifts`. All callable from Flutter via `FirebaseFunctions.instance.httpsCallable(name)`.

Role enforcement uses Firebase custom claims (`admin`, `superAdmin`) set server-side by Cloud Functions — never set client-side.

**Image review roles**: the role itself is a simple custom claim, `reviewRole: 'revisor' | 'sumador' | absent`, set by `setReviewRole` (superAdmin only, no guard against a superAdmin target — intentional). The list of (group, shift) an account covers is separate — real accounts cover several groups, some shared between different people of the same role on different shifts, so it doesn't fit a single tuple — and lives in Firestore, `users/{uid}.reviewShifts: [{chatJid, shift}]`, replaced wholesale by `updateReviewShifts` (superAdmin only; rejects if the target has no `reviewRole` yet). Changing `reviewRole` to a genuinely different value clears `reviewShifts`. Uniqueness (no two accounts with the same reviewRole + chatJid + shift) is enforced in `updateReviewShifts` by reading `listUsers(1000)` filtered to accounts that already have a `reviewRole`, then a single batched Firestore `getAll` over just those uids' `reviewShifts` — not a full second `listUsers` pass, not a scan of the whole `users` collection. Backend and `AdminPage` UI implemented, tested, and **deployed to production**: a role selector (Ninguno/Revisor/Sumador, `ReviewRoleDialog`) next to "Hacer admin/Quitar admin", and a "Horarios" button per checked group inside `AssignGroupsDialog` (`GroupShiftsDialog`, disables shifts already taken by another account of the same role, shown with that account's email). `AuthenticatedUser.reviewRole` reads the claim (`mapToDomain`) and is the real source of `currentReviewRoleProvider` (a dev-only `--dart-define=REVIEW_ROLE=...` fallback still applies when there's no real authenticated session); `reviewShifts` is read separately, once, by `reviewShiftsProvider` (same one-shot pattern as `allowedGroups`, no `.snapshots()`), and gates whether the capture form shows for a given image — see `image-review-roles`. The bridge Cloud Function to a *separate* Firebase project for shifts and winning numbers is also not implemented yet — see `image-review-firebase-integration`.

---

## Web / PWA

The app is also deployed as a PWA on Firebase Hosting (`build/web`, SPA rewrite to `/index.html`, see `firebase.json`).
- `web/sw.js` is a hand-written service worker; cache name is `CACHE_NAME` (currently `whatsapp-monitor-v2`) and `urlsToCache` lists precached files. Bump `CACHE_NAME` and keep `urlsToCache` in sync when changing web assets, or clients keep stale caches.
- Icons/favicon live in `web/icons/` and `web/favicon.png` (regenerated via `generate_icons.py`); `web/manifest.json` defines the PWA.
- Build/deploy: `flutter build web` then `firebase deploy --only hosting`.
- `lib/firebase_options.dart` is gitignored (generate with `flutterfire configure`). Local `*.pem` files in the repo root are local HTTPS dev certs — never commit them.

---

## Key Conventions

- **Freezed everywhere** — all domain entities and error types use `@freezed`. Run build_runner after changing them.
- **Spanish locale** — UI strings are in Spanish. Keep new UI text in Spanish.
- **Shifts** — `lib/core/time/shifts.dart` classifies messages into shifts with two fixed tables in code: the OLD one (06:00–10:54, 10:55–13:58, 13:59–15:23, 15:24–22:24, 22:25–22:30 `night2`, Sunday 06:00–19:20) and the NEW one, decided 2026-09-30 from the `jornadas` collection of the `whats-apuestas` project, used as a fixed table with no dynamic read (05:30–10:51, 10:58–13:55, 14:01–15:20, 15:28–22:15, Sunday 06:00–19:15; **no `night2`**). End minutes are inclusive and times are truncated to the minute. `newShiftsEffectiveFromMs` (UTC ms) is the cutover: `null` today, so the old table applies everywhere; a message uses the new table if its `messageTimestamp` >= the cutover. Enum keys never change; old labels are still recognized by `shiftFromLabel`. Gaps between new shifts are `outOfShift` for reports but labelled "Fuera de jornada X" in the viewer. Tested in `test/unit/shifts_test.dart`, `shifts_end_test.dart` and `shifts_cutover_test.dart`. **Pending**: cutover date and a coordinated deploy with the bot, retiring `night2` from `ASSIGNABLE_SHIFTS` in `functions/`, holiday source (only Sundays today), PWA cache — see `image-review-domain` ("Jornadas: tabla vieja, tabla nueva y corte").
- **Image URLs** — constructed client-side from `storagePath` using Firebase Storage public URL pattern; images are not stored as full URLs in Firestore.
- **Responsive system** — `lib/core/responsive/` provides `AppBreakpoints.mobile` (600px) and the `ResponsiveLayout(mobile:, desktop:)` widget (uses `MediaQuery.sizeOf`). Use these for any new responsive UI (used by login, admin page/dialogs, image detail page, message bubble). `home_page.dart` already uses the named `AppBreakpoints.homeSplit` (700px) with its own `LayoutBuilder` — not a hardcoded `_mobileBreakpoint` (that claim was stale; verified in code). **Planned**: the image review capture form needs a tablet-vs-phone distinction that `AppBreakpoints.mobile` likely can't provide — a new named breakpoint will probably be added there (see `image-review-roles`), not a local hardcoded value.
- **Performance** — `ChatList` and `MessageList`/`MessageBubble` were deliberately optimized for rendering (recent `perf:` commits); avoid rebuild-heavy changes there and keep widgets `const`/granular.
- **Pagination** — messages load 50 at a time; scroll to top triggers `loadMore()` on the `MessagesNotifier`.

---

## Project Skills (`.claude/skills/`)

Beyond generic Dart/Flutter/Firebase best practices (covered by installed plugins), this repo has project-specific skills. Read the relevant one(s) before working on the area they cover — they're the source of truth over assumptions from this file or from general Flutter knowledge:

| Skill | Covers |
|---|---|
| `ui-design` | Design system conventions (colors, spacing, typography, responsive patterns, loading/empty/error states) for any screen or widget in this app |
| `image-review-workflow` | **Start here** for any image-review task — maps to the other four skills below, suggested implementation roadmap, and a consolidated list of open questions blocking parts of the feature |
| `image-review-domain` | Vocabulary and business rules for the image review feature (comprobantes, números, totales, Revisor/Sumador reconciliation, shifts, the existing `Message` model) |
| `image-review-roles` | Revisor/Sumador roles: how they're activated (superAdmin only, from `AdminPage`), mutual exclusivity, tablet/PC-only restriction, mandatory-form navigation guard |
| `image-review-offline-sync` | Local-first storage for capture forms (`hive_ce`) and a manual per-jornada upload — REAL since step 7 layer 6 (rules published 2026-10-01, first real write done); jornada "completion" is never inferred by counting images (see `image-review-domain`) |
| `image-review-firebase-integration` | Bridge Cloud Function to an external Firebase project (shifts, winning numbers; its rule is decided, not implemented), match-and-detail-dialog flow — `/matches` reads real data (see `matches` in Features above) |

These skills capture the agreed design and the open questions. Read `image-review-workflow` first for the step-by-step roadmap and current status of each step, which it keeps up to date.