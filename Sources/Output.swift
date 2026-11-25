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

    static func scroll(x: Int32, y: Int32, flags: CGEventFlags = [], phase: Int64 = 0, momentum: Int64 = 0) {
        guard let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                              wheelCount: 2, wheel1: y, wheel2: x, wheel3: 0) else { return }
        e.flags = flags
        e.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        e.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
        e.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentum)
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
    private var glide = Glide()
    private var horizontal = false
    private var flags: CGEventFlags = []
    private var trackpad = true
    private var link: CADisplayLink?
    private var lastFrame: CFTimeInterval?

    func add(x: Double, y: Double, smoothness: Double, flags: CGEventFlags,
             trackpad: Bool, coasts: Bool = true) {
        let sideways = abs(x) > abs(y)
        if sideways != horizontal { post(glide.cancel()) }  // finish the other axis first
        horizontal = sideways
        self.flags = flags
        self.trackpad = trackpad
        post(glide.add(sideways ? x : y, smoothness: smoothness, coasts: coasts))
        if glide.isDone { return stop() }
        if link == nil {
            let mouse = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
            link = screen?.displayLink(target: self, selector: #selector(frame(_:)))
            link?.add(to: .main, forMode: .common)
        }
    }

    func stop() {
        post(glide.cancel())
        link?.invalidate()
        link = nil
        lastFrame = nil
    }

    @objc private func frame(_ link: CADisplayLink) {
        let dt = lastFrame.map { min(link.timestamp - $0, 0.05) } ?? link.duration
        lastFrame = link.timestamp
        post(glide.step(dt: dt))
        if glide.isDone { stop() }
    }

    private func post(_ frames: [ScrollFrame]) {
        for f in frames {
            // Without trackpad simulation the empty phase markers are not needed.
            if !trackpad && f.delta == 0 { continue }
            Output.scroll(x: horizontal ? f.delta : 0, y: horizontal ? 0 : f.delta, flags: flags,
                          phase: trackpad ? f.scroll : 0, momentum: trackpad ? f.momentum : 0)
        }
    }
}
