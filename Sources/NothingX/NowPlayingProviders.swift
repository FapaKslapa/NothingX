import AppKit

enum NowPlayingProviders {
    private static let spotifyID = "com.spotify.client"
    private static let musicID = "com.apple.Music"
    private static let browsers: [(target: MediaTarget, id: String, app: String)] = [(.chrome, "com.google.Chrome", "Google Chrome"), (.safari, "com.apple.Safari", "Safari")]
    private static let geckoBrowsers = ["app.zen-browser.zen", "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "one.ablaze.floorp"]

    static func read(running: Set<String>) -> [NowPlayingItem] {
        [spotify(running), music(running), youtube(running)].compactMap { $0 }
    }

    static func send(_ command: NowPlayingItem.Command, to item: NowPlayingItem, running: Set<String>) {
        if item.viaMediaKeys { return MediaKey.post(command) }
        switch item.source {
        case .spotify: _ = AppleScriptRunner.run("tell application \"Spotify\" to \(verb(command))")
        case .music: _ = AppleScriptRunner.run("tell application \"Music\" to \(verb(command))")
        case .youtube: controlYouTube(command, running: running)
        }
    }

    static func musicArtwork() -> NSImage? {
        AppleScriptRunner.run("tell application \"Music\" to return data of artwork 1 of current track")
            .flatMap { NSImage(data: $0.data) }
    }

    private static func verb(_ command: NowPlayingItem.Command) -> String {
        switch command {
        case .playPause: "playpause"
        case .next: "next track"
        case .previous: "previous track"
        }
    }

    private static func state(_ text: String) -> NowPlayingItem.State {
        text == "playing" ? .playing : text == "paused" ? .paused : .unknown
    }

    private static func spotify(_ running: Set<String>) -> NowPlayingItem? {
        guard running.contains(spotifyID), MediaPermissions.access(.spotify) == .granted else { return nil }
        let fields = AppleScriptRunner.strings(AppleScriptRunner.run("""
        tell application "Spotify"
            if player state is stopped then return {}
            return {player state as text, name of current track, artist of current track, artwork url of current track}
        end tell
        """))
        guard fields.count == 4, !fields[1].isEmpty else { return nil }
        return NowPlayingItem(source: .spotify, title: fields[1], artist: fields[2], state: state(fields[0]), artworkURL: URL(string: fields[3]))
    }

    private static func music(_ running: Set<String>) -> NowPlayingItem? {
        guard running.contains(musicID), MediaPermissions.access(.music) == .granted else { return nil }
        let fields = AppleScriptRunner.strings(AppleScriptRunner.run("""
        tell application "Music"
            if player state is stopped then return {}
            return {player state as text, name of current track, artist of current track}
        end tell
        """))
        guard fields.count == 3, !fields[1].isEmpty else { return nil }
        return NowPlayingItem(source: .music, title: fields[1], artist: fields[2], state: state(fields[0]), artworkURL: nil)
    }

    private static func youtube(_ running: Set<String>) -> NowPlayingItem? {
        for browser in browsers where running.contains(browser.id) && MediaPermissions.access(browser.target) == .granted {
            let fields = AppleScriptRunner.strings(AppleScriptRunner.run(tabQuery(browser.app)))
            guard fields.count == 3, let videoID = videoID(fields[1]) else { continue }
            let title = fields[0].replacingOccurrences(of: " - YouTube", with: "")
            return NowPlayingItem(source: .youtube, title: title, artist: "YouTube", state: state(fields[2]),
                                  artworkURL: URL(string: "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg"))
        }
        return geckoYouTube(running)
    }

    private static func geckoYouTube(_ running: Set<String>) -> NowPlayingItem? {
        guard MediaPermissions.accessibilityGranted, running.contains(where: geckoBrowsers.contains) else { return nil }
        MediaPermissions.ensureSystemEventsRunning()
        guard MediaPermissions.access(.gecko) == .granted else { return nil }
        for id in geckoBrowsers where running.contains(id) {
            let titles = AppleScriptRunner.strings(AppleScriptRunner.run("""
            tell application "System Events"
                return name of every window of (first application process whose bundle identifier is "\(id)")
            end tell
            """))
            guard let title = youtubeTitle(in: titles) else { continue }
            return NowPlayingItem(source: .youtube, title: title, artist: "YouTube", state: .unknown, artworkURL: nil, viaMediaKeys: true)
        }
        return nil
    }

    private static func tabQuery(_ app: String) -> String {
        let title = app == "Safari" ? "name" : "title"
        let probe = app == "Safari"
            ? "do JavaScript \"(function(){var v=document.querySelector('video');return v?(v.paused?'paused':'playing'):'unknown'})()\" in t"
            : "execute t javascript \"(function(){var v=document.querySelector('video');return v?(v.paused?'paused':'playing'):'unknown'})()\""
        return """
        tell application "\(app)"
            repeat with w in windows
                repeat with t in tabs of w
                    if URL of t contains "youtube.com/watch" then
                        set s to "unknown"
                        try
                            set s to \(probe)
                        end try
                        return {\(title) of t, URL of t, s}
                    end if
                end repeat
            end repeat
            return {}
        end tell
        """
    }

    static func youtubeTitle(in windowTitles: [String]) -> String? {
        windowTitles.first { $0.contains(" - YouTube") }.flatMap { $0.components(separatedBy: " - YouTube").first }
    }

    static func videoID(_ url: String) -> String? {
        URLComponents(string: url)?.queryItems?.first { $0.name == "v" }?.value
    }

    private static func controlYouTube(_ command: NowPlayingItem.Command, running: Set<String>) {
        let js: String
        switch command {
        case .playPause: js = "var v=document.querySelector('video');v.paused?v.play():v.pause()"
        case .next: js = "var b=document.querySelector('.ytp-next-button');if(b)b.click()"
        case .previous: js = "document.querySelector('video').currentTime=0"
        }
        for browser in browsers where running.contains(browser.id) {
            let run = browser.app == "Safari" ? "do JavaScript \"\(js)\" in t" : "execute t javascript \"\(js)\""
            _ = AppleScriptRunner.run("""
            tell application "\(browser.app)"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "youtube.com/watch" then
                            \(run)
                            return
                        end if
                    end repeat
                end repeat
            end tell
            """)
        }
    }
}
