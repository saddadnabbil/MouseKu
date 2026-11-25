import Foundation

/// Turns raw button down/up/move/wheel input into actions. No system APIs, so it is testable.
final class ButtonEngine {
    var config: () -> [Int: ButtonConfig] = { [:] }
    var perform: (Binding) -> Void = { _ in }
    var replayClick: (Int) -> Void = { _ in }
    var dragScroll: (Double, Double) -> Void = { _, _ in }
    var wheelAction: (WheelMode, Int) -> Void = { _, _ in }
    /// Runs a block after a delay and returns a cancel closure.
    var schedule: (TimeInterval, @escaping () -> Void) -> () -> Void = { delay, block in
        let item = DispatchWorkItem(block: block)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return { item.cancel() }
    }

    static let holdDelay = 0.3
    static let doubleClickDelay = 0.25
    static let dragStart = 6.0
    static let swipeDistance = 80.0

    private final class Press {
        let config: ButtonConfig
        var consumed = false      // hold, drag or wheel already used this press
        var dragging = false
        var swiped = false
        var isSecond = false
        var dx = 0.0, dy = 0.0
        var cancelHold: () -> Void = {}
        init(_ config: ButtonConfig) { self.config = config }
    }

    private var presses: [Int: Press] = [:]
    private var pendingClick: [Int: () -> Void] = [:]  // cancel closures

    /// Returns true if the event must be swallowed.
    func down(_ button: Int) -> Bool {
        guard let cfg = config()[button], !cfg.isEmpty else { return false }
        let press = Press(cfg)
        if let cancel = pendingClick.removeValue(forKey: button) {
            cancel()
            press.isSecond = true
        }
        presses[button] = press
        if cfg.hold.action != .none {
            press.cancelHold = schedule(Self.holdDelay) { [weak self, weak press] in
                guard let self, let press, !press.consumed else { return }
                press.consumed = true
                self.perform(press.config.hold)
            }
        }
        return true
    }

    func up(_ button: Int) -> Bool {
        guard let press = presses.removeValue(forKey: button) else { return false }
        press.cancelHold()
        if press.consumed { return true }
        let cfg = press.config
        if press.isSecond {
            perform(cfg.doubleClick)
        } else if cfg.doubleClick.action != .none {
            pendingClick[button] = schedule(Self.doubleClickDelay) { [weak self] in
                self?.pendingClick[button] = nil
                self?.click(button, cfg)
            }
        } else {
            click(button, cfg)
        }
        return true
    }

    private func click(_ button: Int, _ cfg: ButtonConfig) {
        if cfg.click.action == .none { replayClick(button) } else { perform(cfg.click) }
    }

    func moved(dx: Double, dy: Double) {
        for press in presses.values where press.config.drag != .none {
            press.dx += dx
            press.dy += dy
            if !press.dragging {
                guard !press.consumed, hypot(press.dx, press.dy) >= Self.dragStart else { continue }
                press.dragging = true
                press.consumed = true
                press.cancelHold()
            }
            switch press.config.drag {
            case .scroll:
                dragScroll(dx, dy)
            case .spaces:
                guard !press.swiped, max(abs(press.dx), abs(press.dy)) >= Self.swipeDistance else { continue }
                press.swiped = true
                let action: Action
                if abs(press.dx) > abs(press.dy) {
                    // Content follows the hand, like a three finger swipe.
                    action = press.dx > 0 ? .spaceLeft : .spaceRight
                } else {
                    action = press.dy < 0 ? .missionControl : .appExpose
                }
                perform(Binding(action: action))
            case .none:
                break
            }
        }
    }

    /// direction is +1 or -1. Returns true if a held button claimed the wheel tick.
    func wheel(_ direction: Int) -> Bool {
        for press in presses.values where press.config.wheel != .none {
            press.consumed = true
            press.cancelHold()
            wheelAction(press.config.wheel, direction)
            return true
        }
        return false
    }

    func reset() {
        presses.values.forEach { $0.cancelHold() }
        presses.removeAll()
        pendingClick.values.forEach { $0() }
        pendingClick.removeAll()
    }
}
