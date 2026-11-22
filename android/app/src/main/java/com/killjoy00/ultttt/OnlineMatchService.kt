package com.killjoy00.ultttt

import android.content.Context
import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.SecureRandom
import java.util.Locale

/**
 * Neon Functions handle multiplayer validation and store moves in private PostgreSQL.
 * Android sends only a per-install random guest bearer token; no database key is bundled.
 * The Neon Function hashes that token and returns only "self"/"opponent" aliases.
 */
class OnlineMatchService(context: Context) {
    private val preferences = context.applicationContext
        .getSharedPreferences("ultttt-neon-guest-v1", Context.MODE_PRIVATE)
    private val lock = Any()

    val isConfigured: Boolean get() = BuildConfig.ONLINE_CONFIGURED
    val userId: String get() = "self" // Alias from the backend, never the underlying guest credential.

    suspend fun createMatch(): OnlineMatch = withContext(Dispatchers.IO) {
        parseMatch(request("/matches/create", "POST", JSONObject()))
    }

    suspend fun findOpponent(): OnlineMatch = withContext(Dispatchers.IO) {
        parseMatch(request("/matches/find", "POST", JSONObject()))
    }

    suspend fun joinMatch(code: String): OnlineMatch = withContext(Dispatchers.IO) {
        val normalized = code.trim().uppercase(Locale.US)
        require(Regex("^[0-9A-F]{12}$").matches(normalized)) {
            "Invitation codes must contain twelve hexadecimal characters."
        }
        parseMatch(request("/matches/join", "POST", JSONObject().put("invite_code", normalized)))
    }

    suspend fun playMove(match: OnlineMatch, move: Move): OnlineMatch = withContext(Dispatchers.IO) {
        require(match.game.canPlay(move)) { "That square isn't available." }
        require(match.canPlay(userId)) { "It isn't your turn." }
        parseMatch(request("/matches/move", "POST", JSONObject()
            .put("match_id", match.id)
            .put("board", move.board)
            .put("cell", move.cell)
            .put("expected_moves", match.moves.size)))
    }

    suspend fun listMatches(): List<OnlineMatch> = withContext(Dispatchers.IO) {
        val matches = JSONArray(request("/matches", "GET", null))
        (0 until matches.length()).map { OnlineMatch.fromJson(matches.getJSONObject(it)) }
    }

    suspend fun getMatch(id: String): OnlineMatch? = withContext(Dispatchers.IO) {
        require(Regex("^[0-9a-fA-F-]{36}$").matches(id)) { "Invalid match identifier" }
        try {
            parseMatch(request("/matches/" + id, "GET", null))
        } catch (failure: BackendException) {
            if (failure.status == 404) null else throw failure
        }
    }

    private fun parseMatch(response: String): OnlineMatch =
        OnlineMatch.fromJson(JSONObject(response))

    /** A 256-bit bearer credential is generated once, kept private, and never placed in URLs. */
    private fun guestToken(): String = synchronized(lock) {
        val existing = preferences.getString("guest_token", null)
        if (existing != null && Regex("^[a-zA-Z0-9_-]{43}$").matches(existing))
            return@synchronized existing
        val bytes = ByteArray(32)
        SecureRandom().nextBytes(bytes)
        val token = Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
        preferences.edit().putString("guest_token", token).apply()
        token
    }

    private fun request(path: String, method: String, body: JSONObject?): String {
        check(isConfigured) { "Online multiplayer is not active in this build." }
        val url = URL(BuildConfig.ONLINE_NEON_FUNCTION_URL.trimEnd('/') + path)
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 15000
            readTimeout = 15000
            setRequestProperty("Authorization", "Bearer " + guestToken())
            setRequestProperty("Accept", "application/json")
            if (body != null) {
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
            }
        }
        return try {
            if (body != null) {
                connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            }
            val status = connection.responseCode
            val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            val result = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            if (status !in 200..299) {
                val message = runCatching { JSONObject(result).optString("error") }
                    .getOrDefault("").ifBlank { "Online play is unavailable ($status)." }
                throw BackendException(status, message)
            }
            result
        } finally {
            connection.disconnect()
        }
    }
}

private class BackendException(val status: Int, message: String) : IOException(message)

/** Reconstruct online boards from server-checked moves. No guest secret or player hash is exposed. */
data class OnlineMatch(
    val id: String,
    val inviteCode: String,
    val playerX: String,
    val playerO: String?,
    val moves: List<Move>,
    val status: String,
    val winner: String?,
    val updatedAt: String
) {
    val game: Game get() = requireNotNull(Game.replay(moves)) { "Invalid saved match moves." }
    val isWaiting: Boolean get() = status == "waiting"
    val isFinished: Boolean get() = status == "finished"

    fun myMark(userId: String?): Mark? = when (userId) {
        playerX -> Mark.X
        playerO -> if (playerO != null) Mark.O else null
        else -> null
    }

    fun canPlay(userId: String?): Boolean =
        status == "active" && myMark(userId) == game.currentPlayer && !game.result.isFinished

    fun didWin(userId: String?): Boolean =
        isFinished && ((winner == "X" && userId == playerX) ||
            (winner == "O" && userId == playerO))

    companion object {
        fun fromJson(json: JSONObject): OnlineMatch {
            val history = json.getJSONArray("moves")
            val moves = (0 until history.length()).map { index ->
                val move = history.getJSONObject(index)
                Move(move.getInt("board"), move.getInt("cell"))
            }
            val match = OnlineMatch(
                id = json.getString("id"),
                inviteCode = json.getString("invite_code"),
                playerX = json.getString("player_x"),
                playerO = if (json.isNull("player_o")) null else json.getString("player_o"),
                moves = moves,
                status = json.getString("status"),
                winner = if (json.isNull("winner")) null else json.getString("winner"),
                updatedAt = json.optString("updated_at")
            )
            require(match.game.moves.size == moves.size) { "Corrupt match history." }
            require(match.status in setOf("waiting", "active", "finished"))
            require(setOf(match.playerX, match.playerO).contains("self")) {
                "Backend returned a match not belonging to this guest."
            }
            return match
        }
    }
}
