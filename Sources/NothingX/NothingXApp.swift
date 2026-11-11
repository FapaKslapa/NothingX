import SwiftUI
import AppKit

struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
}

struct WindowConfigurator: NSViewRepresentable {
    var title = "Nothing X"

    func makeNSView(context: Context) -> NSView {
        let view = ConfiguratorView()
        view.windowTitle = title
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class ConfiguratorView: NSView {
        private var observers: [NSObjectProtocol] = []
        private var hiddenWatchers: [NSKeyValueObservation] = []
        var windowTitle = "Nothing X"

        override func viewDidMoveToWindow() {
            guard let window else { return }
            window.title = windowTitle
            window.styleMask.formUnion([.titled, .closable, .miniaturizable, .fullSizeContentView])
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden

            window.isMovableByWindowBackground = false
            window.backgroundColor = .black
            raiseTrafficLights(in: window)

            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResizeNotification, NSWindow.didExposeNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self, weak window] _ in
                    if let window { self?.raiseTrafficLights(in: window) }
                })
            }
            DispatchQueue.main.async { [weak self, weak window] in
                if let window { self?.raiseTrafficLights(in: window) }
            }
        }

        private func raiseTrafficLights(in window: NSWindow) {
            for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                window.standardWindowButton(kind)?.isHidden = false
            }
            guard let frameView = window.contentView?.superview,
                  var container = window.standardWindowButton(.closeButton)?.superview else { return }
            while let parent = container.superview, parent !== frameView { container = parent }
            guard container.superview === frameView else { return }
            if frameView.subviews.last !== container {
                frameView.addSubview(container, positioned: .above, relativeTo: nil)
            }
            hideTitlebarBackground(in: container)
        }

        private func hideTitlebarBackground(in view: NSView) {
            for sub in view.subviews {
                let name = String(describing: type(of: sub))
                if name == "NSTitlebarBackgroundView" || sub is NSVisualEffectView {
                    if !sub.isHidden { sub.isHidden = true }
                    if !hiddenWatchers.contains(where: { _ in false }) {
                        hiddenWatchers.append(sub.observe(\.isHidden, options: [.new]) { v, _ in
                            if !v.isHidden { v.isHidden = true }
                        })
                    }
                } else {
                    hideTitlebarBackground(in: sub)
                }
            }
        }
    }
}

@main
struct NothingXApp: App {

    @State private var model = HeadphoneModel(startLink: !OnboardingController.shared.isPresented || BluetoothGate.current != .pending)

    @State private var navigation = AppNavigation()
    private let updater = Updater.shared

    private static var menuBarImage: NSImage {
        let image = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "headphones", accessibilityDescription: nil)!
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            OnboardingRoot()
                .environment(model)
                .environment(navigation)
                .preferredColorScheme(.dark)
                .background(WindowConfigurator())
                .ntAccentRoot()
        }
        .windowResizability(.contentMinSize)
        .commands { SettingsCommand(navigation: navigation) }

        MenuBarExtra {
            MenuBarPanel()
                .environment(model)
                .environment(navigation)
                .preferredColorScheme(.dark)
                .ntAccentRoot()
        } label: {
            Image(nsImage: Self.menuBarImage)
            if let level = model.battery { Text(verbatim: "\(level)%") }
        }
        .menuBarExtraStyle(.window)
    }
}

struct SettingsCommand: Commands {
    let navigation: AppNavigation
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                navigation.showSettings = true
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            .keyboardShortcut(",")
        }
    }
}
