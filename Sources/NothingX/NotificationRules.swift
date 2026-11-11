import Foundation

struct LowBatteryRule {
    static let allowedThresholds = [20, 10]
    static let defaultThreshold = 20

    static let rearmMargin = 10

    private(set) var armed = true
    private var lastThreshold: Int?

    mutating func evaluate(level: Int?, charging: Bool, threshold: Int) -> Bool {
        if let last = lastThreshold, last != threshold { armed = true }
        lastThreshold = threshold
        guard let level else { return false }
        if charging {
            armed = true
            return false
        }
        if !armed, level > threshold + Self.rearmMargin { armed = true }
        guard armed, level <= threshold else { return false }
        armed = false
        return true
    }
}

struct ConnectionNotificationRule {
    static let startupGrace: TimeInterval = 8

    private var wasConnected = false

    mutating func evaluate(connected: Bool, uptime: TimeInterval) -> Bool {
        defer { wasConnected = connected }
        return connected && !wasConnected && uptime >= Self.startupGrace
    }
}
