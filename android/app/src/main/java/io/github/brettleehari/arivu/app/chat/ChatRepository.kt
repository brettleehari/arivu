package io.github.brettleehari.arivu.app.chat

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File

/** Why a reply ended. LOW_MEMORY is the phone giving up, not the user and not the model (spine: C6). */
@Serializable
enum class Stop { END_OF_TURN, CANCELLED, CONTEXT_FULL, MAX_TOKENS, ERROR, LOW_MEMORY }

@Serializable
data class Message(
    val id: String,
    val fromUser: Boolean,
    val text: String,
    val createdAt: Long,
    /** Null while streaming or for user messages. */
    val stop: Stop? = null,
    /** The user flagged this reply with Report (kept on the phone; the report itself goes by their email app). spine: C9 */
    val reported: Boolean = false,
)

private fun corruptPrefix(file: File) = file.name + ".corrupt-"

@Serializable
data class StoredConversation(val version: Int = 1, val messages: List<Message> = emptyList())

/**
 * Flat JSON file (leaves/BRIEF.md "Persistence"). App-private storage, excluded from backup (spine: C3).
 * Writes go to a temp file then rename, so a kill mid-write never corrupts the conversation.
 */
class ChatRepository(private val file: File) {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    fun load(): List<Message> {
        if (!file.exists()) return emptyList()
        return runCatching { json.decodeFromString<StoredConversation>(file.readText()).messages }
            .getOrElse {
                // Keep the unreadable file rather than overwrite it on next save, but only the newest one:
                // older copies are private text nobody can reach, kept forever otherwise (threat-model T13). spine: C3
                file.renameTo(File(file.parentFile, corruptPrefix(file) + System.currentTimeMillis()))
                pruneCorruptCopies()
                emptyList()
            }
    }

    /** Deletes all but the newest `<name>.corrupt-<millis>` copy. */
    internal fun pruneCorruptCopies(keep: Int = 1) {
        val prefix = corruptPrefix(file)
        file.parentFile?.listFiles { f -> f.name.startsWith(prefix) }.orEmpty()
            .sortedByDescending { it.name.removePrefix(prefix).toLongOrNull() ?: 0L }
            .drop(keep)
            .forEach { it.delete() }
    }

    @Synchronized
    fun save(messages: List<Message>) {
        file.parentFile?.mkdirs()
        val tmp = File(file.parentFile, file.name + ".tmp")
        tmp.writeText(json.encodeToString(StoredConversation(messages = messages)))
        if (!tmp.renameTo(file)) {
            file.delete()
            tmp.renameTo(file)
        }
    }
}
