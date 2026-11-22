package com.killjoy00.ultttt

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

enum class GameMode { SOLO, TWO_PLAYER }
enum class Appearance { SYSTEM, LIGHT, DARK }

data class GameSession(
    val game: Game = Game(),
    val mode: GameMode = GameMode.SOLO,
    val difficulty: Difficulty = Difficulty.MEDIUM,
    val xWins: Int = 0,
    val oWins: Int = 0,
    val draws: Int = 0,
    val creditedFinishedGame: Boolean = false,
    val gameId: String = UUID.randomUUID().toString()
) {
    fun play(move: Move): GameSession? {
        val next = game.play(move) ?: return null
        val finished = next.result.isFinished
        return copy(
            game = next,
            xWins = xWins + if (finished && next.result == Outcome.X_WON) 1 else 0,
            oWins = oWins + if (finished && next.result == Outcome.O_WON) 1 else 0,
            draws = draws + if (finished && next.result == Outcome.DRAW) 1 else 0,
            creditedFinishedGame = finished
        )
    }

    fun newGame(nextMode: GameMode, nextDifficulty: Difficulty): GameSession =
        copy(game = Game(), mode = nextMode, difficulty = nextDifficulty,
            creditedFinishedGame = false, gameId = UUID.randomUUID().toString())

    fun undoTurn(): GameSession? {
        if (game.moves.isEmpty()) return null
        val undoCount =
            if (mode == GameMode.SOLO && game.currentPlayer == Mark.X && game.moves.size >= 2) 2 else 1
        val rewind = Game.replay(game.moves.dropLast(undoCount)) ?: return null
        val credit = creditedFinishedGame
        return copy(
            game = rewind,
            xWins = (xWins - if (credit && game.result == Outcome.X_WON) 1 else 0).coerceAtLeast(0),
            oWins = (oWins - if (credit && game.result == Outcome.O_WON) 1 else 0).coerceAtLeast(0),
            draws = (draws - if (credit && game.result == Outcome.DRAW) 1 else 0).coerceAtLeast(0),
            creditedFinishedGame = false
        )
    }
}

/** Local, offline-only storage. Saved state is reconstructed from legal moves. */
class LocalSessionStore(context: Context) {
    private val prefs = context.getSharedPreferences("ultimate-ttt-android-v1", Context.MODE_PRIVATE)

    fun load(): GameSession {
        val json = prefs.getString("session", null) ?: return GameSession()
        return try {
            val saved = JSONObject(json)
            val history = saved.getJSONArray("moves")
            val moves = (0 until history.length()).map { index ->
                val move = history.getJSONObject(index)
                Move(move.getInt("board"), move.getInt("cell"))
            }
            val game = Game.replay(moves) ?: return GameSession()
            GameSession(
                game = game,
                mode = enumValueOf(saved.optString("mode", "SOLO")),
                difficulty = enumValueOf(saved.optString("difficulty", "MEDIUM")),
                xWins = saved.optInt("xWins", 0).coerceAtLeast(0),
                oWins = saved.optInt("oWins", 0).coerceAtLeast(0),
                draws = saved.optInt("draws", 0).coerceAtLeast(0),
                creditedFinishedGame = game.result.isFinished && saved.optBoolean("creditedFinishedGame", false),
                gameId = saved.optString("gameId").ifBlank { UUID.randomUUID().toString() }
            )
        } catch (_: Exception) {
            GameSession()
        }
    }

    fun save(session: GameSession) {
        val history = JSONArray().apply {
            session.game.moves.forEach { move ->
                put(JSONObject().put("board", move.board).put("cell", move.cell))
            }
        }
        val json = JSONObject()
            .put("moves", history)
            .put("mode", session.mode.name)
            .put("difficulty", session.difficulty.name)
            .put("xWins", session.xWins)
            .put("oWins", session.oWins)
            .put("draws", session.draws)
            .put("creditedFinishedGame", session.creditedFinishedGame)
            .put("gameId", session.gameId)
        prefs.edit().putString("session", json.toString()).apply()
    }

    var appearance: Appearance
        get() = runCatching { enumValueOf<Appearance>(prefs.getString("appearance", "SYSTEM")!!) }
            .getOrDefault(Appearance.SYSTEM)
        set(value) { prefs.edit().putString("appearance", value.name).apply() }

    var tutorialCompleted: Boolean
        get() = prefs.getBoolean("tutorial-completed", false)
        set(value) { prefs.edit().putBoolean("tutorial-completed", value).apply() }
}
