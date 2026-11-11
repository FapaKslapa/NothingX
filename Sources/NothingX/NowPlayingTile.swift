import SwiftUI

struct NowPlayingTile: View {
    let service: NowPlayingService
    private let tour = OnboardingController.shared

    var body: some View {
        VStack { content }
            .task(id: tour.isPresented) {
                guard !tour.isPresented else { return }
                service.attach()
                defer { service.detach() }
                try? await Task.sleep(for: .seconds(86_400))
            }
    }

    @ViewBuilder private var content: some View {
        if let item = service.current {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Now playing")
                if service.items.count > 1 { sourceChips(selected: item.source) }
                HStack(spacing: 14) {
                    Artwork(item: item, music: service.musicArtwork)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: item.title).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                        Text(verbatim: item.artist).font(.system(size: 12)).foregroundStyle(NTColor.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                if item.canSeek, let duration = item.duration {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        ProgressSlider(position: service.position(of: item, at: context.date), duration: duration) { service.seek(to: $0) }
                    }
                }
                HStack(spacing: 16) {
                    Spacer(minLength: 0)
                    RoundButton(symbol: "backward.fill", size: 38, label: "Previous track") { service.send(.previous) }
                    RoundButton(symbol: playSymbol(item.state), size: 50, prominent: true, label: "Play / pause") { service.send(.playPause) }
                    RoundButton(symbol: "forward.fill", size: 38, label: "Next track") { service.send(.next) }
                    Spacer(minLength: 0)
                }
                .disabled(!service.canControl(item))
                .opacity(service.canControl(item) ? 1 : 0.4)
            }
            .ntCard()
        }
    }

    private func playSymbol(_ state: NowPlayingItem.State) -> String {
        switch state {
        case .playing: "pause.fill"
        case .paused: "play.fill"
        case .unknown: "playpause.fill"
        }
    }

    private func sourceChips(selected: NowPlayingItem.Source) -> some View {
        HStack(spacing: 8) {
            ForEach(service.items) { item in
                Button { service.selected = item.source } label: {
                    Label(item.source.name, systemImage: item.source.symbol)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.white.opacity(item.source == selected ? 0.16 : 0.06)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct Artwork: View {
    let item: NowPlayingItem
    let music: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.08))
            Image(systemName: item.source.symbol).font(.system(size: 26)).foregroundStyle(NTColor.disabled)
            if item.source == .music, let music {
                Image(nsImage: music).resizable().scaledToFill()
            } else if let url = item.artworkURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                }
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
    }
}

private struct RoundButton: View {
    let symbol: String
    let size: CGFloat
    var prominent = false
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(prominent ? Color.black : NTColor.primary)
                .frame(width: size, height: size)
                .contentShape(Circle())
                .background(Circle().fill(prominent ? Color.white.opacity(0.92) : Color.clear))
                .ntGlass(Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}
