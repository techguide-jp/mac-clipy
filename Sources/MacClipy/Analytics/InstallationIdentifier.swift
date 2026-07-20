import Foundation
import Security

protocol InstallationIdentifierStoring {
    func load() throws -> String?
    func save(_ value: String) throws
}

protocol InstallationIdentifierProviding {
    func installationIdentifier() throws -> UUID
}

enum InstallationIdentifierError: Error {
    case keychain(OSStatus)
    case invalidKeychainValue
}

struct InstallationIdentifierProvider: InstallationIdentifierProviding {
    private let store: any InstallationIdentifierStoring

    init(store: any InstallationIdentifierStoring) {
        self.store = store
    }

    func installationIdentifier() throws -> UUID {
        if let storedValue = try store.load(), let identifier = UUID(uuidString: storedValue) {
            return identifier
        }

        let identifier = UUID()
        try store.save(identifier.uuidString.lowercased())
        return identifier
    }
}

struct KeychainInstallationIdentifierStore: InstallationIdentifierStoring {
    private let service = "jp.techguide.macclipy.analytics"
    private let account = "installation-id"

    func load() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw InstallationIdentifierError.keychain(status)
        }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw InstallationIdentifierError.invalidKeychainValue
        }
        return value
    }

    func save(_ value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw InstallationIdentifierError.invalidKeychainValue
        }

        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw InstallationIdentifierError.keychain(updateStatus)
        }

        var item = baseQuery
        item[kSecValueData as String] = data
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw InstallationIdentifierError.keychain(addStatus)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
