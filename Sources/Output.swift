import AppKit

/// Marks events this app posts so the tap ignores them.
let syntheticMarker: Int64 = 0x4D4B_5531

enum Output {
    static func key(_ code: CGKeyCode, _ flags: CGEventFlags = []) {
        for isDown in [true, false] {
            guard let e = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: isDown) else { continue }
            e.flags = flags
            e.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
            e.post(tap: .cghidEventTap)
        }
    }

    static func click(button: Int) {
        guard let at = CGEvent(source: nil)?.location,
              let mouseButton = CGMouseButton(rawValue: UInt32(button)) else { return }
        for type in [CGEventType.otherMouseDown, .otherMouseUp] {
            guard let e = CGEvent(mouseEventSource: nil, mouseType: type,
                                  mouseCursorPosition: at, mouseButton: mouseButton) else { continue }
            e.setIntegerValueField(.mouseEventButtonNumber, value: Int64(button))
            e.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
            e.post(tap: .cghidEventTap)
        }
    }

    static func scroll(x: Int32, y: Int32, flags: CGEventFlags = []) {
        guard let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                              wheelCount: 2, wheel1: y, wheel2: x, wheel3: 0) else { return }
        e.flags = flags
        e.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        e.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
        e.post(tap: .cghidEventTap)
    }

    static func zoom(_ direction: Int) {
        key(direction > 0 ? 24 : 27, .maskCommand)  // Cmd+= / Cmd+-
    }

    private static func dock(_ name: String) {
        typealias Fn = @convention(c) (CFString, Int32) -> Void
        guard let handle = dlopen(nil, RTLD_NOW),
              let symbol = dlsym(handle, "CoreDockSendNotification") else { return }
        unsafeBitCast(symbol, to: Fn.self)(name as CFString, 0)
    }

    static func perform(_ binding: Binding) {
        let arrows: CGEventFlags = [.maskControl, .maskSecondaryFn, .maskNumericPad]
        switch binding.action {
        case .none: break
        case .middleClick: click(button: 2)
        case .back: key(33, .maskCommand)
        case .forward: key(30, .maskCommand)
        case .missionControl: dock("com.apple.expose.awake")
        case .appExpose: dock("com.apple.expose.front.awake")
        case .showDesktop: dock("com.apple.showdesktop.awake")
        case .spaceLeft: key(123, arrows)
        case .spaceRight: key(124, arrows)
        case .spotlight: key(49, .maskCommand)
        case .copy: key(8, .maskCommand)
        case .paste: key(9, .maskCommand)
        case .closeTab: key(13, .maskCommand)
        case .newTab: key(17, .maskCommand)
        case .shortcut:
            if let s = binding.shortcut { key(s.keyCode, CGEventFlags(rawValue: s.flags)) }
        }
    }
}

/// Replaces stepped wheel ticks with one pixel scroll per display refresh.
final class SmoothScroller: NSObject {
    private var x = Glide(), y = Glide()
    private var flags: CGEventFlags = []
    private var link: CADisplayLink?
    private var lastFrame: CFTimeInterval?
    private var stiffness = 14.0

    func add(x dx: Double, y dy: Double, smoothness: Double, flags: CGEventFlags) {
        x.add(dx)
        y.add(dy)
        self.flags = flags
        stiffness = 28 - 18 * min(max(smoothness, 0), 1)
        if link == nil {
            let mouse = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
            link = screen?.displayLink(target: self, selector: #selector(frame(_:)))
            link?.add(to: .main, forMode: .common)
        }
    }

    func stop() {
        link?.invalidate()
        link = nil
        lastFrame = nil
        x = Glide()
        y = Glide()
    }

    @objc private func frame(_ link: CADisplayLink) {
        let dt = lastFrame.map { min(link.timestamp - $0, 0.05) } ?? link.duration
        lastFrame = link.timestamp
        let px = x.step(dt: dt, stiffness: stiffness)
        let py = y.step(dt: dt, stiffness: stiffness)
        if px != 0 || py != 0 { Output.scroll(x: px, y: py, flags: flags) }
        if x.isDone && y.isDone { stop() }
    }
}
