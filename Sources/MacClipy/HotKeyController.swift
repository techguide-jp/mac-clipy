import Carbon
import Foundation

public enum HotKeyError: LocalizedError {
    case registrationFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .registrationFailed(let status):
            return "ホットキー登録に失敗しました: \(status)"
        }
    }
}

public final class HotKeyController {
    private static let signature = HotKeyController.fourCharCode("MCLP")
    private static let hotKeyID = UInt32(1)
    nonisolated(unsafe) private static var callback: (@MainActor () -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let onPressed: @MainActor () -> Void

    public init(onPressed: @MainActor @escaping () -> Void) {
        self.onPressed = onPressed
    }

    deinit {
        unregister()
    }

    public func register() throws {
        unregister()
        Self.callback = onPressed

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.handleHotKeyEvent,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            throw HotKeyError.registrationFailed(handlerStatus)
        }

        let carbonHotKeyID = EventHotKeyID(signature: Self.signature, id: Self.hotKeyID)
        let hotKeyStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(controlKey | optionKey),
            carbonHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard hotKeyStatus == noErr else {
            unregister()
            throw HotKeyError.registrationFailed(hotKeyStatus)
        }
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private static let handleHotKeyEvent: EventHandlerUPP = { _, event, _ in
        guard let event else {
            return noErr
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr,
              hotKeyID.signature == HotKeyController.signature,
              hotKeyID.id == HotKeyController.hotKeyID else {
            return noErr
        }

        Task { @MainActor in
            HotKeyController.callback?()
        }

        return noErr
    }

    private static func fourCharCode(_ value: String) -> OSType {
        var result: UInt32 = 0
        for byte in value.utf8.prefix(4) {
            result = (result << 8) + UInt32(byte)
        }
        return OSType(result)
    }
}
