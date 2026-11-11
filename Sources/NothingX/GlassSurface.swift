import SwiftUI

extension View {
    @ViewBuilder
    func ntGlass<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
                .background(shape.fill(tint ?? .clear))
                .overlay(shape.stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
    }

    func ntCard() -> some View { modifier(NTCard()) }
}

enum Layout {
    static let topInset: CGFloat = 84
    static let shadowRoom: CGFloat = 32
    static let gap: CGFloat = 16
}

extension View {
    func windowInset() -> some View {
        padding(.horizontal, 32)
            .padding(.top, Layout.topInset)
            .padding(.bottom, 32)
            .frame(maxHeight: .infinity)
    }
}

struct NTCard: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        content
            .padding(20)
            .background {
                shape.fill(.ultraThinMaterial)
                shape.fill(LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.05)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay(
                shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0.05)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 44, y: 22)
            .shadow(color: .black.opacity(0.06), radius: 14, y: 5)
    }
}

struct NTBackground: View {
    var body: some View {
        Color(white: 0.06)
            .overlay { GlassWallpaper() }
            .overlay(Color.black.opacity(0.4))
            .ignoresSafeArea()
    }
}

struct GlassWallpaper: View {
    var body: some View {
        if let image = NSImage(named: "GlassBackground") {
            Image(nsImage: image).resizable().scaledToFill()
        }
    }
}
