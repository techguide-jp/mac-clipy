import Carbon
import Foundation

public enum ShortcutModifier: String, Codable, CaseIterable, Equatable, Sendable {
    case command
    case shift
    case option
    case control

    var carbonFlag: UInt32 {
        switch self {
        case .command:
            UInt32(cmdKey)
        case .shift:
            UInt32(shiftKey)
        case .option:
            UInt32(optionKey)
        case .control:
            UInt32(controlKey)
        }
    }

    var displaySymbol: String {
        switch self {
        case .command:
            "⌘"
        case .shift:
            "⇧"
        case .option:
            "⌥"
        case .control:
            "⌃"
        }
    }

    static let displayOrder: [ShortcutModifier] = [.control, .option, .shift, .command]
}

public enum KeyboardShortcutParseError: LocalizedError, Equatable, Sendable {
    case empty
    case missingModifier
    case missingKey
    case multipleKeys
    case unsupportedKey(String)

    public var errorDescription: String? {
        switch self {
        case .empty:
            "ショートカットを入力してください。"
        case .missingModifier:
            "command、shift、option、control のいずれかを含めてください。"
        case .missingKey:
            "ショートカットのキーを入力してください。"
        case .multipleKeys:
            "ショートカットのキーは1つだけ指定してください。"
        case .unsupportedKey(let key):
            "\(key) は対応していないキーです。英数字、space、tab、enter、escape を指定してください。"
        }
    }
}

public struct KeyboardShortcut: Codable, Equatable, Sendable {
    public static let defaultShortcut = KeyboardShortcut(key: "v", modifiers: [.shift, .command])

    public var key: String
    public var modifiers: [ShortcutModifier]

    public init(key: String, modifiers: [ShortcutModifier]) {
        self.key = Self.normalizedKey(key)
        self.modifiers = Self.normalizedModifiers(modifiers)
    }

    public var carbonKeyCode: UInt32? {
        Self.keyCodes[key]
    }

    public static func key(forCarbonKeyCode keyCode: UInt32) -> String? {
        keysByCode[keyCode]
    }

    public var carbonModifiers: UInt32 {
        modifiers.reduce(UInt32(0)) { $0 | $1.carbonFlag }
    }

    public var displayName: String {
        let modifierDisplay = ShortcutModifier.displayOrder
            .filter { modifiers.contains($0) }
            .map(\.displaySymbol)
            .joined()
        return modifierDisplay + keyDisplayName
    }

    public var editingString: String {
        let modifierNames = ShortcutModifier.displayOrder
            .filter { modifiers.contains($0) }
            .map(\.rawValue)
        return (modifierNames + [key]).joined(separator: "+")
    }

    public static func parse(_ rawValue: String) throws -> KeyboardShortcut {
        let tokens = normalizedTokens(from: rawValue)
        guard !tokens.isEmpty else {
            throw KeyboardShortcutParseError.empty
        }

        var modifiers: [ShortcutModifier] = []
        var key: String?

        for token in tokens {
            if let modifier = modifier(from: token) {
                modifiers.append(modifier)
                continue
            }

            guard key == nil else {
                throw KeyboardShortcutParseError.multipleKeys
            }

            let normalizedKey = normalizedKey(token)
            guard keyCodes[normalizedKey] != nil else {
                throw KeyboardShortcutParseError.unsupportedKey(token)
            }
            key = normalizedKey
        }

        guard !modifiers.isEmpty else {
            throw KeyboardShortcutParseError.missingModifier
        }

        guard let key else {
            throw KeyboardShortcutParseError.missingKey
        }

        return KeyboardShortcut(key: key, modifiers: modifiers)
    }

    private var keyDisplayName: String {
        switch key {
        case "space":
            "Space"
        case "tab":
            "Tab"
        case "return":
            "Return"
        case "escape":
            "Esc"
        default:
            key.uppercased()
        }
    }

    private static func normalizedTokens(from rawValue: String) -> [String] {
        var value = rawValue.lowercased()
        let replacements = [
            "⌘": " command ",
            "⇧": " shift ",
            "⌥": " option ",
            "⌃": " control ",
            "+": " ",
            "＋": " ",
            ",": " ",
            "-": " "
        ]

        for (source, replacement) in replacements {
            value = value.replacingOccurrences(of: source, with: replacement)
        }

        return value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }

    private static func modifier(from token: String) -> ShortcutModifier? {
        switch token {
        case "command", "cmd":
            .command
        case "shift":
            .shift
        case "option", "opt", "alt":
            .option
        case "control", "ctrl", "ctl":
            .control
        default:
            nil
        }
    }

    private static func normalizedKey(_ key: String) -> String {
        switch key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "enter":
            "return"
        case "esc":
            "escape"
        default:
            key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    private static func normalizedModifiers(_ modifiers: [ShortcutModifier]) -> [ShortcutModifier] {
        ShortcutModifier.displayOrder.filter { modifiers.contains($0) }
    }

    private static let keyCodes: [String: UInt32] = [
        "a": UInt32(kVK_ANSI_A),
        "s": UInt32(kVK_ANSI_S),
        "d": UInt32(kVK_ANSI_D),
        "f": UInt32(kVK_ANSI_F),
        "h": UInt32(kVK_ANSI_H),
        "g": UInt32(kVK_ANSI_G),
        "z": UInt32(kVK_ANSI_Z),
        "x": UInt32(kVK_ANSI_X),
        "c": UInt32(kVK_ANSI_C),
        "v": UInt32(kVK_ANSI_V),
        "b": UInt32(kVK_ANSI_B),
        "q": UInt32(kVK_ANSI_Q),
        "w": UInt32(kVK_ANSI_W),
        "e": UInt32(kVK_ANSI_E),
        "r": UInt32(kVK_ANSI_R),
        "y": UInt32(kVK_ANSI_Y),
        "t": UInt32(kVK_ANSI_T),
        "1": UInt32(kVK_ANSI_1),
        "2": UInt32(kVK_ANSI_2),
        "3": UInt32(kVK_ANSI_3),
        "4": UInt32(kVK_ANSI_4),
        "6": UInt32(kVK_ANSI_6),
        "5": UInt32(kVK_ANSI_5),
        "9": UInt32(kVK_ANSI_9),
        "7": UInt32(kVK_ANSI_7),
        "8": UInt32(kVK_ANSI_8),
        "0": UInt32(kVK_ANSI_0),
        "o": UInt32(kVK_ANSI_O),
        "u": UInt32(kVK_ANSI_U),
        "i": UInt32(kVK_ANSI_I),
        "p": UInt32(kVK_ANSI_P),
        "l": UInt32(kVK_ANSI_L),
        "j": UInt32(kVK_ANSI_J),
        "k": UInt32(kVK_ANSI_K),
        "n": UInt32(kVK_ANSI_N),
        "m": UInt32(kVK_ANSI_M),
        "space": UInt32(kVK_Space),
        "tab": UInt32(kVK_Tab),
        "return": UInt32(kVK_Return),
        "escape": UInt32(kVK_Escape)
    ]

    private static let keysByCode: [UInt32: String] = {
        var result: [UInt32: String] = [:]
        for (key, code) in keyCodes {
            result[code] = key
        }
        return result
    }()
}
