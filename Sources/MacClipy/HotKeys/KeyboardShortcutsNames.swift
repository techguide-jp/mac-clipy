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
}

enum LegacyShortcutConverter {
    struct Shortcut: Decodable, Equatable {
        var key: String
        var modifiers: [String]
    }

    static func convert(_ shortcut: Shortcut?) -> KeyboardShortcuts.Shortcut? {
        guard let shortcut,
              let key = key(named: shortcut.key) else {
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
        switch rawKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "a": .a
        case "b": .b
        case "c": .c
        case "d": .d
        case "e": .e
        case "f": .f
        case "g": .g
        case "h": .h
        case "i": .i
        case "j": .j
        case "k": .k
        case "l": .l
        case "m": .m
        case "n": .n
        case "o": .o
        case "p": .p
        case "q": .q
        case "r": .r
        case "s": .s
        case "t": .t
        case "u": .u
        case "v": .v
        case "w": .w
        case "x": .x
        case "y": .y
        case "z": .z
        case "0": .zero
        case "1": .one
        case "2": .two
        case "3": .three
        case "4": .four
        case "5": .five
        case "6": .six
        case "7": .seven
        case "8": .eight
        case "9": .nine
        case "space": .space
        case "tab": .tab
        case "return", "enter": .return
        default: nil
        }
    }
}
