import SwiftUI

struct ActionText: View {
    let title: LocalizedStringResource
    let color: Color

    init(_ title: LocalizedStringResource, _ color: Color = NTColor.secondary) {
        self.title = title
        self.color = color
    }

    var body: some View {
        Text(verbatim: String(localized: title).trimmingCharacters(in: CharacterSet(charactersIn: "[]")))
            .ntLabel(color)
    }
}
