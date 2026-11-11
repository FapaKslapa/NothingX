import SwiftUI

struct CardScrollView<Content: View>: View {
    var inset: CGFloat = 0
    var room: CGFloat = Layout.shadowRoom
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, room)
                .padding(.top, inset)
                .padding(.bottom, room)
        }
        .padding(.horizontal, -room)
        .padding(.top, -inset)
        .padding(.bottom, -room)
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.top)
        .focusable(false)
    }
}
