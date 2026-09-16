// Flat JSON file in app-private storage (leaves/BRIEF.md "Persistence"). The twin of
// android/app/.../chat/ChatRepository.kt, behaviour for behaviour:
//
//  - a write goes to a temp file and is then renamed, so a kill mid-write never corrupts anything
//  - an unreadable file is set aside, never overwritten, and only the newest damaged copy is kept
//  - a missing file is an empty conversation, not an error
//
// Two things are iOS-only and both exist to make the privacy text true here as it is on Android
// (leaves/design.md §14, request 4): the file is excluded from iCloud backup and device transfer,
// and it carries a data-protection class so it is encrypted with the passcode at rest.
//
// spine: C3, C7

import Foundation

public final class ChatRepository: @unchecked Sendable {
    public let url: URL
    private let lock = NSLock()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        // Deterministic output, so two saves of the same conversation are the same bytes and a diff
        // of the file is readable. NOT the same key ORDER as kotlinx (which writes declaration
        // order) — a JSON object is unordered and kotlinx's decoder does not care, so the contract
        // that matters is the field names, the enum spellings, and the presence of `stop: null` and
        // `reported: false`. ConversationTests asserts all three.
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return e
    }()

    public init(url: URL) {
        self.url = url
    }

    /// The conversation file in the app's own Documents-adjacent private storage.
    /// `Application Support` rather than `Documents`: nothing here is a user-visible document, and
    /// `Documents` is what the Files app would surface if file sharing were ever switched on.
    public static func defaultURL(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(for: .applicationSupportDirectory,
                                       in: .userDomainMask,
                                       appropriateFor: nil,
                                       create: true)
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent(Policy.conversationFileName)
    }

    public func load() -> [Message] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url) else { return [] }
        do {
            return try JSONDecoder().decode(StoredConversation.self, from: data).messages
        } catch {
            // Keep the unreadable file rather than overwrite it on the next save, but only the newest
            // one: older copies are private text nobody can reach, kept forever otherwise (T13). spine: C3
            let aside = url.deletingLastPathComponent()
                .appendingPathComponent(Self.corruptPrefix(url) + String(Message.now()))
            try? FileManager.default.moveItem(at: url, to: aside)
            pruneCorruptCopiesLocked()
            return []
        }
    }

    public func save(_ messages: [Message]) {
        lock.lock()
        defer { lock.unlock() }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? encoder.encode(StoredConversation(messages: messages)) else { return }
        let tmp = dir.appendingPathComponent(url.lastPathComponent + ".tmp")
        do {
            try data.write(to: tmp, options: [.atomic])
            protect(tmp)
            _ = try? FileManager.default.removeItem(at: url)
            try FileManager.default.moveItem(at: tmp, to: url)
            excludeFromBackup(url)
        } catch {
            try? FileManager.default.removeItem(at: tmp)
        }
    }

    /// Deletes all but the newest `<name>.corrupt-<millis>` copy. Internal so a test can call it.
    public func pruneCorruptCopies(keep: Int = 1) {
        lock.lock()
        defer { lock.unlock() }
        pruneCorruptCopiesLocked(keep: keep)
    }

    private func pruneCorruptCopiesLocked(keep: Int = 1) {
        let prefix = Self.corruptPrefix(url)
        let dir = url.deletingLastPathComponent()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        names.filter { $0.hasPrefix(prefix) }
            .sorted { (Int64($0.dropFirst(prefix.count)) ?? 0) > (Int64($1.dropFirst(prefix.count)) ?? 0) }
            .dropFirst(keep)
            .forEach { try? FileManager.default.removeItem(at: dir.appendingPathComponent($0)) }
    }

    private static func corruptPrefix(_ url: URL) -> String { url.lastPathComponent + ".corrupt-" }

    /// spine: C3 — "stays only on this phone" has to be true of the backup too.
    private func excludeFromBackup(_ url: URL) {
        var u = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? u.setResourceValues(values)
    }

    private func protect(_ url: URL) {
        #if os(iOS)
        // `completeUnlessOpen`, not `complete`: a reply may still be streaming and saving when the
        // screen locks, and losing the file handle there would lose the partial reply (C7).
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: url.path)
        #endif
    }
}
