package com.killjoy00.ultttt

import androidx.activity.ComponentActivity
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.android.gms.games.PlayGames
import com.google.android.gms.games.PlayGamesSdk

/**
 * Google Play Games Services v2 is for platform achievements and leaderboards,
 * not multiplayer or game-account authentication.
 *
 * Progress is stored before requesting a network update so offline wins can
 * be synchronized on the next successful Play Games authentication.
 */
class AndroidPlayGames(private val activity: ComponentActivity) {
    private val prefs = activity.getSharedPreferences("ultttt-play-games-v1", 0)
    private var initialized = false

    var isAuthenticated by mutableStateOf(false)
        private set
    var signInInProgress by mutableStateOf(false)
        private set
    var message by mutableStateOf<String?>(null)
        private set

    val isConfigured: Boolean get() = BuildConfig.PLAY_GAMES_CONFIGURED
    val soloWins: Int get() = prefs.getStringSet("solo_game_ids", emptySet())?.size ?: 0
    val onlineWins: Int get() = prefs.getStringSet("online_match_ids", emptySet())?.size ?: 0

    fun initializeAfterTutorial() {
        if (!isConfigured || initialized) return
        initialized = true
        try {
            PlayGamesSdk.initialize(activity)
            refreshAuthentication()
        } catch (error: Exception) {
            initialized = false
            message = "Google Play Games could not start: ${error.localizedMessage}"
        }
    }

    fun refreshAuthentication() {
        if (!initialized) return
        PlayGames.getGamesSignInClient(activity).isAuthenticated()
            .addOnCompleteListener(activity) { task ->
                isAuthenticated = task.isSuccessful && task.result.isAuthenticated
                if (isAuthenticated) syncProgress()
            }
    }

    /**
     * Automatic Play Games authentication can fail or be disabled on a device.
     * Give the player a deliberate retry rather than only checking isAuthenticated().
     */
    fun signIn(onSuccess: () -> Unit = {}) {
        if (!isConfigured) {
            message = "Google Play Games has not been configured for this build."
            return
        }
        if (!initialized) {
            message = "Finish the tutorial before connecting to Google Play Games."
            return
        }
        if (isAuthenticated) {
            onSuccess()
            return
        }
        if (signInInProgress) return
        signInInProgress = true
        message = null
        try {
            PlayGames.getGamesSignInClient(activity).signIn()
                .addOnCompleteListener(activity) { task ->
                    signInInProgress = false
                    isAuthenticated = task.isSuccessful && task.result.isAuthenticated
                    if (isAuthenticated) {
                        syncProgress()
                        onSuccess()
                    } else {
                        val detail = task.exception?.localizedMessage?.takeIf { it.isNotBlank() }
                        message = if (detail == null)
                            "Google Play Games sign-in did not finish. Check your Play Games account and try again."
                        else "Google Play Games sign-in failed: $detail"
                    }
                }
        } catch (error: Exception) {
            signInInProgress = false
            message = "Google Play Games sign-in could not start: ${error.localizedMessage}"
        }
    }

    /** Deduplicate per saved solo game, including undo/re-win of the same game. */
    fun recordSoloWin(gameId: String) {
        saveUnique("solo_game_ids", gameId)
        syncProgress()
    }

    /** Called once when an authenticated online match is confirmed complete. */
    fun recordOnlineWin(matchId: String) {
        saveUnique("online_match_ids", matchId)
        syncProgress()
    }

    private fun saveUnique(key: String, value: String) {
        if (value.isBlank()) return
        val ids = (prefs.getStringSet(key, emptySet()) ?: emptySet()).toMutableSet()
        if (ids.add(value)) prefs.edit().putStringSet(key, ids).apply()
    }

    private fun syncProgress() {
        if (!isConfigured || !isAuthenticated) return
        val achievements = PlayGames.getAchievementsClient(activity)
        val solos = soloWins
        val online = onlineWins
        if (solos >= 1 && BuildConfig.PGS_FIRST_WIN_ID.isNotBlank())
            achievements.unlock(BuildConfig.PGS_FIRST_WIN_ID)
        if (solos >= 5 && BuildConfig.PGS_FIVE_WINS_ID.isNotBlank())
            achievements.unlock(BuildConfig.PGS_FIVE_WINS_ID)
        if (solos >= 10 && BuildConfig.PGS_TEN_WINS_ID.isNotBlank())
            achievements.unlock(BuildConfig.PGS_TEN_WINS_ID)
        if (online >= 1 && BuildConfig.PGS_FIRST_ONLINE_WIN_ID.isNotBlank())
            achievements.unlock(BuildConfig.PGS_FIRST_ONLINE_WIN_ID)
        if (online >= 25 && BuildConfig.PGS_TWENTY_FIVE_ONLINE_WINS_ID.isNotBlank())
            achievements.unlock(BuildConfig.PGS_TWENTY_FIVE_ONLINE_WINS_ID)
        if (online > 0 && BuildConfig.PGS_ONLINE_WINS_LEADERBOARD_ID.isNotBlank()) {
            PlayGames.getLeaderboardsClient(activity).submitScore(
                BuildConfig.PGS_ONLINE_WINS_LEADERBOARD_ID, online.toLong()
            )
        }
    }

    fun showAchievements() {
        if (!readyToShow { showAchievements() }) return
        PlayGames.getAchievementsClient(activity).getAchievementsIntent()
            .addOnSuccessListener { activity.startActivityForResult(it, 9021) }
            .addOnFailureListener { message = "Achievements are unavailable: ${it.localizedMessage}" }
    }

    fun showLeaderboards() {
        if (!readyToShow { showLeaderboards() }) return
        if (BuildConfig.PGS_ONLINE_WINS_LEADERBOARD_ID.isBlank()) {
            message = "The online wins leaderboard has not been configured yet."
            return
        }
        PlayGames.getLeaderboardsClient(activity)
            .getLeaderboardIntent(BuildConfig.PGS_ONLINE_WINS_LEADERBOARD_ID)
            .addOnSuccessListener { activity.startActivityForResult(it, 9022) }
            .addOnFailureListener { message = "The leaderboard is unavailable: ${it.localizedMessage}" }
    }

    private fun readyToShow(onAuthenticated: () -> Unit): Boolean {
        if (!isConfigured) {
            message = "Google Play Games has not been configured for this build."
            return false
        }
        if (!isAuthenticated) {
            signIn(onAuthenticated)
            return false
        }
        return true
    }

    fun clearMessage() { message = null }
}
