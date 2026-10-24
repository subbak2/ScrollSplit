import AppKit

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
    var isEnabled = true
    private(set) var lastDevice: ScrollDevice?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    init() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("SwipeScrollDirectionDidChangeNotification"), object: nil, queue: .main
        ) { [weak self] _ in self?.refreshSystemSetting() }
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
        ) else { return false }
        tap = port
        source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    func refreshSystemSetting() {
        systemNatural = ScrollTap.readSystemNatural()
    }

    private static func readSystemNatural() -> Bool {
        // Missing key means the macOS default, which is natural scrolling on.
        UserDefaults(suiteName: UserDefaults.globalDomain)?.object(forKey: "com.apple.swipescrolldirection") as? Bool ?? true
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
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .scrollWheel, isEnabled else { return Unmanaged.passUnretained(event) }
        let device = ScrollTap.device(of: event)
        lastDevice = device
        if wantsNatural[device, default: systemNatural] != systemNatural {
            ScrollTap.reverse(event)
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
