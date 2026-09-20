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
    /**
     * What this reply cost. Null on user messages, while streaming, and in files written before the
     * field existed. Written by iOS today and read by both: the conversation file is one schema
     * across platforms (MULTIPLATFORM.md appendix), so the field lands here at the same time even
     * though the Android UI does not draw it yet. Without it an Android save would silently drop
     * what an iOS save wrote, which is exactly the drift the shared schema exists to prevent.
     */
    val stats: ReplyStats? = null,
)

/**
 * Raw measurements only: tokens in, tokens out, milliseconds spent writing. The rate is derived at
 * the point of display, so a saved conversation never carries a number that disagrees with the two
 * it was computed from. Field names and order match ios/ArivuKit/Sources/ArivuCore/Conversation.swift.
 */
@Serializable
data class ReplyStats(
    val promptTokens: Int,
    val generatedTokens: Int,
    val decodeMs: Double,
    /** Id of the oldest turn the model could see, so the exact prompt can be rebuilt rather than stored twice. */
    val contextFirstID: String? = null,
    /** FNV-1a of the system prompt in force when this reply was written; 0 means not recorded. */
    val systemPromptHash: Long = 0,
)

private fun corruptPrefix(file: File) = file.name + ".corrupt-"

@Serializable
data class StoredConversation(
    val version: Int = 1,
    val messages: List<Message> = emptyList(),
    /**
     * The wording this conversation runs with, or null for the shipped one (D-064). Only the part a
     * user may edit — Policy.SYSTEM_PROMPT's safety sentences are appended when the prompt is
     * assembled and are deliberately not stored, so a hand-edited file cannot remove them either.
     *
     * Android has no editor yet (W142). The field is here so an Android save cannot silently drop
     * what an iOS save wrote, which is the whole point of one schema across platforms.
     */
    val systemPromptBody: String? = null,
)

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
