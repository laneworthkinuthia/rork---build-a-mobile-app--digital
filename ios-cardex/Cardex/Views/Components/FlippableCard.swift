import SwiftUI

/// Wraps a card front and back in a real 3D flip with perspective and depth.
struct FlippableCard: View {
    @Binding var isFlipped: Bool
    let front: AnyView
    let back: AnyView

    init<Front: View, Back: View>(
        isFlipped: Binding<Bool>,
        @ViewBuilder front: () -> Front,
        @ViewBuilder back: () -> Back
    ) {
        self._isFlipped = isFlipped
        self.front = AnyView(front())
        self.back = AnyView(back())
    }

    private var angle: Double { isFlipped ? 180 : 0 }

    var body: some View {
        ZStack {
            front
                .opacity(isFlipped ? 0 : 1)
                .accessibilityHidden(isFlipped)

            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
                .opacity(isFlipped ? 1 : 0)
                .accessibilityHidden(!isFlipped)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .animation(.spring(response: 0.6, dampingFraction: 0.78), value: isFlipped)
    }
}
