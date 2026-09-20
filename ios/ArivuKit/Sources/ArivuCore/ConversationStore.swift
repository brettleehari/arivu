// Many conversations instead of one (D-011).
//
// Until now Arivu kept a single file that grew forever with no way to clear it, which D-011 already
// named as the problem: "a writing assistant's old pasted text stays on the phone indefinitely."
// So this is not only a convenience. Being able to end a conversation, and delete one, is the first
// time a user has had any way to get their own text off the device (C3).
//
// A DIRECTORY OF ChatRepository, not a new storage format. Every property that file already has —
// atomic write-then-rename, an unreadable file set aside rather than overwritten, the data
// protection class, exclusion from iCloud backup and device transfer — is a property each
// conversation needs, and reimplementing them for a multi-conversation format would be four chances
// to get one of them wrong. One conversation is one file, as it always was; there are simply more.
//
// It also means the throttled save during streaming still rewrites one small file rather than every
// conversation the user has ever had.
//
// spine: C3, C7

import Foundation

/// One row in the conversation list. Deliberately not the conversation itself: the list is shown far
/// more often than any single conversation is opened.
public struct ConversationSummary: Identifiable, Equatable, Sendable {
    public let id: String
    /// The opening of the first thing the user said, which is what they will recognise. Never a
    /// summary the model wrote: that would be a second thing to get wrong, and it would cost a
    /// generation per conversation.
    public let title: String
    public let updatedAt: Int64
    public let messageCount: Int
}

public final class ConversationStore: @unchecked Sendable {
    public let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// `Application Support/conversations`, beside where the single file used to live.
    public static func defaultDirectory(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                       appropriateFor: nil, create: true)
        return base.appendingPathComponent("conversations", isDirectory: true)
    }

    public func repository(for id: String) -> ChatRepository {
        ChatRepository(url: directory.appendingPathComponent("\(id).json"))
    }

    /// Newest first. Reads every conversation to take its first line and count, which is O(files) —
    /// acceptable because the files are small and a person has tens of conversations, not thousands.
    /// If that ever stops being true, the fix is a sidecar index, not a different format.
    public func list() -> [ConversationSummary] {
        let urls = (try? fileManager.contentsOfDirectory(at: directory,
                                                         includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "json" } ?? []
        return urls.compactMap { url in
            let id = url.deletingPathExtension().lastPathComponent
            let messages = ChatRepository(url: url).load()
            guard !messages.isEmpty else { return nil }
            return ConversationSummary(id: id,
                                       title: Self.title(from: messages),
                                       updatedAt: messages.last?.createdAt ?? 0,
                                       messageCount: messages.count)
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func create() -> String { UUID().uuidString }

    public func delete(_ id: String) {
        try? fileManager.removeItem(at: directory.appendingPathComponent("\(id).json"))
    }

    /// The single conversation from before this existed becomes the first one in the list, keeping
    /// its text and its order. Returns its id if it moved, so the app can open what the user was
    /// last looking at rather than an empty screen.
    @discardableResult
    public func migrateLegacyConversation(at legacy: URL) -> String? {
        guard fileManager.fileExists(atPath: legacy.path) else { return nil }
        let id = create()
        let destination = directory.appendingPathComponent("\(id).json")
        do {
            try fileManager.moveItem(at: legacy, to: destination)
        } catch {
            // A copy is second best but still keeps the text; the original is left alone rather than
            // deleted, because losing a conversation to a failed migration is unrecoverable.
            guard (try? fileManager.copyItem(at: legacy, to: destination)) != nil else { return nil }
        }
        return id
    }

    /// First line of the first thing the user wrote, trimmed to something a row can show.
    static func title(from messages: [Message]) -> String {
        guard let first = messages.first(where: { $0.fromUser && !$0.text.isEmpty }) else { return "" }
        let line = first.text
            .split(separator: "\n", omittingEmptySubsequences: true).first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? first.text
        return line.count <= 60 ? line : String(line.prefix(60)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
