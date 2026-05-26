import AppKit
import Carbon

@MainActor
final class ShortcutRecorderControl: NSControl {
    var shortcut: KeyboardShortcut {
        didSet {
            needsDisplay = true
        }
    }

    var onShortcutChange: ((KeyboardShortcut) -> Void)?
    var onMessage: ((String) -> Void)?

    private var isRecording = false {
        didSet {
            needsDisplay = true
        }
    }

    init(shortcut: KeyboardShortcut) {
        self.shortcut = shortcut
        super.init(frame: .zero)
        focusRingType = .default
        toolTip = "クリックして、使いたいキーの組み合わせを押してください。"
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override var canBecomeKeyView: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 54)
    }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        beginRecording()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            beginRecording()
            return
        }

        if UInt32(event.keyCode) == UInt32(kVK_Escape) {
            isRecording = false
            onMessage?("変更をキャンセルしました。")
            return
        }

        guard let key = KeyboardShortcut.key(forCarbonKeyCode: UInt32(event.keyCode)) else {
            NSSound.beep()
            onMessage?("このキーは使えません。英数字、Space、Tab、Return を使ってください。")
            return
        }

        let modifiers = shortcutModifiers(from: event.modifierFlags)
        guard KeyboardShortcut.hasActivationModifier(modifiers) else {
            NSSound.beep()
            onMessage?("⌘、⌥、⌃ のいずれかとキーを一緒に押してください。")
            return
        }

        let nextShortcut = KeyboardShortcut(key: key, modifiers: modifiers)
        shortcut = nextShortcut
        isRecording = false
        onShortcutChange?(nextShortcut)
        onMessage?("保存すると \(nextShortcut.displayName) が有効になります。")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = bounds.insetBy(dx: 1, dy: 1)
        let radius: CGFloat = 8
        let path = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)

        let isFocused = window?.firstResponder === self
        let borderColor: NSColor = isRecording
            ? .controlAccentColor
            : (isFocused ? .keyboardFocusIndicatorColor : .separatorColor)
        let fillColor: NSColor = isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.08)
            : NSColor.controlBackgroundColor

        fillColor.setFill()
        path.fill()

        borderColor.setStroke()
        path.lineWidth = isRecording ? 2 : 1
        path.stroke()

        let title = isRecording ? "キーを押してください" : shortcut.displayName
        let subtitle = isRecording ? "Esc でキャンセル" : "クリックして変更"

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: isRecording ? 16 : 18, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        let subtitleString = NSAttributedString(string: subtitle, attributes: subtitleAttributes)
        let totalHeight = titleString.size().height + 3 + subtitleString.size().height
        let titleOrigin = NSPoint(
            x: bounds.midX - titleString.size().width / 2,
            y: bounds.midY + totalHeight / 2 - titleString.size().height
        )
        let subtitleOrigin = NSPoint(
            x: bounds.midX - subtitleString.size().width / 2,
            y: titleOrigin.y - subtitleString.size().height - 3
        )

        titleString.draw(at: titleOrigin)
        subtitleString.draw(at: subtitleOrigin)
    }

    private func beginRecording() {
        isRecording = true
        onMessage?("使いたいキーの組み合わせを押してください。")
    }

    private func shortcutModifiers(from flags: NSEvent.ModifierFlags) -> [ShortcutModifier] {
        var modifiers: [ShortcutModifier] = []
        let normalizedFlags = flags.intersection(.deviceIndependentFlagsMask)

        if normalizedFlags.contains(.control) {
            modifiers.append(.control)
        }
        if normalizedFlags.contains(.option) {
            modifiers.append(.option)
        }
        if normalizedFlags.contains(.shift) {
            modifiers.append(.shift)
        }
        if normalizedFlags.contains(.command) {
            modifiers.append(.command)
        }

        return modifiers
    }
}
