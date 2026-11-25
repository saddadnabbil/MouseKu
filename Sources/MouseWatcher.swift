import Foundation
import IOKit.hid

/// The system "Natural scrolling" switch (shared by mouse and trackpad).
enum NaturalScrolling {
    private static let handle = dlopen(
        "/System/Library/PrivateFrameworks/PreferencePanesSupport.framework/PreferencePanesSupport", RTLD_NOW)
    private typealias Get = @convention(c) () -> Bool
    private typealias Set = @convention(c) (Bool) -> Void

    static var isOn: Bool? {
        guard let handle, let s = dlsym(handle, "swipeScrollDirection") else { return nil }
        return unsafeBitCast(s, to: Get.self)()
    }

    static func set(_ on: Bool) {
        guard let handle, let s = dlsym(handle, "setSwipeScrollDirection") else { return }
        unsafeBitCast(s, to: Set.self)(on)
        // Persist it and tell System Settings and running apps.
        CFPreferencesSetValue("com.apple.swipescrolldirection" as CFString, on as CFBoolean,
                              kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("SwipeScrollDirectionDidChangeNotification"), object: nil,
            userInfo: nil, deliverImmediately: true)
    }
}

/// Turns natural scrolling off while an external mouse is connected, then restores it.
final class MouseWatcher: ObservableObject {
    @Published private(set) var mice: [String] = []
    @Published var autoDisableNatural: Bool {
        didSet {
            UserDefaults.standard.set(autoDisableNatural, forKey: "autoDisableNatural")
            update()
        }
    }

    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
    private var devices: [IOHIDDevice: String] = [:]
    private var ready = false
    private let savedKey = "naturalBeforeMouse"  // set only while we override the system value

    init() {
        autoDisableNatural = UserDefaults.standard.object(forKey: "autoDisableNatural") as? Bool ?? true
    }

    func start() {
        let match = [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse]
        IOHIDManagerSetDeviceMatching(manager, match as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            Unmanaged<MouseWatcher>.fromOpaque(context!).takeUnretainedValue().added(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            Unmanaged<MouseWatcher>.fromOpaque(context!).takeUnretainedValue().removed(device)
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        // Let the initial enumeration finish before deciding there is no mouse.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.ready = true
            self.update()
        }
    }

    /// Puts the user's own setting back.
    func restore() {
        guard let previous = UserDefaults.standard.object(forKey: savedKey) as? Bool else { return }
        NaturalScrolling.set(previous)
        UserDefaults.standard.removeObject(forKey: savedKey)
    }

    private func added(_ device: IOHIDDevice) {
        func property(_ key: String) -> Any? { IOHIDDeviceGetProperty(device, key as CFString) }
        let transport = property(kIOHIDTransportKey) as? String ?? ""
        let vendor = property(kIOHIDVendorIDKey) as? Int ?? 0
        // Skip the built-in trackpad, virtual devices and Apple's Magic Mouse / Trackpad.
        guard transport == "USB" || transport.hasPrefix("Bluetooth"),
              vendor != 0x05AC, vendor != 0x004C else { return }
        devices[device] = property(kIOHIDProductKey) as? String ?? "Mouse"
        changed()
    }

    private func removed(_ device: IOHIDDevice) {
        if devices.removeValue(forKey: device) != nil { changed() }
    }

    private func changed() {
        mice = devices.values.sorted()
        update()
    }

    private func update() {
        if autoDisableNatural && !devices.isEmpty {
            guard let current = NaturalScrolling.isOn else { return }
            if UserDefaults.standard.object(forKey: savedKey) == nil {
                UserDefaults.standard.set(current, forKey: savedKey)
            }
            if current { NaturalScrolling.set(false) }
        } else if ready || !autoDisableNatural {
            restore()
        }
    }
}
