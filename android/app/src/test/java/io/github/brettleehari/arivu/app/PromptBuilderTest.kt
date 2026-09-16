package io.github.brettleehari.arivu.app

import kotlinx.coroutines.test.runTest
import io.github.brettleehari.arivu.app.inference.BuiltPrompt
import io.github.brettleehari.arivu.app.inference.PromptBuilder
import io.github.brettleehari.arivu.app.inference.Turn
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

// spine: C7 — history is dropped visibly, whole turns only, never silently.
class PromptBuilderTest {
    /** One token per character keeps the arithmetic obvious. */
    private fun builder(nCtx: Int, reserve: Int) = PromptBuilder("sys", nCtx, reserve) { it.length }

    private val fixed = PromptBuilder.system("sys").length + PromptBuilder.ASSISTANT_OPEN.length

    private fun turn(i: Int, user: Boolean, len: Int) = Turn("t$i", user, "x".repeat(len))
    private fun rendered(t: Turn) = PromptBuilder.render(t).length

    @Test
    fun everythingFits_firstIncludedIsZero() = runTest {
        val turns = listOf(turn(0, true, 10), turn(1, false, 10), turn(2, true, 10))
        val r = builder(nCtx = 2048, reserve = 512).build(turns) as BuiltPrompt.Ok
        assertEquals(0, r.firstIncluded)
        assertTrue(r.text.startsWith(PromptBuilder.system("sys")))
        assertTrue(r.text.endsWith(PromptBuilder.ASSISTANT_OPEN))
        assertEquals(r.text.length, r.promptTokens)
    }

    @Test
    fun oldestTurnsDropped_andWindowStartsOnUserTurn() = runTest {
        val turns = listOf(turn(0, true, 100), turn(1, false, 100), turn(2, true, 100), turn(3, false, 100), turn(4, true, 100))
        // Room for exactly turns 2,3,4. Turn 2 is a user turn.
        val budget = rendered(turns[2]) + rendered(turns[3]) + rendered(turns[4])
        val r = builder(nCtx = fixed + budget + 50, reserve = 50).build(turns) as BuiltPrompt.Ok
        assertEquals(2, r.firstIncluded)

        // Room for turns 3,4 would start on assistant turn 3; builder must skip to user turn 4.
        val r2 = builder(nCtx = fixed + rendered(turns[3]) + rendered(turns[4]) + 50, reserve = 50).build(turns) as BuiltPrompt.Ok
        assertEquals(4, r2.firstIncluded)
    }

    @Test
    fun newestMessageTooLong_isReported_notTruncated() = runTest {
        val turns = listOf(turn(0, true, 5000))
        val r = builder(nCtx = 2048, reserve = 512).build(turns)
        assertTrue(r is BuiltPrompt.TooLong)
        r as BuiltPrompt.TooLong
        assertEquals(rendered(turns[0]), r.messageTokens)
        assertEquals(2048 - 512 - fixed, r.limitTokens)
    }
}
