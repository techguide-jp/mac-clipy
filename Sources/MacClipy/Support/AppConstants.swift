import Carbon
import CoreGraphics
import Foundation

public enum AppConstants {
    public enum Clipboard {
        public static let defaultMaxItems = 200
        // 100 KiB keeps accidental large clipboard payloads out of the lightweight JSON history.
        public static let defaultMaxItemSizeBytes = 100 * 1024
        public static let initialUseCount = 1
        public static let useCountIncrement = 1
        public static let mostRecentInsertIndex = 0
        public static let menuTitleCharacterLimit = 64
    }

    public enum Favorites {
        public static let initialSortOrder = 0
        public static let sortOrderStep = 1
    }

    public enum ClipboardMonitor {
        // Polling below half a second keeps the menu responsive without busy-waiting the pasteboard.
        public static let pollingInterval: TimeInterval = 0.45
    }

    public enum Paste {
        // Give the previous application a short activation window before synthesizing Command+V.
        public static let delayBeforeSendingCommandV: TimeInterval = 0.15
        public static let commandVKeyCode = CGKeyCode(kVK_ANSI_V)
    }

    public enum HotKey {
        public static let defaultIdentifier: UInt32 = 1
        public static let historyIdentifier: UInt32 = 1
        public static let favoritesIdentifier: UInt32 = 2
        public static let handlerEventCount = 1
        public static let registrationOptions: UInt32 = 0
        public static let fourCharCodeLength = 4
        // Carbon OSType signatures are packed one byte at a time into a 32-bit integer.
        public static let fourCharCodeByteShift = 8
    }

    public enum MenuBar {
        public static let statusItemWidth: CGFloat = 84
        public static let recentHistoryItemLimit = 10
        public static let keyEquivalentItemLimit = 9
    }

    public enum Keyboard {
        public static let firstFolderShortcutIndex = 1
        public static let lastFolderShortcutIndex = 9
    }
}
