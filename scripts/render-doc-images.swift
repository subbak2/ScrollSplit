// Renders illustration images for the docs and blog posts: the ScrollSplit menu and the
// System Settings "Natural scrolling" row, drawn with AppKit (system font, SF Symbols).
// Nothing is captured from the screen, so no account names or personal windows can leak in.
// Usage: swift scripts/render-doc-images.swift <out dir> [ko|en|ja]   -> menu.png, settings-natural-scroll.png (2x)
import AppKit

let args = CommandLine.arguments
let outDir = URL(fileURLWithPath: args.count > 1 ? args[1] : ".")
let lang = args.count > 2 ? args[2] : "ko"
func T(_ ko: String, _ en: String, _ ja: String) -> String { lang == "en" ? en : lang == "ja" ? ja : ko }

let scale: CGFloat = 2
NSApplication.shared.appearance = NSAppearance(named: .aqua)

func save(_ size: NSSize, _ name: String, draw: () -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent(name))
}

func text(_ s: String, _ x: CGFloat, _ y: CGFloat, size: CGFloat = 13, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) {
    (s as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
}

func symbol(_ name: String, _ rect: NSRect, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) {
    let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight).applying(.init(paletteColors: [color]))
    guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { return }
    let s = img.size
    img.draw(in: NSRect(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2, width: s.width, height: s.height))
}

// MARK: menu.png — menu bar strip with the icon, and the open menu below it
let menuW: CGFloat = 300, barH: CGFloat = 26
let rows: [(String, String?, Bool, Bool)] = [ // title, trailing, checked, dimmed; "" = separator, "#" prefix = section header
    ("#" + T("자연스러운 스크롤", "Natural Scrolling", "ナチュラルなスクロール"), nil, false, false),
    (T("트랙패드", "Trackpad", "トラックパッド"), nil, true, false),
    (T("마우스", "Mouse", "マウス"), nil, false, false),
    (T("마지막 스크롤: 마우스", "Last scroll: Mouse", "最後のスクロール: マウス"), nil, false, true),
    (T("시스템 설정: 켬", "System setting: on", "システム設定: オン"), nil, false, true),
    ("", nil, false, false),
    (T("일시 정지", "Pause", "一時停止"), nil, false, false),
    (T("로그인 시 실행", "Launch at Login", "ログイン時に起動"), nil, true, false),
    (T("ScrollSplit 정보…", "About ScrollSplit…", "ScrollSplitについて…"), nil, false, false),
    (T("종료", "Quit", "終了"), "⌘Q", false, false),
]
let rowH: CGFloat = 22, sepH: CGFloat = 11, pad: CGFloat = 6
let menuH = pad * 2 + rows.reduce(0) { $0 + ($1.0.isEmpty ? sepH : rowH) }
let canvas = NSSize(width: menuW + 120, height: barH + menuH + 40)
save(canvas, "menu.png") {
    NSColor(calibratedRed: 0.93, green: 0.94, blue: 0.96, alpha: 1).setFill()
    NSRect(origin: .zero, size: canvas).fill()
    // menu bar
    NSColor(white: 0.98, alpha: 1).setFill()
    NSRect(x: 0, y: canvas.height - barH, width: canvas.width, height: barH).fill()
    let iconRect = NSRect(x: 60, y: canvas.height - barH + 2, width: 30, height: barH - 4)
    NSColor(white: 0, alpha: 0.12).setFill()
    NSBezierPath(roundedRect: iconRect, xRadius: 5, yRadius: 5).fill()
    symbol("arrow.up.arrow.down", iconRect, size: 13, weight: .medium)
    symbol("wifi", NSRect(x: 100, y: iconRect.minY, width: 26, height: iconRect.height), size: 13)
    symbol("battery.75percent", NSRect(x: 130, y: iconRect.minY, width: 34, height: iconRect.height), size: 14)
    // menu panel
    let menuRect = NSRect(x: 56, y: canvas.height - barH - 6 - menuH, width: menuW, height: menuH)
    let shadow = NSShadow(); shadow.shadowBlurRadius = 16; shadow.shadowOffset = NSSize(width: 0, height: -4)
    shadow.shadowColor = NSColor(white: 0, alpha: 0.22)
    NSGraphicsContext.saveGraphicsState(); shadow.set()
    NSColor(white: 0.97, alpha: 1).setFill()
    NSBezierPath(roundedRect: menuRect, xRadius: 10, yRadius: 10).fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor(white: 0, alpha: 0.12).setStroke()
    NSBezierPath(roundedRect: menuRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10).stroke()
    var y = menuRect.maxY - pad
    for (title, trailing, checked, dimmed) in rows {
        if title.isEmpty {
            y -= sepH
            NSColor(white: 0, alpha: 0.12).setFill()
            NSRect(x: menuRect.minX + 14, y: y + sepH / 2, width: menuW - 28, height: 1).fill()
            continue
        }
        y -= rowH
        if title.hasPrefix("#") {
            text(String(title.dropFirst()), menuRect.minX + 14, y + 4, size: 11, weight: .semibold, color: .secondaryLabelColor)
            continue
        }
        if checked { symbol("checkmark", NSRect(x: menuRect.minX + 10, y: y, width: 16, height: rowH), size: 11, weight: .semibold) }
        text(title, menuRect.minX + 30, y + 3, color: dimmed ? .tertiaryLabelColor : .labelColor)
        if let trailing { text(trailing, menuRect.maxX - 40, y + 3, color: .secondaryLabelColor) }
    }
}

// MARK: settings-natural-scroll.png — the Natural scrolling row with a real switch
let setW: CGFloat = 560, setH: CGFloat = 150
save(NSSize(width: setW, height: setH), "settings-natural-scroll.png") {
    NSColor(white: 0.955, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: setW, height: setH).fill()
    text(T("스크롤 및 확대/축소", "Scroll & Zoom", "スクロールとズーム"), 24, setH - 36, size: 13, weight: .semibold)
    let group = NSRect(x: 20, y: 20, width: setW - 40, height: setH - 66)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: group, xRadius: 9, yRadius: 9).fill()
    NSColor(white: 0, alpha: 0.08).setStroke()
    NSBezierPath(roundedRect: group.insetBy(dx: 0.5, dy: 0.5), xRadius: 9, yRadius: 9).stroke()
    let rowMid = group.midY
    text(T("자연스러운 스크롤", "Natural scrolling", "ナチュラルなスクロール"), group.minX + 16, rowMid + 1, size: 13)
    text(T("콘텐츠가 손가락의 움직임을 따라갑니다", "Content tracks finger movement", "コンテンツが指の動きに合わせて移動します"),
         group.minX + 16, rowMid - 17, size: 11, color: .secondaryLabelColor)
    // Switch in the "on" state: accent-colored pill with a white knob.
    let pill = NSRect(x: group.maxX - 16 - 38, y: rowMid - 11, width: 38, height: 22)
    NSColor.controlAccentColor.setFill()
    NSBezierPath(roundedRect: pill, xRadius: 11, yRadius: 11).fill()
    let knobShadow = NSShadow(); knobShadow.shadowBlurRadius = 2; knobShadow.shadowOffset = NSSize(width: 0, height: -1)
    knobShadow.shadowColor = NSColor(white: 0, alpha: 0.25)
    NSGraphicsContext.saveGraphicsState(); knobShadow.set()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: pill.maxX - 21, y: pill.minY + 1, width: 20, height: 20)).fill()
    NSGraphicsContext.restoreGraphicsState()
}
print("wrote menu.png and settings-natural-scroll.png to \(outDir.path)")
