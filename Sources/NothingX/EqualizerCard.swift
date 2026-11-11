import SwiftUI

struct EqualizerCard: View {
    @Environment(HeadphoneModel.self) private var model

    private var spatialLocksEQ: Bool { model.spatial?.on == true && !model.isWired }

    var body: some View {
        let usable = model.connection == .connected || model.isWired
        let profile = model.isWired ? model.softwareEQProfile : model.eqProfile
        VStack(alignment: .leading, spacing: 24) {
            SectionHeader(title: "Equalizer")
            Segmented(
                options: EQPreset.allCases.map { ($0, $0.label) },
                selection: model.isWired ? model.softwareSelectedPreset : model.selectedPreset
            ) { model.selectPreset($0) }
            if let eq = profile {
                EQPanel(bands: eq.bands) { model.setBandGain($0, $1) } onEnd: { model.commitCustomEQ() }
                HStack(spacing: 24) {
                    Button { model.resetCustomEQ() } label: { ActionText("[Reset to zero]", NTColor.secondary) }
                        .buttonStyle(.plain)
                    EQFileActions(model: model)
                }
                if !model.eqImportNote.isEmpty {
                    Text(verbatim: model.eqImportNote).ntLabel(NTColor.disabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .ntCard()
        .disabled(!usable || spatialLocksEQ)
        .opacity(usable && !spatialLocksEQ ? 1 : 0.4)
    }
}
