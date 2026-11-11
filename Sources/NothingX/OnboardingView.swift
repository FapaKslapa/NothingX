import SwiftUI

struct OnboardingRoot: View {
    private let controller = OnboardingController.shared

    var body: some View {
        ZStack {
            ContentView()
                .disabled(controller.isPresented)
                .accessibilityHidden(controller.isPresented)
            if controller.isPresented {
                OnboardingView().transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: controller.isPresented)
    }
}

struct OnboardingView: View {
    @Environment(HeadphoneModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let service = NotificationService.shared

    @State private var flow = OnboardingFlow(bluetooth: Self.seed(BluetoothGate.current))

    @State private var beat: Task<Void, Never>?

    @State private var notificationRequest: Task<Void, Never>?
    @State private var requestingNotifications = false

    private static func seed(_ gate: BluetoothGate) -> OnboardingFlow.Bluetooth {
        switch gate {
        case .pending: .notAsked
        case .denied: .denied
        case .allowed: .allowed
        }
    }

    private var stepTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(x: 16)), removal: .opacity)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 28) {
                hero.frame(height: 140, alignment: .bottomLeading)
                ZStack(alignment: .topLeading) {
                    stepContent
                        .id(flow.step)
                        .transition(stepTransition)
                }
                .animation(.easeOut(duration: 0.3), value: flow.step)
            }
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.top, Layout.topInset)
            .padding(.horizontal, 32)
            bottomRow
                .frame(maxWidth: 560)
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
        }
        .overlay(alignment: .top) { WindowDragHandle().frame(height: 64) }
        .frame(minWidth: 900, maxWidth: .infinity, minHeight: 700, maxHeight: .infinity)
        .background(NTBackground())
        .contentShape(Rectangle())
        .foregroundStyle(NTColor.primary)
        .onChange(of: model.connection, initial: true) { forwardConnection() }
        .onChange(of: model.linkStarted) { forwardConnection() }
        .onChange(of: flow.linkShouldRun, initial: true) {
            if flow.linkShouldRun { startLinkLater() }
        }
        .onChange(of: flow.autoAdvances, initial: true) {
            if flow.autoAdvances { scheduleNext(from: .bluetooth) } else { cancelBeat() }
        }
        .onChange(of: flow.step) {
            cancelBeat()
            if flow.autoAdvances { scheduleNext(from: .bluetooth) }
        }
        .onChange(of: flow.outcome) {
            guard let outcome = flow.outcome else { return }
            OnboardingController.shared.finish(outcome)
            startLinkLater()
        }
        .onDisappear {
            cancelBeat()
            notificationRequest?.cancel()
            notificationRequest = nil

            if flow.outcome == nil { startLinkLater() }
        }
    }

    private func startLinkLater() {
        let model = model
        Task { @MainActor in model.startLink() }
    }

    private var heroKey: String { "step-\(flow.step.rawValue)-\(model.connection == .connected)" }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            heroContent
                .id(heroKey)
                .transition(.opacity)
        }
        .animation(.easeOut(duration: 0.3), value: heroKey)
    }

    @ViewBuilder private var heroContent: some View {
        if flow.step == .welcome {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 128, height: 128)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        } else if flow.step == .connect, model.connection == .connected {
            DeviceIllustration(deviceName: model.deviceName, size: 150).frame(width: 160, height: 140)
        } else {
            IconBadge(symbol: flow.step.symbol, filled: flow.step == .done)
                .scaleEffect(1.8, anchor: .bottomLeading)
        }
    }

    @ViewBuilder private var stepContent: some View {
        switch flow.step {
        case .welcome: WelcomeStep()
        case .bluetooth: BluetoothStep(state: flow.bluetooth)
        case .connect: ConnectStep()
        case .notifications: NotificationsStep()
        case .media: MediaStep()
        case .macAnchor: MacAnchorStep()
        case .done: DoneStep()
        }
    }

    private var bottomRow: some View {
        HStack(alignment: .center, spacing: 24) {
            OnboardingProgress(step: flow.step, completed: flow.completedSteps)
            Spacer(minLength: 0)
            Button { flow.handle(.skip) } label: { ActionText("[Skip]", NTColor.secondary) }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel(Text("Skip the welcome tour"))
            actions.fixedSize()
        }
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: 12) {
            switch flow.step {
            case .welcome:
                primary("[Continue]") { next(from: .welcome) }
            case .bluetooth:
                switch flow.bluetooth {
                case .notAsked:
                    primary("[Allow Bluetooth]") { flow.handle(.allowBluetooth) }
                case .denied:
                    secondary("[Open Bluetooth settings]") { BluetoothGate.openSettings() }
                case .waiting, .allowed:
                    EmptyView()
                }
            case .connect:
                if model.connection == .connected {
                    primary("[Continue]") { next(from: .connect) }
                } else {
                    secondary("[Pair in System Settings]") { OnboardingLinks.openBluetoothPairing() }
                    secondary("[Later]") { next(from: .connect) }
                }
            case .notifications:
                notificationActions
            case .media:
                secondary("[Continue]") { next(from: .media) }
                primary("[Allow all]") { MediaPermissionList.requestAll() }
            case .macAnchor:
                primary("[Got it]") { next(from: .macAnchor) }
            case .done:
                primary("[Start]") { next(from: .done) }
            }
        }
    }

    @ViewBuilder private var notificationActions: some View {
        switch service.authorization {
        case .notDetermined:
            secondary("[Not now]") { next(from: .notifications) }
            primary("[Allow]") { requestNotifications() }
                .disabled(requestingNotifications)
                .opacity(requestingNotifications ? 0.4 : 1)
        case .denied:
            secondary("[Open System Settings]") { service.openSystemSettings() }
            primary("[Continue]") { next(from: .notifications) }
        case .allowed, .unsupported:
            primary("[Continue]") { next(from: .notifications) }
        }
    }

    private func primary(_ title: LocalizedStringResource, action: @escaping () -> Void) -> some View {
        PillButton(title: title, prominent: true, action: action)
            .keyboardShortcut(.defaultAction)
    }

    private func secondary(_ title: LocalizedStringResource, action: @escaping () -> Void) -> some View {
        PillButton(title: title, action: action)
    }

    private func next(from step: OnboardingStep) {
        guard flow.step == step else { return }
        flow.handle(.next)
    }

    private func forwardConnection() {
        guard model.linkStarted else { return }
        let state: OnboardingFlow.Bluetooth
        switch model.connection {
        case .permissionPending: state = .waiting
        case .permissionDenied: state = .denied
        case .searching, .connecting, .connected: state = .allowed
        }
        if state != flow.bluetooth { flow.handle(.bluetoothChanged(state)) }
    }

    private func scheduleNext(from step: OnboardingStep) {
        beat?.cancel()
        beat = Task {
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            if step == .bluetooth, !flow.autoAdvances { return }
            next(from: step)
        }
    }

    private func cancelBeat() {
        beat?.cancel()
        beat = nil
    }

    private func requestNotifications() {
        guard !requestingNotifications else { return }
        requestingNotifications = true
        notificationRequest = Task {
            let ok = await service.requestAuthorization()
            requestingNotifications = false
            guard !Task.isCancelled, ok else { return }
            scheduleNext(from: .notifications)
        }
    }
}
