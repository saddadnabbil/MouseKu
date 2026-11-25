import AppKit
import ServiceManagement

final class Store: ObservableObject {
    @Published var config: Config {
        didSet {
            if let data = try? JSONEncoder().encode(config) {
                UserDefaults.standard.set(data, forKey: "config")
            }
            if oldValue.enabled != config.enabled { apply() }
        }
    }
    @Published var needsPermission = false
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var errorText: String?

    private lazy var tap = EventTap(store: self)
    private var poll: Timer?

    init() {
        config = Config.load(UserDefaults.standard.data(forKey: "config"))
    }

    /// Starts or stops the event tap and keeps watching the Accessibility permission.
    func apply() {
        poll?.invalidate()
        poll = nil
        guard config.enabled else {
            tap.stop()
            needsPermission = false
            return
        }
        refresh()
        poll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
    }

    private func refresh() {
        let ok: Bool
        if AXIsProcessTrusted() {
            ok = tap.start()
        } else {
            tap.stop()
            ok = false
        }
        if needsPermission == ok { needsPermission = !ok }
    }

    func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
