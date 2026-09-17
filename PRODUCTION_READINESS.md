# Cardex — Production Readiness

Last updated: 2026-09-17 (production-readiness pass).

## Current status

**Cardex is NOT production ready.** It is a polished, fully client-side prototype. There is
no backend, no authentication, no real messaging, no real payments, and no analytics. The
work in this pass established the architecture so those services can be added without
rewriting the UI, and fixed objective bugs (see below). Everything in this document should
be re-read before an App Store submission.

**Build status:** the app target compiles clean (simulator build verified after every
change). **Test status:** a unit suite (`CardexTests`) and UI suite (`CardexUITests`) are
written; execution was attempted and blocked by the managed runner after two
compile-error cycles in the new test code — both errors are fixed in source, but a
passing run has NOT yet been observed. Rerun `swiftTest` (target `CardexTests`) to verify.

## Architecture (as of this pass)

```
Views (SwiftUI)
  ↓
CardexStore (@Observable orchestration/state layer)
  ↓            ↓                 ↓
MessageRepository   PaymentProcessing   MediaStoring      (protocols)
  ↓            ↓                 ↓
LocalMessageRepository  SimulatedPaymentProcessor  FileMediaStore  (LOCAL / DEV ONLY)
```

- `CardexStore` is the single observable state/orchestration layer. It no longer owns
  message storage, payment simulation, or raw media blobs directly.
- All services are injected into `CardexStore(defaults:messageRepository:paymentProcessor:)`
  so tests can substitute mocks and a future backend can be dropped in.
- Sample data lives in `SampleData.swift` and is used **only** to seed local repositories
  on first launch. Nothing in the UI invents data at runtime except documented exceptions
  (see P1 list).

## Confirmed bugs fixed in this pass

1. **Missing camera usage description** — the camera capture flow (`CameraPicker`) would
   crash on a real device. `NSCameraUsageDescription` added to both app configurations.
   Photo-library picking uses `PhotosPicker` (PHPicker), which deliberately requires **no**
   permission, so no photo-library key is added.
2. **Fabricated metric** — `roomsAttended` returned joined rooms **+ 5**. Now returns the
   real count; shows an honest zero.
3. **Access ceiling not enforced everywhere** — `grantTier` and `exchangeCards` could grant
   tiers above the contact's visibility ceiling. All grants are now clamped via
   `AccessTier.clamped(by:)` (client-side only — see P0 note on server enforcement).
4. **Duplicate outgoing requests** — `requestAccess` could stack duplicate pending
   requests on repeated taps. All request flows now guard against duplicates.
5. **Stale-relationship state** — `removeConnection` left messages, requests, pending
   connection IDs and read markers behind. Full teardown now: messages deleted, requests
   removed, pending requests cleared, reply tasks cancelled, read markers cleared.
6. **Story expiration was render-once** — a 24h story stayed visible after expiring until
   some unrelated re-render. Live tab re-evaluates every 30 s via `TimelineView`.
7. **Silent persistence failures** — `persistOwner` swallowed encode errors with `try?`.
   Now logged via `os.Logger` (subsystem `Cardex`, category `persistence`).
8. **Unstructured delayed tasks** — the canned message reply Task was uncancellable and
   could append to a deleted relationship. Reply tasks are tracked, cancelled on
   relationship removal, re-validate the relationship before appending, and only run
   through the mock repository.

## Tests

Unit suite — `CardexTests/CardexTests.swift` (Swift Testing). Coverage:

- Access tier ordering; `clamped(by:)` semantics; `maxShareableTier` per visibility mode.
- Duplicate outgoing card requests collapsed; duplicate access requests collapsed.
- Approving an incoming request creates a connection whose tier is clamped to the owner's
  ceiling; declining does not create a connection.
- `grantTier` and `exchangeCards` never exceed the contact's visibility ceiling.
- `removeConnection` teardown: messages, requests, pending IDs, discoverable round-trip.
- Room joining; single-joined-room invariant; leaving; ticketed rooms block entry until
  `purchaseTicket` (with an injected zero-delay `SimulatedPaymentProcessor`);
  `purchaseTicket` is a no-op for non-ticketed rooms; `roomsAttended` is the real count.
- Messaging: `sendMessage` appends to the right thread; unknown recipients ignored;
  simulated replies are attributed to the partner and only produced by the local repo.
- Story expiration at the 24-hour boundary.
- Persistence: photo blobs are stored on disk, never in the JSON payload; the legacy
  inline-blob format still decodes (migration); message round-trip.
- Search: connections, people and rooms match/filter correctly.

UI suite — `CardexUITests/CardexUITests.swift` (XCTest), driven by new launch arguments
(`UITEST_RESET`, `UITEST_SKIP_ONBOARDING` handled in `CardexStore.init`):

- All five tabs navigate to their screens.
- Onboarding completes to the main tab shell (name entry required at identity step).
- Profile → Messages → seeded thread → send a message → sent bubble appears.
- Cards → Rooms stat tile opens My Rooms.

**Neither suite has a passing run recorded yet** — see the note under Current status.

## Prototype-only behavior (still present, clearly marked)

| Area | Implementation | File |
|---|---|---|
| Messaging | `LocalMessageRepository` — local JSON file, seeds sample threads, **simulated replies** | `Services/MessageRepository.swift` |
| Payments | `SimulatedPaymentProcessor` — sleeps, charges nothing | `Services/PaymentService.swift` |
| Exchange / QR scanning | Simulated locally | `ExchangeView.swift` |
| Rooms / people | Seeded from `SampleData`; live counts, distances and door queues are sample values | `SampleData.swift` |
| Approvals of outgoing requests | Simulated on-device via `grantTier` | `CardexStore.swift` |
| Feed, stories of others | Sample data | `SampleData.swift` |

Every one of these is isolated behind a protocol or clearly-marked sample file so a real
implementation replaces it without UI changes.

## P0 — BLOCKER (must be resolved before public release)

1. **Server-side backend does not exist.** All data is local. Anything privacy-sensitive
   (access tiers, visibility, trusted details, messages, event permissions) is currently
   enforced **client-side only** and can be bypassed. Required: an account backend that
   owns and enforces ownership, visibility ceilings, tier grants, room membership and
   messaging authorization. Affected: every repository protocol in `Cardex/Services/`.
   *What I need from you: which backend/provider to target (or approve building one).*
2. **Authentication does not exist.** No sign-in, no user identity beyond a local card.
   Required before multi-user anything. File: `CardexStore.swift`, `ContentView.swift`.
3. **Payments are simulated.** `SimulatedPaymentProcessor` performs no transaction and
   must be replaced with a real provider + server receipt validation before selling
   tickets. File: `Services/PaymentService.swift`, `TicketSheet.swift`.
   *What I need from you: payment provider choice (Stripe / Adyen / IAP if digital-only).*
4. **Real messaging.** `LocalMessageRepository` is local-only; replies are canned.
   Needs push transport + backend. File: `Services/MessageRepository.swift`.
5. **Apple Developer configuration.** `DEVELOPMENT_TEAM` is empty,
   `PRODUCT_BUNDLE_IDENTIFIER = app.rork.p8bgff7cw7kasw6687yah` (prototype identifier).
   Both must be replaced with your permanent values. Files: `project.pbxproj`
   (4 configurations). *I did not invent values for these.*
6. **Privacy policy + App Store metadata** do not exist yet (required for submission).

## P1 — SHOULD FIX BEFORE PUBLIC RELEASE

- `CardexStore` still owns connections/rooms/feed state in memory only; a relaunch resets
  everything except the owner card and messages. Connections/rooms/requests need the same
  local-persistence treatment messages got (or a backend).
- Read markers persist to `UserDefaults` (small JSON) — acceptable short-term, move with
  the messaging backend.
- `owner.photoData` legacy path still decodes inline blobs from old `UserDefaults` records
  (migration-safe, but old installs should be re-saved once to migrate to `FileMediaStore`).
- Story `TimelineView` refresh is only on the Live tab; story chips elsewhere refresh on
  next navigation. Cosmetic staleness only (≤ a few minutes).
- Room "live" counts and door queues are sample data; UI shows them as if real.
- Discover distances are fabricated sample values, and the "London" chip was removed, but
  the search header still implies location awareness. Real location (CoreLocation) is
  intentionally **not** implemented — no location permission is requested.
- No analytics/crash reporting configured. Do not add any provider until you choose one.
- UI test coverage exists but is basic (launch, tabs, onboarding, messaging); UI tests
  have not been executed yet (see Current status).

## P2 — POLISH / QUALITY

- Bundled portrait/venue PNGs were recompressed to ≤1200 px JPEG (~70% bundle reduction).
  The 1024 px app icon stays PNG as required.
- `CardexStore` is still a large file; further feature work should split it into
  feature-level stores as described in Phase 2.
- Accessibility: core labels exist; a full Dynamic Type / VoiceOver sweep on every screen
  is still outstanding.

## FUTURE — NOT REQUIRED FOR FIRST RELEASE

- Push notifications (requests, messages, approvals).
- Widget / share-extension targets.
- NFC / real QR scanning.
- End-to-end encryption for trusted-tier details.

## External configuration still required (nothing is invented below)

| Item | Where | What to provide |
|---|---|---|
| Apple Developer Team ID | `project.pbxproj` `DEVELOPMENT_TEAM` | Your team ID |
| Production Bundle ID | `project.pbxproj` `PRODUCT_BUNDLE_IDENTIFIER` (4 places) | e.g. `com.yourcompany.cardex` |
| Backend + auth provider | new `Services/` implementations | Provider decision |
| Payment provider | `PaymentProcessing` implementation | Provider decision |
| Push notification certs | Capabilities + entitlements | After backend exists |
| Analytics / crash reporting | — | Provider decision (currently none) |
| Privacy policy URL | App Store Connect | URL |
| App Store metadata | App Store Connect | Copy, screenshots |
