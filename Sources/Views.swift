import SwiftUI

struct RootView: View {
    @ObservedObject var store: Store

    var body: some View {
        TabView {
            GeneralView(store: store).tabItem { Label("General", systemImage: "gearshape") }
            ButtonsView(store: store).tabItem { Label("Buttons", systemImage: "computermouse") }
                .disabled(!store.config.enabled)
            ScrollingView(store: store).tabItem { Label("Scrolling", systemImage: "arrow.up.arrow.down") }
                .disabled(!store.config.enabled)
            AboutView().tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 520)
        .padding(.top, 8)
    }
}

struct GeneralView: View {
    @ObservedObject var store: Store

    var body: some View {
        Form {
            Toggle("Enable MouseKu", isOn: $store.config.enabled).font(.headline)
            if store.needsPermission {
                Text("MouseKu needs Accessibility permission to read your mouse.")
                    .foregroundColor(.orange)
                Button("Open Accessibility Settings") { store.requestPermission() }
            }
            Toggle("Launch at login", isOn: SwiftUI.Binding(
                get: { store.launchAtLogin }, set: { store.setLaunchAtLogin($0) }))
            if let error = store.errorText { Text(error).foregroundColor(.red) }
        }
        .toggleStyle(.switch)
        .formStyle(.grouped)
    }
}

struct ButtonsView: View {
    @ObservedObject var store: Store

    var body: some View {
        Form {
            ForEach(2...6, id: \.self) { number in
                Section(number == 2 ? "Middle Button" : "Button \(number + 1)") {
                    row("Click", number, \.click)
                    row("Double click", number, \.doubleClick)
                    row("Hold", number, \.hold)
                    Picker("Click and drag", selection: binding(number, \.drag)) {
                        ForEach(DragMode.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Click and scroll", selection: binding(number, \.wheel)) {
                        ForEach(WheelMode.allCases) { Text($0.title).tag($0) }
                    }
                }
            }
            Button("Restore defaults") { store.config.buttons = Config().buttons }
        }
        .formStyle(.grouped)
    }

    private func binding<T>(_ number: Int, _ path: WritableKeyPath<ButtonConfig, T>) -> SwiftUI.Binding<T> {
        SwiftUI.Binding(
            get: { (store.config.buttons[number] ?? ButtonConfig())[keyPath: path] },
            set: { value in
                var button = store.config.buttons[number] ?? ButtonConfig()
                button[keyPath: path] = value
                store.config.buttons[number] = button
            })
    }

    @ViewBuilder
    private func row(_ title: String, _ number: Int, _ path: WritableKeyPath<ButtonConfig, Binding>) -> some View {
        let value = binding(number, path)
        Picker(title, selection: value.action) {
            ForEach(Action.allCases) { Text($0.title).tag($0) }
        }
        if value.wrappedValue.action == .shortcut {
            LabeledContent("↳ Keys") {
                Button(value.wrappedValue.shortcut?.label ?? "Click, then press keys…") {
                    ShortcutRecorder.record { value.wrappedValue.shortcut = $0 }
                }
            }
        }
    }
}

enum ShortcutRecorder {
    private static var monitor: Any?

    /// Captures the next key press in this app. Esc cancels.
    static func record(_ done: @escaping (Shortcut) -> Void) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            stop()
            if event.keyCode == 53 { return nil }
            var flags: CGEventFlags = []
            var label = ""
            let mods = event.modifierFlags
            if mods.contains(.control) { flags.insert(.maskControl); label += "⌃" }
            if mods.contains(.option) { flags.insert(.maskAlternate); label += "⌥" }
            if mods.contains(.shift) { flags.insert(.maskShift); label += "⇧" }
            if mods.contains(.command) { flags.insert(.maskCommand); label += "⌘" }
            if mods.contains(.function) { flags.insert(.maskSecondaryFn) }
            if mods.contains(.numericPad) { flags.insert(.maskNumericPad) }
            let names: [UInt16: String] = [36: "↩", 48: "⇥", 49: "Space", 51: "⌫",
                                           123: "←", 124: "→", 125: "↓", 126: "↑"]
            label += names[event.keyCode]
                ?? event.charactersIgnoringModifiers?.uppercased()
                ?? "key \(event.keyCode)"
            done(Shortcut(keyCode: event.keyCode, flags: flags.rawValue, label: label))
            return nil
        }
    }

    private static func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

struct ScrollingView: View {
    @ObservedObject var store: Store

    var body: some View {
        Form {
            Section("Movement") {
                Toggle("Smooth scrolling", isOn: $store.config.smooth)
                Slider(value: $store.config.smoothness, in: 0...1) { Text("Smoothness") }
                    .disabled(!store.config.smooth)
                Slider(value: $store.config.speed, in: 0.3...3) { Text("Speed") }
                Toggle("Trackpad simulation (momentum and bounce)", isOn: $store.config.trackpadSimulation)
                    .disabled(!store.config.smooth)
                Toggle("Reverse scroll direction", isOn: $store.config.reverse)
            }
            Section("Keyboard modifier + scroll") {
                Toggle("⇧ Shift: horizontal scroll", isOn: $store.config.shiftHorizontal)
                Toggle("⌘ Command: zoom", isOn: $store.config.commandZoom)
                Toggle("⌥ Option: precise scroll", isOn: $store.config.optionPrecise)
                Toggle("⌃ Control: fast scroll", isOn: $store.config.controlFast)
            }
        }
        .toggleStyle(.switch)
        .formStyle(.grouped)
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "computermouse").font(.system(size: 48))
            Text("MouseKu").font(.title2.bold())
            Text("A small mouse utility for macOS. Version 1.0")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
