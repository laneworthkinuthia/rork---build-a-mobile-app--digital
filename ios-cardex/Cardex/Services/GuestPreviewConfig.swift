import Foundation

/// Guest / Preview mode configuration.
///
/// Guest mode is a development-only way to explore the full Cardex UI with
/// local sample data, without creating an account, authenticating, or ever
/// reaching the backend. It is deliberately hard to ship:
///
/// 1. The entry point ("Continue as Guest") is compiled into DEBUG builds only.
/// 2. `isAvailable` is `false` in release builds, so no code path — sign-in
///    button, launch argument, or notification — can enter guest mode outside
///    development.
/// 3. Guest state lives in a separate `UserDefaults` suite, never in a beta
///    user's keys, and never leaves the device. A guest store has
///    `CardexStore.isGuestPreview == true`, `mode == .local`, and no auth
///    identity, so it can never be confused with a signed-in beta account.
enum GuestPreviewConfig {
    /// Optional launch argument that boots straight into guest preview.
    /// The sign-in screen button is the normal entry point.
    static let launchArgument = "GUEST_PREVIEW"

    /// Guest persistence is fully isolated from beta user defaults.
    static let defaultsSuiteName = "cardex.guest-preview"

    /// Shown instead of silently failing when an action needs a real account.
    static let accountRequiredMessage =
        "This feature requires a Cardex account. Preview mode shows local sample data only."

    /// Guest mode exists only in DEBUG builds. Release / TestFlight builds
    /// contain no guest entry point at all.
    static var isAvailable: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Whether this launch was asked to start in guest preview.
    static var isRequested: Bool {
        isAvailable && ProcessInfo.processInfo.arguments.contains(launchArgument)
    }
}

extension Notification.Name {
    /// Posted by views inside guest mode to request exiting back to the
    /// sign-in gate. ContentView owns the actual mode switch.
    static let guestPreviewExit = Notification.Name("cardex.guestPreview.exit")
}
