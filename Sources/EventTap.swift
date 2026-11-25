import AppKit

final class EventTap {
    private let store: Store
    private let engine = ButtonEngine()
    private let scroller = SmoothScroller()
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var lastTick = 0.0
    private var acceleration = 1.0
    private var lastDesktopToggle = 0.0

    var isRunning: Bool { tap != nil }

    init(store: Store) {
        self.store = store
        engine.config = { [unowned store] in store.config.buttons }
        engine.perform = { Output.perform($0) }
        engine.replayClick = { Output.click(button: $0) }
        engine.dragScroll = { dx, dy in Output.scroll(x: Int32(dx * 2), y: Int32(dy * 2)) }
        engine.wheelAction = { [unowned self] mode, direction in self.heldWheel(mode, direction) }
    }

    func start() -> Bool {
        if tap != nil { return true }
        let types: [CGEventType] = [.otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, info in
            let me = Unmanaged<EventTap>.fromOpaque(info!).takeUnretainedValue()
            return me.handle(type, event) ? nil : Unmanaged.passUnretained(event)
        }
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        tap = port
        source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    func stop() {
        engine.reset()
        scroller.stop()
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
    }

    /// Returns true to swallow the event.
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            engine.reset()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        if event.getIntegerValueField(.eventSourceUserData) == syntheticMarker { return false }
        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        switch type {
        case .otherMouseDown: return engine.down(button)
        case .otherMouseUp: return engine.up(button)
        case .otherMouseDragged:
            engine.moved(dx: Double(event.getIntegerValueField(.mouseEventDeltaX)),
                         dy: Double(event.getIntegerValueField(.mouseEventDeltaY)))
            return false
        case .scrollWheel: return handleScroll(event)
        default: return false
        }
    }

    private func handleScroll(_ event: CGEvent) -> Bool {
        // Trackpads and Magic Mouse send continuous events; leave them alone.
        if event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 { return false }
        let rawY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let rawX = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        if rawX == 0 && rawY == 0 { return false }
        if engine.wheel((rawY != 0 ? rawY : rawX) > 0 ? 1 : -1) { return true }

        let c = store.config
        var flags = event.flags
        var x = Double(rawX.signum()), y = Double(rawY.signum())
        if c.reverse { x = -x; y = -y }

        if c.commandZoom && flags.contains(.maskCommand) {
            Output.zoom(y > 0 ? 1 : -1)
            return true
        }
        if c.shiftHorizontal && flags.contains(.maskShift) {
            if y != 0 { x = y; y = 0 }
            flags.remove(.maskShift)
        }
        var distance = 50.0 * min(max(c.speed, 0.3), 3)  // stored value is untrusted
        var coasts = true
        if c.optionPrecise && flags.contains(.maskAlternate) {
            distance = 10
            flags.remove(.maskAlternate)
            acceleration = 1
            coasts = false
        } else {
            let now = ProcessInfo.processInfo.systemUptime
            acceleration = now - lastTick < 0.08 ? min(acceleration + 0.25, 3.5) : 1
            lastTick = now
            distance *= acceleration
        }

        if c.controlFast && flags.contains(.maskControl) {
            distance *= 4
            flags.remove(.maskControl)
        }

        if c.smooth {
            scroller.add(x: x * distance, y: y * distance, smoothness: c.smoothness, flags: flags,
                         trackpad: c.trackpadSimulation, coasts: coasts)
        } else {
            Output.scroll(x: Int32(x * distance), y: Int32(y * distance), flags: flags)
        }
        return true
    }

    private func heldWheel(_ mode: WheelMode, _ direction: Int) {
        let d = Double(store.config.reverse ? -direction : direction)
        switch mode {
        case .none: break
        case .zoom: Output.zoom(Int(d))
        case .horizontal: scroller.add(x: d * 60, y: 0, smoothness: 0.5, flags: [], trackpad: false)
        case .fast: scroller.add(x: 0, y: d * 300, smoothness: 0.5, flags: [], trackpad: false)
        case .desktop:
            // One toggle per scroll gesture, not one per wheel tick.
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastDesktopToggle > 0.6 { Output.perform(Binding(action: .showDesktop)) }
            lastDesktopToggle = now
        case .spaces: Output.perform(Binding(action: d > 0 ? .spaceLeft : .spaceRight))
        }
    }
}
