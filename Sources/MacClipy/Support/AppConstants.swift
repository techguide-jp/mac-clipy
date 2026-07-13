import Carbon
import CoreGraphics
import Foundation

public enum AppConstants {
    public enum Support {
        public static let operatorInformationURL = makeURL("https://techguide.jp/#company")
        public static let contactURL: URL = makeContactURL()

        private static func makeURL(_ value: String) -> URL {
            guard let url = URL(string: value) else {
                preconditionFailure("Invalid support URL")
            }
            return url
        }

        private static func makeContactURL() -> URL {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "techguide.jp"
            components.path = "/contact/"
            components.queryItems = [
                URLQueryItem(name: "category", value: "macclipy"),
                URLQueryItem(name: "subject", value: L10n.tr("support.contactSubject"))
            ]
            guard let url = components.url else {
                preconditionFailure("Invalid contact URL")
            }
            return url
        }
    }

    public enum Clipboard {
        public static let defaultMaxItems = 200
        // 軽量なJSON履歴を維持するため、巨大なクリップボード内容は保存しない。
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
        /// 反応速度を保ちつつ、ペーストボードを過剰に監視しない間隔にする。
        public static let pollingInterval: TimeInterval = 0.45
    }

    public enum Paste {
        // 前面アプリへ戻る猶予を置いてからCommand+Vを送る。
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
        /// CarbonのOSType署名は1バイトずつ32bit整数へ詰める。
        public static let fourCharCodeByteShift = 8
    }

    public enum MenuBar {
        public static let recentHistoryItemLimit = 10
        public static let keyEquivalentItemLimit = 9
    }

    public enum Keyboard {
        public static let firstFolderShortcutIndex = 1
        public static let lastFolderShortcutIndex = 9
    }
}
