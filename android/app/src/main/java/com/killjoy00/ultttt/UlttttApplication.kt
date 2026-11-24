package com.killjoy00.ultttt

import android.app.Application
import android.util.Log
import com.google.android.gms.games.PlayGamesSdk

/** Follow the Play Games v2 startup lifecycle; local play never depends on it. */
class UlttttApplication : Application() {
    var playGamesInitialized = false
        private set
    var playGamesInitializationStatus = "Not initialized"
        private set

    override fun onCreate() {
        super.onCreate()
        initializePlayGames()
    }

    fun initializePlayGames(): Boolean {
        if (!BuildConfig.PLAY_GAMES_CONFIGURED) {
            playGamesInitializationStatus = "Disabled in this build"
            return false
        }
        if (playGamesInitialized) return true
        try {
            PlayGamesSdk.initialize(this)
            playGamesInitialized = true
            playGamesInitializationStatus = "Initialized"
        } catch (error: Exception) {
            playGamesInitializationStatus = "Initialization failed: " + error.javaClass.simpleName
        }
        Log.i("ULTTT.PlayGames", playGamesInitializationStatus)
        return playGamesInitialized
    }
}
