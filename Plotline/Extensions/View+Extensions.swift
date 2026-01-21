import SwiftUI

// MARK: - View Extensions

extension View {
    /// Applies a card-style background
    func cardStyle(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(Color.plotlineCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Applies conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Applies conditional modifier with else clause
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        if ifTransform: (Self) -> TrueContent,
        else elseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTransform(self)
        } else {
            elseTransform(self)
        }
    }

    /// Hide view conditionally
    @ViewBuilder
    func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide {
            self.hidden()
        } else {
            self
        }
    }

    /// Read the size of a view
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometry.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}

// MARK: - Preference Keys

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - Font Extensions

extension Font {
    /// Plotline title font
    static func plotlineTitle(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    /// Plotline headline font
    static func plotlineHeadline(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    /// Plotline body font
    static func plotlineBody(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    /// Plotline caption font
    static func plotlineCaption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    /// Monospaced font for ratings
    static func plotlineRating(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

// MARK: - Animation Extensions

extension Animation {
    /// Standard Plotline animation
    static var plotlineStandard: Animation {
        .easeInOut(duration: 0.3)
    }

    /// Fast Plotline animation
    static var plotlineFast: Animation {
        .easeInOut(duration: 0.15)
    }

    /// Spring animation for interactive elements
    static var plotlineSpring: Animation {
        .spring(response: 0.3, dampingFraction: 0.7)
    }
}

// MARK: - Transition Extensions

extension AnyTransition {
    /// Slide and fade transition
    static var slideAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    /// Scale and fade transition
    static var scaleAndFade: AnyTransition {
        .scale(scale: 0.9).combined(with: .opacity)
    }
}
