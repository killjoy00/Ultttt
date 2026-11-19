package com.killjoy00.ultttt

import org.junit.Assert.*
import org.junit.Test

class GameTest {
    @Test fun openingAllows81Squares() {
        val g = Game()
        assertEquals(81, g.legalMoves.size)
        assertNull(g.forcedBoard)
        assertEquals(Mark.X, g.currentPlayer)
    }

    @Test fun forcesTheMatchingBoardAndRejectsWrongBoard() {
        val g = requireNotNull(Game().play(Move(4, 2)))
        assertEquals(2, g.forcedBoard)
        assertEquals(listOf(2), g.legalBoards)
        assertNull(g.play(Move(3, 4)))
        assertEquals(0, requireNotNull(g.play(Move(2, 0))).forcedBoard)
    }

    @Test fun winningDestinationAllowsFreeChoice() {
        val boards = List(9) { index ->
            if (index == 2) listOf(Mark.X, Mark.X, Mark.X) + List<Mark?>(6) { null }
            else List<Mark?>(9) { null }
        }
        val g = Game(cells = boards, forcedBoard = 2)
        assertEquals(listOf(0, 1, 3, 4, 5, 6, 7, 8), g.legalBoards)
        assertNull(requireNotNull(g.play(Move(4, 2))).forcedBoard)
    }

    @Test fun macroThreeBoardsWinsGame() {
        val boards = List(9) { index ->
            if (index in 0..2) listOf(Mark.X, Mark.X, Mark.X) + List<Mark?>(6) { null }
            else List<Mark?>(9) { null }
        }
        val g = Game(cells = boards)
        assertEquals(Outcome.X_WON, g.result)
        assertTrue(g.legalMoves.isEmpty())
    }

    @Test fun drawnBoardDoesNotCountAsWon() {
        val draw = listOf(Mark.X, Mark.O, Mark.X, Mark.X, Mark.O, Mark.O, Mark.O, Mark.X, Mark.X)
        val boards = List(9) { index ->
            when (index) {
                0 -> draw
                1, 2 -> listOf(Mark.X, Mark.X, Mark.X) + List<Mark?>(6) { null }
                else -> List<Mark?>(9) { null }
            }
        }
        assertEquals(Outcome.DRAW, Game.boardResult(draw))
        assertEquals(Outcome.ONGOING, Game(cells = boards).result)
    }

    @Test fun undoReplaysAndRestoresForcedBoard() {
        val a = requireNotNull(Game().play(Move(4, 6)))
        val b = requireNotNull(a.play(Move(6, 0)))
        val undone = requireNotNull(b.undo())
        assertEquals(1, undone.moves.size)
        assertEquals(Mark.O, undone.currentPlayer)
        assertEquals(6, undone.forcedBoard)
        assertNull(undone.cells[6][0])
    }

    @Test fun badIndicesAreRejected() {
        assertNull(Game().play(Move(-1, 1)))
        assertNull(Game().play(Move(0, 9)))
        assertTrue(Game().moves.isEmpty())
    }

    @Test fun actualWinningLineIsFound() {
        assertEquals(listOf(0, 1, 2),
            Game.winningLine(listOf(Mark.O, Mark.O, Mark.O, null, Mark.X, null, null, null, Mark.X)))
        assertEquals(listOf(0, 4, 8),
            Game.winningLine(listOf(Mark.X, Mark.O, null, Mark.O, Mark.X, null, null, null, Mark.X)))
        assertNull(Game.winningLine(List(9) { null }))
    }

    @Test fun allDifficultiesChooseOnlyLegalMoves() {
        val g = requireNotNull(Game().play(Move(4, 4)))
        for (difficulty in Difficulty.entries) {
            assertTrue(g.canPlay(requireNotNull(ComputerOpponent.chooseMove(g, difficulty))))
        }
    }

    @Test fun corruptedSavedMoveListCannotReplay() {
        assertNull(Game.replay(listOf(Move(0, 0), Move(8, 1))))
    }
}
