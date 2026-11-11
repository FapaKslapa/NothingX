import Foundation

enum AppleScriptRunner {
    static func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }

    static func strings(_ descriptor: NSAppleEventDescriptor?) -> [String] {
        guard let descriptor else { return [] }
        return (0..<descriptor.numberOfItems).map { descriptor.atIndex($0 + 1)?.stringValue ?? "" }
    }
}
