package com.killjoy00.ultttt

import android.content.ClipData
import android.content.ClipboardManager
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.games.AuthenticationResult
import com.google.android.gms.games.GamesClientStatusCodes
import com.google.android.gms.games.PlayGames
import com.google.android.gms.tasks.Task
import java.security.MessageDigest

/**
 * Google Play Games Services v2 is for platform achievements and leaderboards,
 * not multiplayer or game-account authentication.
 *
 * Progress is stored before requesting a network update so offline wins can
 * be synchronized on the next successful Play Games authentication.
 */
class AndroidPlayGames(private val activity: ComponentActivity) {
    private val prefs = activity.getSharedPreferences("ultttt-play-games-v1", 0)
    private val app get() = activity.application as? UlttttApplication
    private val active get() = !activity.isDestroyed && !activity.isFinishing
    private var requestEpoch = 0

    var checkingAuthentication by mutableStateOf(false)
        private set
    var automaticStatus by mutableStateOf("Not checked")
        private set
    var manualStatus by mutableStateOf("Not attempted")
        private set
    var playerApiStatus by mutableStateOf("Not checked")
        private set

    var isAuthenticated by mutableStateOf(false)
        private set
    var signInInProgress by mutableStateOf(false)
        private set
    var message by mutableStateOf<String?>(null)
        private set

    val isConfigured: Boolean get() = BuildConfig.PLAY_GAMES_CONFIGURED
    val soloWins: Int get() = prefs.getStringSet("solo_game_ids", emptySet())?.size ?: 0
    val onlineWins: Int get() = prefs.getStringSet("online_match_ids", emptySet())?.size ?: 0

    private fun ensureInitialized(): Boolean =
        app?.initializePlayGames() == true

    fun refreshAuthentication() {
        if (!active || !isConfigured || signInInProgress || checkingAuthentication) return
        if (!ensureInitialized()) {
            automaticStatus = app?.playGamesInitializationStatus ?: "Application setup missing"
            return
        }
        val epoch = requestEpoch
        checkingAuthentication = true
        try {
            PlayGames.getGamesSignInClient(activity).isAuthenticated()
                .addOnCompleteListener { task ->
                    if (!active || epoch != requestEpoch) return@addOnCompleteListener
                    checkingAuthentication = false
                    automaticStatus = describeAuthentication(task)
                    isAuthenticated = task.isSuccessful && task.result.isAuthenticated
                    Log.i("ULTTT.PlayGames", "Automatic: " + automaticStatus)
                    if (isAuthenticated) {
                        syncProgress()
                    }
                }
        } catch (error: Exception) {
            checkingAuthentication = false
            automaticStatus = describeError(error)
            isAuthenticated = false
            Log.w("ULTTT.PlayGames", "Automatic: " + automaticStatus)
        }
    }

    /**
     * The user can retry after automatic authentication fails. Listen without an
     * Activity-scoped Task listener: Google's UI may stop the Activity temporarily.
     * Ignore stale results after a new attempt or Activity destruction.
     */
    fun signIn(onSuccess: () -> Unit = {}) {
        if (!active) return
        if (!isConfigured) {
            message = "Google Play Games has not been configured for this build."
            return
        }
        if (!ensureInitialized()) {
            manualStatus = app?.playGamesInitializationStatus ?: "Application setup missing"
            message = "Google Play Games could not start. " + manualStatus
            return
        }
        if (isAuthenticated) {
            onSuccess()
            return
        }
        if (signInInProgress) return
        val epoch = ++requestEpoch
        checkingAuthentication = false
        signInInProgress = true
        manualStatus = "Connecting..."
        playerApiStatus = "Not checked"
        message = null
        try {
            PlayGames.getGamesSignInClient(activity).signIn()
                .addOnCompleteListener { task ->
                    if (!active || epoch != requestEpoch) return@addOnCompleteListener
                    signInInProgress = false
                    manualStatus = describeAuthentication(task)
                    isAuthenticated = task.isSuccessful && task.result.isAuthenticated
                    Log.i("ULTTT.PlayGames", "Manual: " + manualStatus)
                    if (isAuthenticated) {
                        syncProgress()
                        onSuccess()
                    } else {
                        message = failedSignInMessage()
                        probePlayerApi(epoch)
                    }
                }
        } catch (error: Exception) {
            signInInProgress = false
            manualStatus = describeError(error)
            Log.w("ULTTT.PlayGames", "Manual: " + manualStatus)
            message = failedSignInMessage()
            probePlayerApi(epoch)
        }
    }

    // The sign-in Task may return false without an exception. A separate read-only
    // Games API request can expose the real status code. Never store or log player IDs.
    private fun probePlayerApi(epoch: Int) {
        playerApiStatus = "Checking..."
        try {
            PlayGames.getPlayersClient(activity).getCurrentPlayerId()
                .addOnCompleteListener { task ->
                    if (!active || epoch != requestEpoch) return@addOnCompleteListener
                    playerApiStatus = when {
                        task.isSuccessful -> "Player API responded successfully"
                        task.isCanceled -> "Canceled"
                        else -> describeError(task.exception)
                    }
                    Log.i("ULTTT.PlayGames", "Player API: " + playerApiStatus)
                    if (!isAuthenticated && message != null) message = failedSignInMessage()
                }
        } catch (error: Exception) {
            playerApiStatus = describeError(error)
            Log.w("ULTTT.PlayGames", "Player API: " + playerApiStatus)
            if (!isAuthenticated && message != null) message = failedSignInMessage()
        }
    }

    private fun describeAuthentication(task: Task<AuthenticationResult>): String = when {
        task.isSuccessful && task.result.isAuthenticated -> "Authenticated"
        task.isSuccessful -> "Completed, authenticated=false"
        task.isCanceled -> "Canceled"
        else -> describeError(task.exception)
    }

    private fun describeError(error: Exception?): String = when (error) {
        is ApiException -> GamesClientStatusCodes.getStatusCodeString(error.statusCode) +
            " (" + error.statusCode + ")"
        null -> "No exception supplied"
        else -> error.javaClass.simpleName
    }

    private fun servicesStatus(): String = runCatching {
        val availability = GoogleApiAvailability.getInstance()
        val code = availability.isGooglePlayServicesAvailable(activity)
        availability.getErrorString(code) + " (" + code + ")"
    }.getOrDefault("Unavailable")

    @Suppress("DEPRECATION")
    private fun installedAppDetails(): String {
        val manager = activity.packageManager
        val pkg = activity.packageName
        val signing = runCatching {
            val flags = if (Build.VERSION.SDK_INT >= 28)
                PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
            val info = manager.getPackageInfo(pkg, flags)
            val signatures = if (Build.VERSION.SDK_INT >= 28)
                info.signingInfo?.apkContentsSigners else info.signatures
            signatures?.joinToString(", ") { signature ->
                MessageDigest.getInstance("SHA-1").digest(signature.toByteArray())
                    .joinToString(":") { "%02X".format(it.toInt() and 0xff) }
            } ?: "Unknown"
        }.getOrDefault("Unknown")
        val installer = runCatching {
            if (Build.VERSION.SDK_INT >= 30)
                manager.getInstallSourceInfo(pkg).installingPackageName
            else manager.getInstallerPackageName(pkg)
        }.getOrNull() ?: "Unknown"
        val manifestId = runCatching {
            val metadata = manager.getApplicationInfo(pkg, PackageManager.GET_META_DATA).metaData
            val value = metadata?.get("com.google.android.gms.games.APP_ID")
            when (value) {
                is Int -> runCatching { activity.getString(value) }.getOrDefault(value.toString())
                null -> "Missing"
                else -> value.toString()
            }
        }.getOrDefault("Unreadable")
        val resourceId = runCatching { activity.getString(R.string.game_services_project_id) }
            .getOrDefault("Unreadable")
        return listOf(
            "ULTTT " + BuildConfig.VERSION_NAME + " (" + BuildConfig.VERSION_CODE + ")",
            "Package: " + pkg,
            "Installer: " + installer,
            "Installed signing SHA-1: " + signing,
            "Project ID (expected): " + BuildConfig.PLAY_GAMES_PROJECT_ID,
            "Project ID (manifest): " + manifestId,
            "Project ID (resource): " + resourceId
        ).joinToString("\n")
    }

    private fun failedSignInMessage(): String =
        "Google Play Games did not connect.\n\n" +
            "Sign-in: " + manualStatus + "\n" +
            "Player API: " + playerApiStatus + "\n" +
            "Play services: " + servicesStatus() +
            "\n\nCopy sign-in details from Statistics for troubleshooting."

    fun copyDiagnostics() {
        val report = installedAppDetails() + "\n" + listOf(
            "SDK startup: " + (app?.playGamesInitializationStatus ?: "Application setup missing"),
            "Google Play services: " + servicesStatus(),
            "Automatic check: " + automaticStatus,
            "Manual sign-in: " + manualStatus,
            "Player API: " + playerApiStatus
        ).joinToString("\n")
        activity.getSystemService(ClipboardManager::class.java)
            ?.setPrimaryClip(ClipData.newPlainText("ULTTT Play Games diagnostics", report))
        Toast.makeText(activity, "Sign-in details copied", Toast.LENGTH_SHORT).show()
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
            .addOnSuccessListener { if (active) activity.startActivityForResult(it, 9021) }
            .addOnFailureListener { if (active) message = "Achievements are unavailable: " + describeError(it) }
    }

    fun showLeaderboards() {
        if (!readyToShow { showLeaderboards() }) return
        if (BuildConfig.PGS_ONLINE_WINS_LEADERBOARD_ID.isBlank()) {
            message = "The online wins leaderboard has not been configured yet."
            return
        }
        PlayGames.getLeaderboardsClient(activity)
            .getLeaderboardIntent(BuildConfig.PGS_ONLINE_WINS_LEADERBOARD_ID)
            .addOnSuccessListener { if (active) activity.startActivityForResult(it, 9022) }
            .addOnFailureListener { if (active) message = "The leaderboard is unavailable: " + describeError(it) }
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
