import SwiftUI

enum DeviceColor: String, CaseIterable {
    case black, white, pink, yellow

    static let key = "device.color"

    var color: Color {
        switch self {
        case .black: Color(white: 0.12)
        case .white: Color(white: 0.95)
        case .pink: Color(red: 0.96, green: 0.72, blue: 0.77)
        case .yellow: Color(red: 1, green: 0.88, blue: 0.29)
        }
    }

    var label: String {
        switch self {
        case .black: String(localized: "Black")
        case .white: String(localized: "White")
        case .pink: String(localized: "Pink")
        case .yellow: String(localized: "Yellow")
        }
    }
}
