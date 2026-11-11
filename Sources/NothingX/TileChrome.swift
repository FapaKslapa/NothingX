import SwiftUI

extension View {
    func tileChrome(highlighted: Bool = false) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(highlighted ? 0.13 : 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(highlighted ? 0.18 : 0.07), lineWidth: 1))
            .animation(.snappy(duration: 0.2), value: highlighted)
    }
}

struct IconBadge: View {
    let symbol: String
    var filled = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(filled ? Color.black : NTColor.primary)
            .frame(width: 40, height: 40)
            .background(Circle().fill(filled ? Color.white.opacity(0.92) : Color.white.opacity(0.08)))
    }
}

struct TileText: View {
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 15, weight: .semibold))
            if let detail {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(NTColor.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SettingsTile<Content: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    var detail: LocalizedStringKey?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                IconBadge(symbol: symbol)
                TileText(title: title, detail: detail)
            }
            content
        }
        .tileChrome()
    }
}

struct ActionTile: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let buttonTitle: LocalizedStringResource
    var active = false
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                IconBadge(symbol: symbol, filled: active)
                    .symbolEffect(.variableColor.iterative, isActive: active)
                Spacer()
                PillButton(title: buttonTitle, prominent: true, action: action)
            }
            TileText(title: title, detail: detail)
        }
        .tileChrome(highlighted: active)
    }
}
