import SwiftUI

enum AccentChoice: String, CaseIterable {
    case red, orange, yellow, green, blue, pink, white, gray, black

    static let key = "appearance.accent"

    var color: Color {
        switch self {
        case .red: Color(red: 0.843, green: 0.098, blue: 0.129)
        case .orange: Color(red: 1, green: 0.48, blue: 0.1)
        case .yellow: Color(red: 0.96, green: 0.77, blue: 0.09)
        case .green: Color(red: 0.18, green: 0.82, blue: 0.48)
        case .blue: Color(red: 0.04, green: 0.52, blue: 1)
        case .pink: Color(red: 1, green: 0.3, blue: 0.55)
        case .white: Color(white: 0.95)
        case .gray: Color(white: 0.55)
        case .black: Color(white: 0.1)
        }
    }

    var label: String {
        switch self {
        case .red: String(localized: "Red")
        case .orange: String(localized: "Orange")
        case .yellow: String(localized: "Yellow")
        case .green: String(localized: "Green")
        case .blue: String(localized: "Blue")
        case .pink: String(localized: "Pink")
        case .white: String(localized: "White")
        case .gray: String(localized: "Gray")
        case .black: String(localized: "Black")
        }
    }
}

private struct AccentKey: EnvironmentKey {
    static let defaultValue = AccentChoice.red.color
}

extension EnvironmentValues {
    var ntAccent: Color {
        get { self[AccentKey.self] }
        set { self[AccentKey.self] = newValue }
    }
}

struct AccentRoot: ViewModifier {
    @AppStorage(AccentChoice.key) private var choice = AccentChoice.red

    func body(content: Content) -> some View {
        content.environment(\.ntAccent, choice.color)
    }
}

extension View {
    func ntAccentRoot() -> some View { modifier(AccentRoot()) }
}
