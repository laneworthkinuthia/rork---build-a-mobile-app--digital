import SwiftUI

/// Large screen title with a supporting caption, used on every tab root.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    let caption: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(caption)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, Theme.margin)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, caption: String) {
        self.init(title: title, caption: caption) { EmptyView() }
    }
}

/// Small circular glyph button used in headers.
struct CircleIconButton: View {
    let symbol: String
    var size: CGFloat = 38
    var tint: Color = Theme.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Theme.surface, in: .circle)
                .overlay {
                    Circle().strokeBorder(Theme.hairline, lineWidth: 0.6)
                }
        }
        .buttonStyle(.pressable)
    }
}

/// Section title with an optional trailing "See all" affordance.
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, Theme.margin)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// Compact pill used for access badges, industries and audiences.
struct TagPill: View {
    let text: String
    var symbol: String?
    var tint: Color = Theme.textSecondary

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 9, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.14), in: .capsule)
    }
}

/// Button style that gives every tap a subtle physical response.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

/// Primary filled action used for the main call-to-action on a screen.
struct PrimaryButtonLabel: View {
    let title: String
    var symbol: String?
    var tint: Color = Theme.accent

    var body: some View {
        HStack(spacing: 7) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
            }
            Text(title).font(.system(size: 16, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(tint, in: .rect(cornerRadius: 14))
    }
}

/// Quiet secondary action, used beside a primary button.
struct SecondaryButtonLabel: View {
    let title: String
    var symbol: String?

    var body: some View {
        HStack(spacing: 7) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 14, weight: .semibold))
            }
            Text(title).font(.system(size: 16, weight: .semibold))
        }
        .foregroundStyle(Theme.textPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Theme.surfaceHigh, in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.hairline, lineWidth: 0.6)
        }
    }
}

/// Empty state used when a list has nothing to show yet.
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.textTertiary)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 44)
    }
}

/// Screen background: graphite canvas with a faint top glow for depth.
struct CanvasBackground: View {
    var body: some View {
        ZStack {
            Theme.canvas
            RadialGradient(
                colors: [Theme.accent.opacity(0.10), .clear],
                center: .init(x: 0.85, y: -0.05),
                startRadius: 10,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}
