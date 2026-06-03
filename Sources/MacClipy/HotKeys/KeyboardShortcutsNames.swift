import AppKit
import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let showHistory = Self(
        "showHistory",
        default: KeyboardShortcuts.Shortcut(.v, modifiers: [.command, .shift])
    )

    static let showFavorites = Self(
        "showFavorites",
        default: KeyboardShortcuts.Shortcut(.v, modifiers: [.command, .option])
    )

    static let showHelp = Self(
        "showHelp",
        default: KeyboardShortcuts.Shortcut(.slash, modifiers: [.command, .shift])
    )
}

enum LegacyShortcutConverter {
    struct Shortcut: Decodable, Equatable {
        var key: String
        var modifiers: [String]
    }

    static func convert(_ shortcut: Shortcut?) -> KeyboardShortcuts.Shortcut? {
        guard let shortcut,
              let key = key(named: shortcut.key)
        else {
            return nil
        }

        let modifiers = modifierFlags(from: shortcut.modifiers)
        guard modifiers.contains(.command) || modifiers.contains(.option) || modifiers.contains(.control) else {
            return nil
        }

        return KeyboardShortcuts.Shortcut(key, modifiers: modifiers)
    }

    private static func modifierFlags(from names: [String]) -> NSEvent.ModifierFlags {
        var result: NSEvent.ModifierFlags = []

        for name in names.map({ $0.lowercased() }) {
            switch name {
            case "command":
                result.insert(.command)
            case "shift":
                result.insert(.shift)
            case "option":
                result.insert(.option)
            case "control":
                result.insert(.control)
            default:
                continue
            }
        }

        return result
    }

    private static func key(named rawKey: String) -> KeyboardShortcuts.Key? {
        let normalizedKey = rawKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return keysByName[normalizedKey]
    }

    private static let keysByName: [String: KeyboardShortcuts.Key] = [
        "a": .a,
        "b": .b,
        "c": .c,
        "d": .d,
        "e": .e,
        "f": .f,
        "g": .g,
        "h": .h,
        "i": .i,
        "j": .j,
        "k": .k,
        "l": .l,
        "m": .m,
        "n": .n,
        "o": .o,
        "p": .p,
        "q": .q,
        "r": .r,
        "s": .s,
        "t": .t,
        "u": .u,
        "v": .v,
        "w": .w,
        "x": .x,
        "y": .y,
        "z": .z,
        "0": .zero,
        "1": .one,
        "2": .two,
        "3": .three,
        "4": .four,
        "5": .five,
        "6": .six,
        "7": .seven,
        "8": .eight,
        "9": .nine,
        "space": .space,
        "tab": .tab,
        "return": .return,
        "enter": .return
    ]
}
