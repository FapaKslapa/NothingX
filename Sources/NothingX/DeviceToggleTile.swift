import SwiftUI

struct DeviceToggleTile: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let value: Bool?
    let onSelect: (Bool) -> Void

    private var isOn: Bool { value == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                IconBadge(symbol: symbol, filled: isOn)
                Spacer()
                NTToggle(isOn: isOn, onChange: onSelect)
            }
            TileText(title: title, detail: detail)
        }
        .tileChrome(highlighted: isOn)
    }
}
