import Carbon
import Foundation

public enum HotKeyError: LocalizedError {
    case registrationFailed(OSStatus)
    case unsupportedShortcut(String)

    public var errorDescription: String? {
        switch self {
        case .registrationFailed(let status):
            return L10n.tr("hotKey.error.registrationFailed", status)
        case .unsupportedShortcut(let shortcut):
            return L10n.tr("hotKey.error.unsupportedShortcut", shortcut)
        }
    }
}

public final class HotKeyController {
    private static let signature = HotKeyController.fourCharCode("MCLP")
    nonisolated(unsafe) private static var callbacks: [UInt32: @MainActor () -> Void] = [:]
    nonisolated(unsafe) private static var callbackOwners: [UInt32: ObjectIdentifier] = [:]
    nonisolated(unsafe) private static var eventHandlerRef: EventHandlerRef?

    public let shortcut: KeyboardShortcut
    public let identifier: UInt32
    public private(set) var isRegistered = false

    private var hotKeyRef: EventHotKeyRef?
    private let onPressed: @MainActor () -> Void

    public init(shortcut: KeyboardShortcut, identifier: UInt32 = 1, onPressed: @MainActor @escaping () -> Void) {
        self.shortcut = shortcut
        self.identifier = identifier
        self.onPressed = onPressed
    }

    deinit {
        unregister()
    }

    public func register() throws {
        unregister()

        guard let keyCode = shortcut.carbonKeyCode else {
            throw HotKeyError.unsupportedShortcut(shortcut.displayName)
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        try Self.installHandlerIfNeeded(eventType: &eventType)

        let carbonHotKeyID = EventHotKeyID(signature: Self.signature, id: identifier)
        let hotKeyStatus = RegisterEventHotKey(
            keyCode,
            shortcut.carbonModifiers,
            carbonHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard hotKeyStatus == noErr else {
            unregister()
            throw HotKeyError.registrationFailed(hotKeyStatus)
        }

        Self.callbacks[identifier] = onPressed
        Self.callbackOwners[identifier] = ObjectIdentifier(self)
        isRegistered = true
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if Self.callbackOwners[identifier] == ObjectIdentifier(self) {
            Self.callbacks[identifier] = nil
            Self.callbackOwners[identifier] = nil
        }
        Self.removeHandlerIfUnused()
        isRegistered = false
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
              let callback = HotKeyController.callbacks[hotKeyID.id] else {
            return noErr
        }

        Task { @MainActor in
            callback()
        }

        return noErr
    }

    private static func installHandlerIfNeeded(eventType: inout EventTypeSpec) throws {
        guard eventHandlerRef == nil else {
            return
        }

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
    }

    private static func removeHandlerIfUnused() {
        guard callbacks.isEmpty, let eventHandlerRef else {
            return
        }

        RemoveEventHandler(eventHandlerRef)
        Self.eventHandlerRef = nil
    }

    private static func fourCharCode(_ value: String) -> OSType {
        var result: UInt32 = 0
        for byte in value.utf8.prefix(4) {
            result = (result << 8) + UInt32(byte)
        }
        return OSType(result)
    }
}
