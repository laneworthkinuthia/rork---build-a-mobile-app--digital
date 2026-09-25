# Cardex — Beta Handoff

**Status: CLOSED BETA CANDIDATE — READY FOR INDEPENDENT TECHNICAL VERIFICATION**

Not production ready. This document is the handoff for a technical team who did
not build the application. Verified 2026-09-25.

---

## 1. Architecture

```
ios-cardex/  (SwiftUI, iOS 18+, Xcode 26)
  CardexApp.swift → ContentView
    mode = UITEST_LOCAL launch arg ? .local (offline prototype) : .beta (default)
  CardexStore (@Observable, @MainActor) — single source of truth
    .beta  → BackendClient + RealtimeClient, server-authoritative snapshot
    .local → LocalMessageRepository + SampleData (tests/previews/UI tests only)
  Services/Backend/: AuthManager (Rork Auth, Apple/Google), KeychainHelper,
    BackendClient (typed errors), RealtimeClient (WebSocket), NotificationService

functions/   (Cloudflare Worker)
  index.ts        — routes; platform verifies Rork Auth token, stamps X-Rork-User-Id
  cardex-hub.ts   — CardexHub Durable Object ("global"): SQLite schema + all
                    beta state + WebSocket push (30 s client poll as fallback)
```

Identity: the platform verifies the bearer token and stamps `X-Rork-User-Id`
before the Worker sees the request. The app can never claim someone else's
identity; a missing header is a guest → 401. The card's `id` is **forced** to
the server-side user UUID on save (`card.id = me`), so QR payloads and every
relationship record resolve to one server-owned identity.

## 2. How to run

- **App:** open `ios-cardex/Cardex.xcodeproj`, run the Cardex scheme on an
  iOS 18+ simulator/device. Launching normally = beta mode (sign-in gate →
  onboarding → five-tab app). No local Xcode configuration is required; config
  values are injected at build time by the platform (`Config.swift` is empty in
  source by design).
- **Backend:** `functions/` deploys via Rork CI. Live deployment:
  `https://build-a-mobile-app-digital-business-card-backend.rork.app`
  (codeId 4099e095). Smoke test: `GET /ping` → 200; `GET /state` without auth
  → 401. Re-deploy happens automatically on changes to `functions/`.

## 3. How local/test mode is enabled (and why a normal build can't hit it)

- Beta mode is the default. `.local` is chosen **only** when the process
  launch argument `UITEST_LOCAL` is present — UI tests pass
  `["UITEST_RESET", "UITEST_SKIP_ONBOARDING", "UITEST_LOCAL"]`. A normal beta
  build has no launch arguments, so it cannot fall back to sample data.
- In local mode only: `SampleData` seeds, canned replies
  (`LocalMessageRepository.makeSimulatedReply`), the prototype "nearby
  exchange" strip, and random event distances. All other UI paths are gated on
  `store.mode == .beta`.
- `UITEST_RESET` / `UITEST_SKIP_ONBOARDING` act on defaults only and are inert
  without test-runner launch arguments.

## 4. Required environment variables / configuration

Already provisioned (public, build-time injected — nothing to add for beta):
`EXPO_PUBLIC_RORK_FUNCTIONS_URL`, `EXPO_PUBLIC_RORK_AUTH_URL`,
`EXPO_PUBLIC_RORK_APP_KEY`, `EXPO_PUBLIC_PROJECT_ID` (with literal fallbacks in
`CardexConfig` so local builds reach the beta backend). The OAuth callback
scheme `rork-p8bgff7cw7kasw6687yah` is registered in `ios-cardex/Info.plist`.

Server-side optional: `BETA_TEST_KEY` (unlocks the curl test harness via
`X-Beta-Test-Key`/`X-Beta-Test-User`; dead while unset).

No secrets, API keys, tokens or credentials exist anywhere in the repository
(verified by scan; `Config.swift` literals are intentionally empty; auth tokens
live in the Keychain only).

## 5. Verified (independently re-checked this pass)

- **Beta isolation:** `.beta` starts from a blank placeholder card and empty
  collections; `SampleData` is referenced only from the `.local` branch,
  `LocalMessageRepository`, tests/previews, and (fixed this pass) the card
  editor's transient draft — now `CardexStore.placeholderCard()`. Canned
  replies only run for `LocalMessageRepository`. Beta events have distance 0
  and no fabricated door queues/attendee counts.
- **Server-authoritative enforcement** (all in `cardex-hub.ts`):
  authentication (401 without identity), card ownership (`card.id = me`),
  Public/Connected/Trusted (contact details stripped server-side via
  `tieredCard`; grants clamped to the owner's visibility ceiling), connections
  (server-created for both sides), access requests (duplicates collapsed,
  self/blocked targets rejected, recipient-only resolve), messaging
  (connection required, block check, 4 000-char cap), blocking (tears down
  relationship both sides + hides pairs everywhere), account deletion (wipes
  all 13 tables), room membership (single joined room enforced server-side,
  ticket check, host-only door/broadcast), QR exchange (block/self/unknown
  checks, tier ceilings applied on both sides).
- **Error handling:** every mutation failure surfaces through
  `betaError` (alert) or the offline view/banner; the optimistic message bubble
  is rolled back on rejection; account deletion only wipes local state after
  the server confirms. `BackendError` maps status codes/codes to user-facing
  messages; no silent failures or false success states found.
- **Secrets:** none committed.
- **Tests:** unit suite **31/31 passing**; UI suite **8/8 passing**
  (previously-failing `testSendMessageFromInbox` now passes; see §7).
- **Builds:** `ios-cardex` simulator build green; `functions` deployed code
  verified live (`/ping` 200, unauthenticated `/state` 401).

## 6. Not verified / known limitations

- **Real-device behaviour** (camera capture on hardware, push on lock screen,
  backgrounding/foregrounding over cellular) — validated in the managed
  simulator and cloud emulator only.
- **Device build / App Store Release validation** — occurs during publish;
  `DEVELOPMENT_TEAM` and the production bundle ID are still placeholders
  (`app.rork.p8bgff7cw7kasw6687yah`).
- **Payments** are simulated (`SimulatedPaymentProcessor`, "charges nothing",
  labelled in the UI). The backend records real ticket membership. No card
  data is collected.
- **Push notifications** are in-app banners only; no APNs integration.
- Single global Durable Object; snapshot includes the last 1 000 messages and
  100 posts — fine for a small beta, not a scaling design.
- WebSocket events are triggers (`state.refresh` / typed events) plus message
  payloads; state consistency ultimately relies on the 30 s poll/refresh.

## 7. The UI test bug (fixed, then verified)

`testSendMessageFromInbox` failed for every previous run because
`SampleData.makeContacts()` produced **random UUIDs per call**: connections and
seeded messages were built from separate calls, so message threads never
matched their connection and the inbox computed empty. Fix: deterministic
`castID(_:)` UUIDs for the sample cast (`SampleData.swift`). Result: UI suite
8/8, unit suite 31/31.

## 8. Two-device test procedure

1. Install the build on two devices (device + simulator is fine).
2. Device A: open → Continue with Apple/Google → create card → privacy → Finish.
3. Device B: same, with a **different account**.
4. A: Live tab → join "Cardex Beta Lobby" → Tap to Exchange → **My Code**.
5. B: **Tap to Exchange** → Scan → point at A's QR → confirm the preview →
   "Cards exchanged" appears on both devices.
6. B: open A's card → Request Access; A approves in Cards → Requests; B's
   locked details unlock (the **server** decides what is visible).
7. Either side: Message → send — arrives on the other device via WebSocket
   (or next poll/foreground).
8. Force-quit both apps, reopen: connections, tiers, threads, unread counts
   and room membership all persist (server-side).
9. Optional: Profile → Block on either device — the connection, messages and
   discovery disappear for both.

## 9. Exact TestFlight requirements still outstanding

1. Apple Developer Team ID (`DEVELOPMENT_TEAM`) and final bundle ID + signer.
2. Privacy policy URL (App Store Connect field).
3. Camera usage strings are present; verify final review notes for QR scanning.
4. App Review account/notes if gating behind sign-in.
5. Decide APNs provisioning if background push is wanted for launch.

## 10. Known technical risks

1. Single Durable Object = single point of contention/failure (acceptable for
   closed beta scale; needs partitioning/sharding before public launch).
2. Snapshot-based sync (full state per refresh) — bandwidth grows with beta
   size; move to deltas if the beta grows past a few hundred users.
3. Photo blobs are inline transport-encoded JSON (1.5 MB cap) — fine for beta;
   move to object storage later.
4. Simulated payments must be replaced (or ticketed rooms disabled) before any
   real money moves.
5. `BETA_TEST_KEY` harness is dead while unset — keep it that way in prod.
