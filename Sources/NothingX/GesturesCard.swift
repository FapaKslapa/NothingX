import SwiftUI

struct GesturesCard: View {
    @Environment(HeadphoneModel.self) private var model

    private var connected: Bool { model.connection == .connected }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text("Gestures").ntLabel()
                Spacer()
                if model.gesturesDifferFromOriginal {
                    PillButton(title: "[Restore original]") { model.restoreOriginalGestures() }
                }
                Text("Experimental").ntLabel(NTColor.disabled)
            }
            if model.gestures.isEmpty {
                Text("—").ntLabel(NTColor.disabled)
            } else {
                GestureGrid(rows: model.gestures) { model.setGestureAction($0, action: $1) }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .ntCard()
        .disabled(!connected)
        .opacity(connected ? 1 : 0.4)
    }
}
