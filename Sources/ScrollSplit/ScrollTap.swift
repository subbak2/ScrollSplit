import AppKit
import os

/// Diagnostics in the unified log (not written to disk unless streamed). Per-event lines only with
/// `defaults write io.github.subbak2.ScrollSplit debug -bool true`; view with
/// `log stream --level debug --predicate 'subsystem == "io.github.subbak2.ScrollSplit"'`.
let log = Logger(subsystem: "io.github.subbak2.ScrollSplit", category: "tap")

enum ScrollDevice: String {
    case trackpad, mouse
}

/// Flips scroll direction per device with a session event tap that sees only scroll-wheel events.
/// No timers and no polling: the callback runs only while something scrolls, so an idle Mac costs nothing.
final class ScrollTap {
    /// Whether each device should scroll "naturally" (content follows the fingers).
    var wantsNatural: [ScrollDevice: Bool] = [.trackpad: true, .mouse: false]
    /// macOS "Natural scrolling" (one switch for every device). Events reaching the tap already follow it.
    private(set) var systemNatural = ScrollTap.readSystemNatural()
    /// Paused means the tap is switched off entirely, so scroll events don't pass through this app at all.
    var isEnabled = true {
        didSet { if let tap { CGEvent.tapEnable(tap: tap, enable: isEnabled) } }
    }
    var debug = UserDefaults.standard.bool(forKey: "debug")
    private(set) var lastDevice: ScrollDevice?
    private var lastSettingRead = Date()
    private var loggedWaiting = false
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    /// The tap exists, i.e. Accessibility access was granted.
    var isRunning: Bool { tap != nil }

    init() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("SwipeScrollDirectionDidChangeNotification"), object: nil, queue: .main
        ) { [weak self] _ in self?.refreshSystemSetting() }
        // Posted when the Accessibility list changes. If our access was taken away, drop the tap
        // right away instead of leaving an active tap without permission.
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.stopIfUntrusted() }
        }
    }

    /// Callback for when the tap was removed because permission went away.
    var onPermissionLost: (() -> Void)?

    func stop() {
        guard let port = tap else { return }
        CGEvent.tapEnable(tap: port, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(port)
        tap = nil
        source = nil
    }

    func stopIfUntrusted() {
        guard tap != nil, !AXIsProcessTrusted() else { return }
        log.notice("Accessibility access removed, tap stopped")
        stop()
        onPermissionLost?()
    }

    /// Creates the tap. Returns false while Accessibility permission is missing.
    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                let me = Unmanaged<ScrollTap>.fromOpaque(userInfo!).takeUnretainedValue()
                return me.handle(type, event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            if !loggedWaiting { log.notice("tap not created, AXIsProcessTrusted=\(AXIsProcessTrusted())") }
            loggedWaiting = true
            return false
        }
        loggedWaiting = false
        log.notice("tap created, systemNatural=\(self.systemNatural)")
        tap = port
        source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: isEnabled)
        return true
    }

    func refreshSystemSetting() {
        systemNatural = ScrollTap.readSystemNatural()
        lastSettingRead = Date()
    }

    /// Turns the tap back on if macOS switched it off (sleep, timeouts).
    func reenable() {
        if let tap, isEnabled, !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    private static func readSystemNatural() -> Bool {
        // UserDefaults(suiteName: NSGlobalDomain) is nil, so read the global domain through CFPreferences.
        // Missing key means the macOS default, which is natural scrolling on.
        let key = "com.apple.swipescrolldirection" as CFString
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        return CFPreferencesCopyAppValue(key, kCFPreferencesAnyApplication) as? Bool ?? true
    }

    /// Trackpads (and Magic Mouse) send scroll and momentum phases; wheel mice send neither.
    static func device(of event: CGEvent) -> ScrollDevice {
        let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        return phase != 0 || momentum != 0 ? .trackpad : .mouse
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // macOS turns a slow tap off; turn it back on.
            log.notice("tap disabled by macOS (\(type.rawValue)), re-enabling")
            if let tap, isEnabled { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .scrollWheel, isEnabled else { return Unmanaged.passUnretained(event) }
        // Backup for the change notification, in case a macOS update renames it. Reading preferences
        // talks to cfprefsd, so do it after this event is handed back, never inside the callback.
        if Date().timeIntervalSince(lastSettingRead) > 5 {
            lastSettingRead = Date()
            DispatchQueue.main.async { [weak self] in
                self?.refreshSystemSetting()
                self?.stopIfUntrusted() // backup for the undocumented permission notification
            }
        }
        let device = ScrollTap.device(of: event)
        lastDevice = device
        let flip = wantsNatural[device, default: systemNatural] != systemNatural
        if flip { ScrollTap.reverse(event) }
        if debug {
            log.debug("\(device.rawValue) phase=\(event.getIntegerValueField(.scrollWheelEventScrollPhase)) momentum=\(event.getIntegerValueField(.scrollWheelEventMomentumPhase)) continuous=\(event.getIntegerValueField(.scrollWheelEventIsContinuous)) systemNatural=\(self.systemNatural) flip=\(flip)")
        }
        return Unmanaged.passUnretained(event)
    }

    /// Negates both axes in all three representations apps read (line, fixed-point, pixel).
    static func reverse(_ event: CGEvent) {
        let line1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let line2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let fixed1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let fixed2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        let point1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let point2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -line1)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -line2)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixed1)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -fixed2)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -point1)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -point2)
    }
}
