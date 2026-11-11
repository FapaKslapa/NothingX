import SwiftUI

struct SettingsPanel: View {
    private enum Block: CaseIterable {
        case appearance, notifications, media, wired, updates, welcome

        @ViewBuilder var view: some View {
            switch self {
            case .appearance: AppearanceSection()
            case .notifications: NotificationsSection()
            case .media: MediaSection()
            case .wired: WiredSection()
            case .updates: UpdatesSection()
            case .welcome: WelcomeSection()
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            CardScrollView(inset: Layout.topInset) {
                columns(geometry.size.width >= 1100 ? 3 : geometry.size.width >= 720 ? 2 : 1)
            }
        }
    }

    private func columns(_ count: Int) -> some View {
        HStack(alignment: .top, spacing: Layout.gap) {
            ForEach(0..<count, id: \.self) { column in
                VStack(spacing: Layout.gap) {
                    ForEach(Block.allCases.enumerated().filter { $0.offset % count == column }.map(\.element), id: \.self) { $0.view }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    var trailing = ""
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: title, trailing: trailing)
            content
        }
        .ntCard()
    }
}

let settingsColumns = [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), spacing: 12, alignment: .top)]
