package com.killjoy00.ultttt

import org.junit.Assert.*
import org.junit.Test

class GameSessionTest {
    @Test fun newGamePreservesScoresAndSwitchesMode() {
        val session = GameSession(xWins = 3, oWins = 2)
            .newGame(GameMode.TWO_PLAYER, Difficulty.HARD)
        assertEquals(3, session.xWins)
        assertEquals(2, session.oWins)
        assertEquals(GameMode.TWO_PLAYER, session.mode)
        assertEquals(81, session.game.legalMoves.size)
    }

    @Test fun soloUndoReturnsToLastHumanChoice() {
        val x = requireNotNull(GameSession().play(Move(4, 6)))
        val o = requireNotNull(x.play(Move(6, 0)))
        val undone = requireNotNull(o.undoTurn())
        assertEquals(Game(), undone.game)
        assertEquals(0, undone.game.moves.size)
    }

    @Test fun humanCannotScoreOnRejectedMove() {
        val session = GameSession()
        assertNull(session.play(Move(0, 50)))
        assertEquals(0, session.xWins)
    }
}
