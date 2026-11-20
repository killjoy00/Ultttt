package com.killjoy00.ultttt

/** Mirrors Sources/UltimateTTTCore/UltimateGame.swift; indices are zero-based. */
enum class Mark { X, O;
    val opponent: Mark get() = if (this == X) O else X
}
enum class Outcome { ONGOING, X_WON, O_WON, DRAW;
    val isFinished get() = this != ONGOING
    val winner: Mark? get() = when (this) {
        X_WON -> Mark.X
        O_WON -> Mark.O
        else -> null
    }
}
data class Move(val board: Int, val cell: Int)

/** Immutable state: a rejected move never modifies a board or its move history. */
data class Game(
    val cells: List<List<Mark?>> = List(9) { List(9) { null } },
    val currentPlayer: Mark = Mark.X,
    val forcedBoard: Int? = null,
    val moves: List<Move> = emptyList()
) {
    init {
        require(cells.size == 9 && cells.all { it.size == 9 })
    }

    val boardResults: List<Outcome> get() = cells.map(::boardResult)

    val result: Outcome get() {
        val owners = boardResults.map { it.winner }
        for (line in LINES) {
            val owner = owners[line[0]]
            if (owner != null && owners[line[1]] == owner && owners[line[2]] == owner)
                return outcomeFor(owner)
        }
        return if (boardResults.all { it.isFinished }) Outcome.DRAW else Outcome.ONGOING
    }

    val legalBoards: List<Int> get() {
        if (result.isFinished) return emptyList()
        val finished = boardResults
        if (forcedBoard in 0..8 && finished[forcedBoard!!] == Outcome.ONGOING)
            return listOf(forcedBoard)
        return (0..8).filter { finished[it] == Outcome.ONGOING }
    }

    val legalMoves: List<Move> get() =
        legalBoards.flatMap { board -> (0..8).filter { cells[board][it] == null }.map { Move(board, it) } }

    fun canPlay(move: Move): Boolean =
        move.board in 0..8 && move.cell in 0..8 &&
            move.board in legalBoards && cells[move.board][move.cell] == null

    /** Returns null for an illegal move. */
    fun play(move: Move): Game? {
        if (!canPlay(move)) return null
        val updated = cells.mapIndexed { b, board ->
            if (b != move.board) board else board.mapIndexed { c, mark ->
                if (c == move.cell) currentPlayer else mark
            }
        }
        val destination = move.cell
        val nextForced = if (boardResult(updated[destination]) == Outcome.ONGOING) destination else null
        return Game(updated, currentPlayer.opponent, nextForced, moves + move)
    }

    /** Mirrors iOS undo: rebuild from the remaining *legal* move history. */
    fun undo(): Game? = if (moves.isEmpty()) null else replay(moves.dropLast(1))

    companion object {
        val LINES = listOf(
            listOf(0, 1, 2), listOf(3, 4, 5), listOf(6, 7, 8),
            listOf(0, 3, 6), listOf(1, 4, 7), listOf(2, 5, 8),
            listOf(0, 4, 8), listOf(2, 4, 6)
        )

        fun winningLine(board: List<Mark?>): List<Int>? {
            if (board.size != 9) return null
            return LINES.firstOrNull { line ->
                board[line[0]] != null && board[line[0]] == board[line[1]] &&
                    board[line[1]] == board[line[2]]
            }
        }

        fun boardResult(board: List<Mark?>): Outcome {
            val line = winningLine(board)
            if (line != null) return outcomeFor(requireNotNull(board[line[0]]))
            return if (board.all { it != null }) Outcome.DRAW else Outcome.ONGOING
        }

        fun replay(moves: List<Move>): Game? {
            var game = Game()
            for (move in moves) game = game.play(move) ?: return null
            return game
        }

        private fun outcomeFor(mark: Mark) =
            if (mark == Mark.X) Outcome.X_WON else Outcome.O_WON
    }
}
