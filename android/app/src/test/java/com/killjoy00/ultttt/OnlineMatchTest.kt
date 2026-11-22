package com.killjoy00.ultttt

import org.junit.Assert.*
import org.junit.Test

class OnlineMatchTest {
    private val alice = "alice"
    private val bob = "bob"

    private fun match(
        moves: List<Move> = emptyList(),
        status: String = "active",
        winner: String? = null
    ) = OnlineMatch(
        id = "demo", inviteCode = "ABCDEF123456",
        playerX = alice, playerO = bob, moves = moves, status = status,
        winner = winner, updatedAt = ""
    )

    @Test fun onlyCurrentParticipantMayMove() {
        val opened = match()
        assertEquals(Mark.X, opened.myMark(alice))
        assertEquals(Mark.O, opened.myMark(bob))
        assertTrue(opened.canPlay(alice))
        assertFalse(opened.canPlay(bob))
        assertFalse(opened.canPlay("stranger"))

        val after = match(moves = listOf(Move(4, 2)))
        assertEquals(2, after.game.forcedBoard)
        assertFalse(after.canPlay(alice))
        assertTrue(after.canPlay(bob))
    }

    @Test fun waitingAndFinishedGamesRejectMoves() {
        assertFalse(match(status = "waiting").canPlay(alice))
        assertFalse(match(status = "finished", winner = "O").canPlay(alice))
        assertTrue(match(status = "finished", winner = "O").didWin(bob))
        assertFalse(match(status = "finished", winner = "O").didWin(alice))
        assertFalse(match(status = "finished", winner = "DRAW").didWin(alice))
    }

    @Test fun corruptedHistoryNeverBecomesPlayable() {
        val broken = match(moves = listOf(Move(4, 0), Move(1, 2)))
        assertThrows(IllegalArgumentException::class.java) { broken.game }
    }
}
