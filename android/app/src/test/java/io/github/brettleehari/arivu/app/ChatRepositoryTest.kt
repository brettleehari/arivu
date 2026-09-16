package io.github.brettleehari.arivu.app

import io.github.brettleehari.arivu.app.chat.ChatRepository
import io.github.brettleehari.arivu.app.chat.Message
import io.github.brettleehari.arivu.app.chat.Stop
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

// spine: C7 — replies that were cut off keep their stop reason across restarts.
class ChatRepositoryTest {
    @get:Rule val tmp = TemporaryFolder()

    @Test
    fun roundTrip() {
        val f = File(tmp.root, "conversation.json")
        val repo = ChatRepository(f)
        val msgs = listOf(
            Message("1", true, "Rewrite: send it now", 1L),
            Message("2", false, "Could you send it, please? ✓ €", 2L, Stop.CONTEXT_FULL),
        )
        repo.save(msgs)
        assertEquals(msgs, ChatRepository(f).load())
    }

    @Test
    fun missingFileIsEmpty() = assertEquals(emptyList<Message>(), ChatRepository(File(tmp.root, "none.json")).load())

    @Test
    fun corruptFileIsSetAsideNotOverwritten() {
        val f = File(tmp.root, "conversation.json").apply { writeText("{not json") }
        assertEquals(emptyList<Message>(), ChatRepository(f).load())
        assertTrue(tmp.root.listFiles()!!.any { it.name.startsWith("conversation.json.corrupt-") })
    }

    // spine: C3 — damaged copies hold private text; only the newest one is kept.
    @Test
    fun onlyNewestCorruptCopyIsKept() {
        listOf(100L, 300L, 200L).forEach { File(tmp.root, "conversation.json.corrupt-$it").writeText("old") }
        val f = File(tmp.root, "conversation.json").apply { writeText("{not json") }
        assertEquals(emptyList<Message>(), ChatRepository(f).load())
        val left = tmp.root.listFiles()!!.map { it.name }.filter { it.startsWith("conversation.json.corrupt-") }
        assertEquals("kept $left", 1, left.size)
        assertTrue("kept an old copy instead of the newest: $left", left.single().removePrefix("conversation.json.corrupt-").toLong() > 300L)
    }
}
