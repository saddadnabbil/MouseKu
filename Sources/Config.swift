import Foundation

enum Action: String, Codable, CaseIterable, Identifiable {
    case none, middleClick, back, forward, missionControl, appExpose, showDesktop,
         spaceLeft, spaceRight, spotlight, copy, paste, closeTab, newTab, shortcut
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "—"
        case .middleClick: return "Middle Click"
        case .back: return "Back"
        case .forward: return "Forward"
        case .missionControl: return "Mission Control"
        case .appExpose: return "App Exposé"
        case .showDesktop: return "Show Desktop"
        case .spaceLeft: return "Space Left"
        case .spaceRight: return "Space Right"
        case .spotlight: return "Spotlight"
        case .copy: return "Copy"
        case .paste: return "Paste"
        case .closeTab: return "Close Tab"
        case .newTab: return "New Tab"
        case .shortcut: return "Custom Shortcut…"
        }
    }
}

enum DragMode: String, Codable, CaseIterable, Identifiable {
    case none, spaces, scroll
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "—"
        case .spaces: return "Spaces & Mission Control"
        case .scroll: return "Scroll & Navigate"
        }
    }
}

enum WheelMode: String, Codable, CaseIterable, Identifiable {
    case none, zoom, horizontal, spaces, fast, desktop
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "—"
        case .zoom: return "Zoom"
        case .horizontal: return "Horizontal Scroll"
        case .spaces: return "Switch Space"
        case .fast: return "Fast Scroll"
        case .desktop: return "Show Desktop"
        }
    }
}

struct Shortcut: Codable, Equatable {
    var keyCode: UInt16
    var flags: UInt64
    var label: String
}

struct Binding: Codable, Equatable {
    var action: Action = .none
    var shortcut: Shortcut? = nil
}

struct ButtonConfig: Codable, Equatable {
    var click = Binding()
    var doubleClick = Binding()
    var hold = Binding()
    var drag: DragMode = .none
    var wheel: WheelMode = .none

    var isEmpty: Bool {
        click.action == .none && doubleClick.action == .none && hold.action == .none
            && drag == .none && wheel == .none
    }
}

struct Config: Codable, Equatable {
    var enabled = false
    // Keys are CGEvent button numbers: 2 = middle, 3 = button 4, 4 = button 5.
    var buttons: [Int: ButtonConfig] = [
        3: ButtonConfig(click: Binding(action: .back), drag: .spaces, wheel: .desktop),
        4: ButtonConfig(click: Binding(action: .forward), drag: .scroll, wheel: .zoom),
    ]
    var smooth = true
    var reverse = true     // mouse only; the trackpad keeps the system direction
    var speed = 1.0        // distance multiplier
    var smoothness = 0.8   // 0 = snappy, 1 = long glide
    var shiftHorizontal = true
    var commandZoom = true
    var optionPrecise = true
    var controlFast = true
    var trackpadSimulation = true

    /// Reads saved settings, keeping the defaults for options added after they were saved.
    static func load(_ data: Data?) -> Config {
        guard let data,
              let saved = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let base = try? JSONEncoder().encode(Config()),
              var merged = try? JSONSerialization.jsonObject(with: base) as? [String: Any]
        else { return Config() }
        merged.merge(saved) { _, new in new }
        guard let json = try? JSONSerialization.data(withJSONObject: merged),
              let config = try? JSONDecoder().decode(Config.self, from: json) else { return Config() }
        return config
    }
}
