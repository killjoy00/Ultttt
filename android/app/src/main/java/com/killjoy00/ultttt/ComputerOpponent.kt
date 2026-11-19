package com.killjoy00.ultttt

import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

enum class Difficulty { EASY, MEDIUM, HARD }

/** Port of iOS ComputerOpponent.swift: human X, computer O. */
object ComputerOpponent {
    fun chooseMove(game: Game, difficulty: Difficulty, random: Random = Random.Default): Move? {
        if (game.currentPlayer != Mark.O) return null
        val legal = game.legalMoves
        if (legal.isEmpty()) return null
        if (difficulty == Difficulty.EASY) return legal.random(random)
        if (difficulty == Difficulty.MEDIUM) {
            return legal.maxByOrNull { move ->
                evaluate(requireNotNull(game.play(move))) + random.nextDouble(-7.0, 7.0)
            }
        }
        val roots = orderedMoves(game, if (legal.size > 18) 18 else legal.size)
        var best = roots.first()
        var bestScore = Double.NEGATIVE_INFINITY
        var alpha = Double.NEGATIVE_INFINITY
        val budget = intArrayOf(6000)
        for (move in roots) {
            val candidate = minimax(requireNotNull(game.play(move)), 2, alpha, Double.POSITIVE_INFINITY, budget)
            if (candidate > bestScore) {
                bestScore = candidate
                best = move
            }
            alpha = max(alpha, bestScore)
        }
        return best
    }

    private fun orderedMoves(game: Game, limit: Int): List<Move> {
        val maximizing = game.currentPlayer == Mark.O
        return game.legalMoves.sortedWith(
            compareByDescending<Move> { move ->
                val score = evaluate(requireNotNull(game.play(move)))
                if (maximizing) score else -score
            }.thenBy { it.board }.thenBy { it.cell }
        ).take(limit)
    }

    private fun minimax(game: Game, depth: Int, alpha: Double, beta: Double, budget: IntArray): Double {
        budget[0]--
        if (depth == 0 || game.result.isFinished || budget[0] <= 0) return evaluate(game)
        val maximizing = game.currentPlayer == Mark.O
        var low = alpha
        var high = beta
        var best = if (maximizing) Double.NEGATIVE_INFINITY else Double.POSITIVE_INFINITY
        for (move in orderedMoves(game, if (depth == 2) 10 else 8)) {
            val value = minimax(requireNotNull(game.play(move)), depth - 1, low, high, budget)
            if (maximizing) {
                best = max(best, value)
                low = max(low, best)
            } else {
                best = min(best, value)
                high = min(high, best)
            }
            if (high <= low || budget[0] <= 0) break
        }
        return if (best.isFinite()) best else evaluate(game)
    }

    private fun evaluate(game: Game): Double {
        when (game.result) {
            Outcome.O_WON -> return 1_000_000.0
            Outcome.X_WON -> return -1_000_000.0
            Outcome.DRAW -> return 0.0
            Outcome.ONGOING -> Unit
        }
        val results = game.boardResults
        val weights = listOf(1.3, 1.0, 1.3, 1.0, 1.6, 1.0, 1.3, 1.0, 1.3)
        var score = 0.0
        for (board in 0..8) {
            val weight = weights[board]
            when (results[board]) {
                Outcome.O_WON -> score += 80 * weight
                Outcome.X_WON -> score -= 80 * weight
                Outcome.DRAW -> Unit
                Outcome.ONGOING -> for (line in Game.LINES) {
                    val marks = line.mapNotNull { game.cells[board][it] }
                    val os = marks.count { it == Mark.O }
                    val xs = marks.size - os
                    if (os > 0 && xs > 0) continue
                    if (os > 0) score += (if (os == 2) 12.0 else 1.6) * weight
                    if (xs > 0) score -= (if (xs == 2) 14.0 else 1.6) * weight
                }
            }
        }
        for (line in Game.LINES) {
            val boards = line.map { results[it] }
            val os = boards.count { it == Outcome.O_WON }
            val xs = boards.count { it == Outcome.X_WON }
            if (Outcome.DRAW in boards || (os > 0 && xs > 0)) continue
            if (os > 0) score += if (os == 2) 360.0 else 32.0
            if (xs > 0) score -= if (xs == 2) 390.0 else 35.0
        }
        val forced = game.forcedBoard
        if (forced != null && results[forced] == Outcome.ONGOING &&
            game.cells[forced].count { it == null } <= 2) {
            score += if (game.currentPlayer == Mark.O) -2.0 else 2.0
        }
        return score
    }
}
