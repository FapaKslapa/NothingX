import SwiftUI

struct MediaPermissionList: View {
    @State private var states: [MediaTarget: MediaAccess] = [:]

    static func requestAll() {
        DispatchQueue.global(qos: .userInitiated).async {
            for target in MediaTarget.allCases where MediaPermissions.access(target) != .granted && MediaPermissions.access(target) != .notRunning {
                MediaPermissions.request(target)
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(MediaTarget.allCases, id: \.self) { target in
                row(target, states[target] ?? .notRunning)
            }
        }
        .task {
            while !Task.isCancelled {
                for target in MediaTarget.allCases { states[target] = MediaPermissions.access(target) }
                try? await Task.sleep(for: .seconds(1.5))
            }
        }
    }

    private func row(_ target: MediaTarget, _ state: MediaAccess) -> some View {
        HStack(spacing: 12) {
            IconBadge(symbol: target.symbol, filled: state == .granted)
            Text(verbatim: target.name).font(.system(size: 14, weight: .medium))
            Spacer(minLength: 8)
            switch state {
            case .granted:
                Text("Allowed").ntLabel(NTColor.secondary)
            case .notRunning:
                Text("Not open").ntLabel(NTColor.disabled)
            case .notAsked:
                PillButton(title: "Allow", prominent: true) {
                    DispatchQueue.global(qos: .userInitiated).async { MediaPermissions.request(target) }
                }
            case .denied:
                PillButton(title: "Open System Settings") { MediaPermissions.openAutomationSettings() }
            }
        }
        .tileChrome()
    }
}
