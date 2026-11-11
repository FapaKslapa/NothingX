import Foundation

enum DeviceKind {
    case headphone, earbuds

    init(name: String) {
        self = name.localizedCaseInsensitiveContains("headphone") ? .headphone : .earbuds
    }

    var isEarbuds: Bool { self == .earbuds }

    static func isNothingAudio(_ name: String) -> Bool {
        name.localizedCaseInsensitiveContains("nothing")
            && name.range(of: #"\bphone\b"#, options: [.regularExpression, .caseInsensitive]) == nil
    }
}
