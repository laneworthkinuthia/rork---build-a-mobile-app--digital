import SwiftUI
import AuthenticationServices

/// The first thing a beta user sees: create an account or return to one.
/// Apple and Google sign-in through Rork Auth — the backend identity every
/// card, connection and message belongs to.
struct SignInGateView: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 40)

            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 20)
                        .fill(CardPalette.allCases[index].base)
                        .frame(width: 200, height: 122)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 0.8)
                        }
                        .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
                        .rotationEffect(.degrees(Double(index - 1) * 7))
                        .offset(y: CGFloat(index) * -14)
                }
            }

            VStack(spacing: 10) {
                Text("Welcome to Cardex")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Sign in to carry your card, meet people and keep every connection in one place.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            Spacer(minLength: 20)

            VStack(spacing: 12) {
                if auth.isSigningIn {
                    ProgressView()
                        .tint(Theme.accent)
                        .frame(height: 50)
                } else {
                    SignInWithAppleButton(.signIn) { _ in
                        Task { await auth.signIn(provider: "apple") }
                    } onCompletion: { _ in }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .clipShape(.rect(cornerRadius: 14))
                        .font(.system(size: 16, weight: .semibold))

                    Button {
                        Task { await auth.signIn(provider: "google") }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Theme.surfaceHigh, in: .rect(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Theme.hairline, lineWidth: 0.8)
                        }
                    }
                    .buttonStyle(.pressable)
                }

                if let error = auth.authError {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.warning)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
            }
            .padding(.horizontal, Theme.margin)

            Spacer(minLength: 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.canvas.ignoresSafeArea())
    }
}
