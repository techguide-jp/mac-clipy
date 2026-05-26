import AppKit
import Carbon

private enum ShortcutRecorderMetrics {
    static let intrinsicHeight: CGFloat = 54
    static let borderInset: CGFloat = 1
    static let cornerRadius: CGFloat = 8
    static let recordingFillAlpha: CGFloat = 0.08
    static let recordingBorderWidth: CGFloat = 2
    static let idleBorderWidth: CGFloat = 1
    static let recordingTitleFontSize: CGFloat = 16
    static let idleTitleFontSize: CGFloat = 18
    static let subtitleFontSize: CGFloat = 12
    static let titleSubtitleSpacing: CGFloat = 3
}

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
        toolTip = L10n.tr("shortcutRecorder.toolTip")
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
        NSSize(width: NSView.noIntrinsicMetric, height: ShortcutRecorderMetrics.intrinsicHeight)
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
            onMessage?(L10n.tr("shortcutRecorder.cancelled"))
            return
        }

        guard let key = KeyboardShortcut.key(forCarbonKeyCode: UInt32(event.keyCode)) else {
            NSSound.beep()
            onMessage?(L10n.tr("shortcutRecorder.unsupportedKey"))
            return
        }

        let modifiers = shortcutModifiers(from: event.modifierFlags)
        guard KeyboardShortcut.hasActivationModifier(modifiers) else {
            NSSound.beep()
            onMessage?(L10n.tr("shortcutRecorder.missingModifier"))
            return
        }

        let nextShortcut = KeyboardShortcut(key: key, modifiers: modifiers)
        shortcut = nextShortcut
        isRecording = false
        onShortcutChange?(nextShortcut)
        onMessage?(L10n.tr("shortcutRecorder.willActivate", nextShortcut.displayName))
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let bounds = bounds.insetBy(
            dx: ShortcutRecorderMetrics.borderInset,
            dy: ShortcutRecorderMetrics.borderInset
        )
        let radius = ShortcutRecorderMetrics.cornerRadius
        let path = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)

        let isFocused = window?.firstResponder === self
        let borderColor: NSColor = isRecording
            ? .controlAccentColor
            : (isFocused ? .keyboardFocusIndicatorColor : .separatorColor)
        let fillColor: NSColor = isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(ShortcutRecorderMetrics.recordingFillAlpha)
            : NSColor.controlBackgroundColor

        fillColor.setFill()
        path.fill()

        borderColor.setStroke()
        path.lineWidth = isRecording
            ? ShortcutRecorderMetrics.recordingBorderWidth
            : ShortcutRecorderMetrics.idleBorderWidth
        path.stroke()

        let title = isRecording ? L10n.tr("shortcutRecorder.recordingTitle") : shortcut.displayName
        let subtitle = isRecording
            ? L10n.tr("shortcutRecorder.recordingSubtitle")
            : L10n.tr("shortcutRecorder.idleSubtitle")

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(
                ofSize: isRecording
                    ? ShortcutRecorderMetrics.recordingTitleFontSize
                    : ShortcutRecorderMetrics.idleTitleFontSize,
                weight: .semibold
            ),
            .foregroundColor: NSColor.labelColor
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: ShortcutRecorderMetrics.subtitleFontSize),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        let subtitleString = NSAttributedString(string: subtitle, attributes: subtitleAttributes)
        let totalHeight = titleString.size().height
            + ShortcutRecorderMetrics.titleSubtitleSpacing
            + subtitleString.size().height
        let titleOrigin = NSPoint(
            x: bounds.midX - titleString.size().width / 2,
            y: bounds.midY + totalHeight / 2 - titleString.size().height
        )
        let subtitleOrigin = NSPoint(
            x: bounds.midX - subtitleString.size().width / 2,
            y: titleOrigin.y - subtitleString.size().height - ShortcutRecorderMetrics.titleSubtitleSpacing
        )

        titleString.draw(at: titleOrigin)
        subtitleString.draw(at: subtitleOrigin)
    }

    private func beginRecording() {
        isRecording = true
        onMessage?(L10n.tr("shortcutRecorder.prompt"))
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
