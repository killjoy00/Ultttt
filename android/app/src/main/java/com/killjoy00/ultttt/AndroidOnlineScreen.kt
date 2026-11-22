package com.killjoy00.ultttt

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Locale

/** Independent of local games: entering or leaving online play never erases the local board. */
@Composable
internal fun AndroidOnlineScreen(
    service: OnlineMatchService,
    playGames: AndroidPlayGames,
    onExit: () -> Unit
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var matches by remember { mutableStateOf(emptyList<OnlineMatch>()) }
    var selected by remember { mutableStateOf<OnlineMatch?>(null) }
    var invite by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var refreshNumber by remember { mutableIntStateOf(0) }

    fun accept(updated: OnlineMatch) {
        selected = updated
        matches = (listOf(updated) + matches.filterNot { it.id == updated.id })
        if (updated.didWin(service.userId)) playGames.recordOnlineWin(updated.id)
    }

    fun act(block: suspend () -> Unit) {
        if (busy) return
        busy = true
        scope.launch {
            try {
                block()
                error = null
            } catch (failure: Exception) {
                error = failure.localizedMessage ?: "Couldn't reach the online game service."
            } finally {
                busy = false
            }
        }
    }

    // Poll while the online screen is visible. Android Play Games no longer
    // supplies turn notifications; the player can also tap Refresh.
    LaunchedEffect(service.isConfigured, refreshNumber) {
        if (!service.isConfigured) {
            loading = false
            return@LaunchedEffect
        }
        while (true) {
            try {
                val fetched = service.listMatches()
                matches = fetched
                selected?.let { old ->
                    val current = fetched.firstOrNull { it.id == old.id } ?: service.getMatch(old.id)
                    if (current != null) {
                        selected = current
                        if (current.didWin(service.userId)) playGames.recordOnlineWin(current.id)
                    }
                }
            } catch (failure: Exception) {
                error = failure.localizedMessage ?: "Unable to refresh online games."
            }
            loading = false
            delay(15000)
        }
    }

    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(18.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("Play online", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text(
            "Take turns whenever you're ready. Your games are saved online.",
            style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center
        )

        if (!service.isConfigured) {
            Text(
                "Online play isn't active in this version yet. Your local games are still available.",
                style = MaterialTheme.typography.bodyMedium
            )
            Button(onClick = onExit) { Text("Back to game") }
            return@Column
        }

        error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        if (loading) Text("Connecting to online games…")

        if (selected != null) {
            val match = requireNotNull(selected)
            val myMark = match.myMark(service.userId)
            val canPlay = !busy && match.canPlay(service.userId)
            TextButton(onClick = { selected = null }) { Text("Back to my matches") }
            if (match.isWaiting) {
                Text("Waiting for another player to join.")
                Text("Share this invitation code:", fontWeight = FontWeight.SemiBold)
                Text(match.inviteCode, style = MaterialTheme.typography.headlineSmall)
                OutlinedButton(onClick = {
                    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    clipboard.setPrimaryClip(ClipData.newPlainText("Ultimate TTT invite", match.inviteCode))
                }) { Text("Copy invitation code") }
            } else {
                Text(
                    when {
                        match.isFinished -> when {
                            match.didWin(service.userId) -> "You won!"
                            match.winner == "DRAW" -> "It's a draw."
                            else -> "Match finished."
                        }
                        canPlay -> "Your turn — " + (myMark?.name ?: "")
                        else -> "Opponent's turn"
                    },
                    style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold
                )
                Text(
                    "You're " + (myMark?.name ?: "a spectator") +
                        "  ·  Move " + match.moves.size,
                    style = MaterialTheme.typography.bodyMedium
                )
                BoardGrid(
                    game = match.game, enabled = canPlay,
                    onMove = { move ->
                        act { accept(service.playMove(match, move)) }
                    }
                )
                if (!canPlay && !match.isFinished) {
                    Text("Open this screen again later to check for their move.")
                }
            }
            OutlinedButton(
                onClick = { refreshNumber++ },
                enabled = !busy
            ) { Text("Refresh match") }
        } else {
            Button(
                onClick = { act { accept(service.findOpponent()) } },
                enabled = !busy, modifier = Modifier.fillMaxWidth()
            ) { Text("Find an opponent") }
            OutlinedButton(
                onClick = { act { accept(service.createMatch()) } },
                enabled = !busy, modifier = Modifier.fillMaxWidth()
            ) { Text("Invite a friend") }

            Text("Have an invitation code?", style = MaterialTheme.typography.titleMedium)
            OutlinedTextField(
                value = invite,
                onValueChange = {
                    invite = it.filter { char -> char.isLetterOrDigit() }
                        .uppercase(Locale.US).take(12)
                },
                label = { Text("12-character invitation code") },
                singleLine = true, modifier = Modifier.fillMaxWidth()
            )
            Button(
                onClick = { act { accept(service.joinMatch(invite)) } },
                enabled = !busy && Regex("^[A-F0-9]{12}$").matches(invite),
                modifier = Modifier.fillMaxWidth()
            ) { Text("Join game") }

            if (matches.isNotEmpty()) {
                Spacer(Modifier.height(4.dp))
                Text("My games", style = MaterialTheme.typography.titleLarge)
                matches.forEach { match ->
                    val turn = when {
                        match.isWaiting -> "Waiting for an opponent"
                        match.isFinished -> if (match.didWin(service.userId)) "You won"
                            else if (match.winner == "DRAW") "Draw" else "Completed"
                        match.canPlay(service.userId) -> "Your turn"
                        else -> "Opponent's turn"
                    }
                    OutlinedButton(
                        onClick = { selected = match },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(horizontalAlignment = Alignment.Start) {
                            Text(turn, fontWeight = FontWeight.SemiBold)
                            Text(
                                "Move " + match.moves.size + " · " + match.inviteCode,
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                    }
                }
            } else if (!loading) {
                Text("No games yet. Find an opponent or invite a friend.")
            }

            TextButton(onClick = { refreshNumber++ }, enabled = !busy) {
                Text("Refresh my games")
            }
        }
        TextButton(onClick = onExit) { Text("Back to local game") }
    }
}
