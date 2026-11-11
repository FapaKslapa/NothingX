import SwiftUI

struct NoiseControlCard: View {
    @Environment(HeadphoneModel.self) private var model

    private var connected: Bool { model.connection == .connected }

    var body: some View {
        let raw = model.ancRaw
        let kind = raw.map(ANCState.kind(of:))
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Noise control")
            Segmented(options: ANCKind.allCases.map { ($0, $0.label) }, selection: kind) { model.setANCKind($0) }
            if kind == .anc {
                Segmented(options: ANCLevel.allCases.map { ($0.rawValue, $0.label) }, selection: raw) { model.setANC($0) }
            }
        }
        .ntCard()
        .disabled(!connected)
        .opacity(connected ? 1 : 0.4)
    }
}
