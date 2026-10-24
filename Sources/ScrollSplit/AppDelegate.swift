import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let tap = ScrollTap()
    /// Runs only while Accessibility permission is missing, then stops.
    private var permissionTimer: Timer?
    private let defaults = UserDefaults.standard
    private let repoURL = URL(string: "https://github.com/subbak2/ScrollSplit")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["natural.trackpad": true, "natural.mouse": false, "enabled": true])
        for device in [ScrollDevice.trackpad, .mouse] {
            tap.wantsNatural[device] = defaults.bool(forKey: "natural.\(device.rawValue)")
        }
        tap.isEnabled = defaults.bool(forKey: "enabled")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.tap.stopIfUntrusted()
            self?.tap.reenable()
        }

        tap.onPermissionLost = { [weak self] in
            self?.updateIcon()
            self?.waitForPermission()
        }

        // Escape hatch: holding Shift at launch starts without the tap (menu › Pause is on).
        if NSEvent.modifierFlags.contains(.shift) {
            tap.isEnabled = false
            defaults.set(false, forKey: "enabled")
        }

        if !tap.start() {
            // Shows the system prompt once; after that the menu item opens System Settings.
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            waitForPermission()
        }
    }

    private func waitForPermission() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard let self, self.tap.start() else { return }
            timer.invalidate()
            self.permissionTimer = nil
            self.updateIcon()
        }
    }

    private func updateIcon() {
        let symbol = tap.isRunning && tap.isEnabled ? "arrow.up.arrow.down" : "arrow.up.arrow.down.circle"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "ScrollSplit")
        statusItem.button?.appearsDisabled = !(tap.isRunning && tap.isEnabled)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        tap.refreshSystemSetting()

        if !tap.isRunning {
            let grant = NSMenuItem(title: L("Allow Accessibility Access…", "손쉬운 사용 권한 허용…"),
                                   action: #selector(openAccessibilitySettings), keyEquivalent: "")
            grant.target = self
            grant.toolTip = L("macOS lets an app change scroll direction only with Accessibility access.",
                              "macOS는 손쉬운 사용 권한이 있는 앱만 스크롤 방향을 바꿀 수 있게 합니다.")
            menu.addItem(grant)
            menu.addItem(.separator())
        }

        menu.addItem(sectionHeader(L("Natural Scrolling", "자연스러운 스크롤")))
        for (device, title) in [(ScrollDevice.trackpad, L("Trackpad", "트랙패드")), (.mouse, L("Mouse", "마우스"))] {
            let item = NSMenuItem(title: title, action: #selector(toggleNatural(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = device.rawValue
            item.state = tap.wantsNatural[device] == true ? .on : .off
            item.isEnabled = tap.isEnabled
            item.indentationLevel = 1
            menu.addItem(item)
        }
        // Read-only lines to check that the device and the system setting are recognized.
        var info = [tap.systemNatural ? L("System setting: on", "시스템 설정: 켬") : L("System setting: off", "시스템 설정: 끔")]
        if let last = tap.lastDevice {
            let name = last == .trackpad ? L("Trackpad", "트랙패드") : L("Mouse", "마우스")
            info.insert(L("Last scroll: \(name)", "마지막 스크롤: \(name)"), at: 0)
        }
        for title in info {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.indentationLevel = 1
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let pause = NSMenuItem(title: L("Pause", "일시 정지"), action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        pause.state = tap.isEnabled ? .off : .on
        pause.toolTip = L("Every device follows the system setting while paused.",
                          "정지하면 모든 기기가 시스템 설정을 따릅니다.")
        menu.addItem(pause)
        let login = NSMenuItem(title: L("Launch at Login", "로그인 시 실행"), action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        let about = NSMenuItem(title: L("About ScrollSplit…", "ScrollSplit 정보…"), action: #selector(openRepo), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(NSMenuItem(title: L("Quit", "종료"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func sectionHeader(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) { return .sectionHeader(title: title) }
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func toggleNatural(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let device = ScrollDevice(rawValue: raw) else { return }
        let value = !(tap.wantsNatural[device] ?? false)
        tap.wantsNatural[device] = value
        defaults.set(value, forKey: "natural.\(raw)")
    }

    @objc private func togglePause() {
        tap.isEnabled.toggle()
        defaults.set(tap.isEnabled, forKey: "enabled")
        updateIcon()
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        if permissionTimer == nil { waitForPermission() }
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc private func openRepo() {
        NSWorkspace.shared.open(repoURL)
    }
}
