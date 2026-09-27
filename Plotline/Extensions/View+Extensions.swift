import SwiftUI

// MARK: - Navigation Namespace Environment Key

private struct NavigationNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var navigationNamespace: Namespace.ID? {
        get { self[NavigationNamespaceKey.self] }
        set { self[NavigationNamespaceKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Shimmer Effect

/// A light band that sweeps across a loading placeholder.
///
/// With Reduce Motion on, the placeholder renders static: the fill alone
/// already reads as "loading", and a band sweeping forever is exactly the kind
/// of motion that setting asks the app to drop.
struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay(
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.2),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 2)
                        .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                    }
                )
                .mask(content)
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        }
    }
}

extension View {
    /// Applies a shimmer loading effect
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}
