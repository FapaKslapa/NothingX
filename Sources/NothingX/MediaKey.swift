import AppKit

enum MediaKey {
    private static let codes: [NowPlayingItem.Command: Int] = [.playPause: 16, .next: 17, .previous: 18]

    static func post(_ command: NowPlayingItem.Command) {
        guard let code = codes[command] else { return }
        for down in [true, false] {
            let flags = down ? 0xA00 : 0xB00
            NSEvent.otherEvent(with: .systemDefined, location: .zero,
                               modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
                               timestamp: 0, windowNumber: 0, context: nil, subtype: 8,
                               data1: (code << 16) | flags, data2: -1)?
                .cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
