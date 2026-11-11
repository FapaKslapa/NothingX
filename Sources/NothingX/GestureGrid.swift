import SwiftUI

struct GestureGrid: View {
    let rows: [GestureBinding]
    let onChange: (GestureBinding, UInt8) -> Void

    private var groups: [[GestureBinding]] {
        Dictionary(grouping: rows) { Int($0.side) << 8 | Int($0.button) }
            .sorted { $0.key < $1.key }
            .map { $0.value.sorted { $0.gesture < $1.gesture } }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(groups, id: \.first?.id) { group in
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        IconBadge(symbol: GestureBinding.partSymbol(group[0]))
                        Text(verbatim: GestureBinding.sideName(group[0].side) ?? GestureBinding.controlName(group[0].button))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    ForEach(group) { row in
                        GestureTile(row: row) { onChange(row, $0) }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .tileChrome()
            }
        }
    }
}

private struct GestureTile: View {
    let row: GestureBinding
    let onChange: (UInt8) -> Void

    private var options: [UInt8] {
        GestureBinding.knownActions + (GestureBinding.knownActions.contains(row.action) ? [] : [row.action])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TapGlyph(gesture: row.gesture)
                Text(verbatim: GestureBinding.gestureName(row.gesture))
                    .font(.system(size: 13))
                    .foregroundStyle(NTColor.secondary)
            }
            Menu {
                ForEach(options, id: \.self) { action in
                    Button { onChange(action) } label: {
                        Label(GestureBinding.actionName(action), systemImage: GestureBinding.actionSymbol(action))
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: GestureBinding.actionSymbol(row.action)).frame(width: 16)
                    Text(verbatim: GestureBinding.actionName(row.action)).lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 9)).foregroundStyle(NTColor.disabled)
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.white.opacity(0.1)))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
        }
    }
}

private struct TapGlyph: View {
    let gesture: UInt8

    private var taps: Int {
        switch gesture {
        case 0x03: 2
        case 0x07: 3
        default: 1
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            if gesture == 0x09 {
                Capsule().frame(width: 22, height: 6)
            } else {
                ForEach(0..<taps, id: \.self) { _ in Circle().frame(width: 6, height: 6) }
            }
        }
        .foregroundStyle(NTColor.primary)
        .frame(width: 26, alignment: .leading)
    }
}

extension GestureBinding {
    static func actionSymbol(_ action: UInt8) -> String {
        switch action {
        case 0x01: "minus.circle"
        case 0x08: "forward.fill"
        case 0x09: "playpause.fill"
        case 0x16: "backward.fill"
        case 0x0B: "waveform"
        default: "questionmark.circle"
        }
    }

    static func partSymbol(_ row: GestureBinding) -> String {
        switch (row.side, row.button) {
        case (0x02, _): "l.circle"
        case (0x03, _): "r.circle"
        case (_, 0x01): "dial.medium"
        default: "button.programmable"
        }
    }
}
