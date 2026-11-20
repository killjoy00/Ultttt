package com.killjoy00.ultttt

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlin.math.roundToInt

private val Teal = Color(0xFF18B8A8)
private val DeepTeal = Color(0xFF087F76)
private val Coral = Color(0xFFF37B70)
private val Midnight = Color(0xFF111E30)
private val LightBackground = Color(0xFFF5F7F6)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val store = LocalSessionStore(applicationContext)
        setContent { UltimateApp(store) }
    }
}

@Composable
private fun UltimateApp(store: LocalSessionStore) {
    var session by remember { mutableStateOf(store.load()) }
    var appearance by remember { mutableStateOf(store.appearance) }
    var showNewGame by remember { mutableStateOf(false) }
    var showStatistics by remember { mutableStateOf(false) }
    var showSettings by remember { mutableStateOf(false) }
    var tutorialStep by remember { mutableIntStateOf(if (store.tutorialCompleted) -1 else 0) }
    var replaying by remember { mutableStateOf(false) }
    var replayIndex by remember { mutableIntStateOf(0) }

    fun update(next: GameSession) {
        session = next
        store.save(next)
    }

    // Only computers play O, and invalidated effects never submit stale moves.
    LaunchedEffect(session.game.moves, session.mode, session.difficulty) {
        val snapshot = session
        if (snapshot.mode == GameMode.SOLO &&
            snapshot.game.currentPlayer == Mark.O &&
            snapshot.game.result == Outcome.ONGOING
        ) {
            delay(300)
            val candidate = withContext(Dispatchers.Default) {
                ComputerOpponent.chooseMove(snapshot.game, snapshot.difficulty)
            }
            if (candidate != null && session == snapshot) {
                snapshot.play(candidate)?.let(::update)
            }
        }
    }

    val isDark = when (appearance) {
        Appearance.SYSTEM -> isSystemInDarkTheme()
        Appearance.LIGHT -> false
        Appearance.DARK -> true
    }
    val scheme = if (isDark) darkColorScheme(
        primary = Teal, secondary = Coral, background = Midnight,
        surface = Color(0xFF1B2B3E), onSurface = Color.White, onBackground = Color.White
    ) else lightColorScheme(
        primary = DeepTeal, secondary = Color(0xFFBC514B),
        background = LightBackground, surface = Color.White,
        onSurface = Color(0xFF152736), onBackground = Color(0xFF152736)
    )
    MaterialTheme(colorScheme = scheme) {
        Surface(modifier = Modifier.fillMaxSize(), color = scheme.background) {
            if (replaying) {
                val replay = Game.replay(session.game.moves.take(replayIndex)) ?: Game()
                Column(
                    Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(18.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text("Game replay", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(14.dp))
                    BoardGrid(replay, enabled = false, onMove = {})
                    Spacer(Modifier.height(14.dp))
                    Text("Move " + replayIndex + " of " + session.game.moves.size)
                    Slider(
                        value = replayIndex.toFloat(),
                        onValueChange = { replayIndex = it.roundToInt() },
                        valueRange = 0f..session.game.moves.size.toFloat(),
                        steps = (session.game.moves.size - 1).coerceAtLeast(0)
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        OutlinedButton(onClick = { replayIndex = (replayIndex - 1).coerceAtLeast(0) }) {
                            Text("Previous")
                        }
                        OutlinedButton(onClick = {
                            replayIndex = (replayIndex + 1).coerceAtMost(session.game.moves.size)
                        }) { Text("Next") }
                    }
                    Button(onClick = { replaying = false }) { Text("Back to game") }
                }
            } else {
                Column(
                    Modifier.fillMaxSize().verticalScroll(rememberScrollState())
                        .padding(horizontal = 16.dp, vertical = 18.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text("ULTIMATE", color = MaterialTheme.colorScheme.primary,
                        fontSize = 13.sp, letterSpacing = 3.sp, fontWeight = FontWeight.Bold)
                    Text("Tic/Tac/Toe", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(8.dp))
                    val thinking = session.mode == GameMode.SOLO &&
                        session.game.currentPlayer == Mark.O && session.game.result == Outcome.ONGOING
                    val heading = when (session.game.result) {
                        Outcome.X_WON -> "X wins the game!"
                        Outcome.O_WON -> "O wins the game!"
                        Outcome.DRAW -> "It's a draw."
                        Outcome.ONGOING -> if (thinking) "Computer is thinking..." else
                            if (session.game.currentPlayer == Mark.X) "X to play" else "O to play"
                    }
                    Text(heading, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(4.dp))
                    val forcedDestination = session.game.forcedBoard
                    Text(
                        if (session.game.result.isFinished) "Start another game or replay your moves."
                        else if (forcedDestination != null &&
                            session.game.legalBoards.size == 1) {
                            "Play in highlighted board " + (forcedDestination + 1)
                        } else "Free choice: play in any open board.",
                        style = MaterialTheme.typography.bodySmall,
                        textAlign = TextAlign.Center
                    )
                    Spacer(Modifier.height(14.dp))
                    BoardGrid(
                        game = session.game,
                        enabled = !thinking && !session.game.result.isFinished,
                        onMove = { move -> session.play(move)?.let(::update) }
                    )
                    Spacer(Modifier.height(16.dp))
                    Text(
                        if (session.mode == GameMode.SOLO)
                            "Vs computer  ·  " + session.difficulty.name.lowercase().replaceFirstChar { it.uppercase() }
                        else "Two players  ·  pass and play",
                        style = MaterialTheme.typography.labelLarge
                    )
                    Text(
                        "X wins: " + session.xWins + "   O wins: " + session.oWins + "   Draws: " + session.draws,
                        style = MaterialTheme.typography.bodyMedium
                    )
                    Spacer(Modifier.height(12.dp))
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Button(onClick = { showNewGame = true }, modifier = Modifier.weight(1f)) { Text("New game") }
                        OutlinedButton(
                            onClick = { session.undoTurn()?.let(::update) },
                            enabled = session.game.moves.isNotEmpty() && !thinking,
                            modifier = Modifier.weight(1f)
                        ) { Text("Undo") }
                    }
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        OutlinedButton(onClick = { showStatistics = true }, modifier = Modifier.weight(1f)) {
                            Text("Statistics")
                        }
                        OutlinedButton(onClick = { showSettings = true }, modifier = Modifier.weight(1f)) {
                            Text("Settings")
                        }
                    }
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        TextButton(onClick = { tutorialStep = 0 }, modifier = Modifier.weight(1f)) {
                            Text("How to play")
                        }
                        TextButton(
                            onClick = { replayIndex = session.game.moves.size; replaying = true },
                            enabled = session.game.moves.isNotEmpty(),
                            modifier = Modifier.weight(1f)
                        ) { Text("Replay") }
                    }
                    Text("Play offline. Online games and ads are not yet enabled.",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
                }
            }
        }

        if (showNewGame) {
            var nextMode by remember { mutableStateOf(session.mode) }
            var nextDifficulty by remember { mutableStateOf(session.difficulty) }
            AlertDialog(
                onDismissRequest = { showNewGame = false },
                title = { Text("New game") },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("Who are you playing?")
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            FilterChip(
                                selected = nextMode == GameMode.SOLO,
                                onClick = { nextMode = GameMode.SOLO },
                                label = { Text("Computer") }
                            )
                            FilterChip(
                                selected = nextMode == GameMode.TWO_PLAYER,
                                onClick = { nextMode = GameMode.TWO_PLAYER },
                                label = { Text("Two players") }
                            )
                        }
                        if (nextMode == GameMode.SOLO) {
                            Text("Computer difficulty")
                            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                Difficulty.entries.forEach { level ->
                                    FilterChip(
                                        selected = nextDifficulty == level,
                                        onClick = { nextDifficulty = level },
                                        label = { Text(level.name.lowercase().replaceFirstChar { it.uppercase() }) }
                                    )
                                }
                            }
                        }
                        Text("Starting a new game keeps your saved win totals.",
                            style = MaterialTheme.typography.bodySmall)
                    }
                },
                confirmButton = {
                    Button(onClick = {
                        update(session.newGame(nextMode, nextDifficulty))
                        showNewGame = false
                    }) { Text("Play") }
                },
                dismissButton = { TextButton(onClick = { showNewGame = false }) { Text("Cancel") } }
            )
        }

        if (showStatistics) AlertDialog(
            onDismissRequest = { showStatistics = false },
            title = { Text("Statistics") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("X wins: " + session.xWins)
                    Text("O wins: " + session.oWins)
                    Text("Draws: " + session.draws)
                    Text("Moves in current game: " + session.game.moves.size)
                    Text("Scores are saved on this device.", style = MaterialTheme.typography.bodySmall)
                }
            },
            confirmButton = { Button(onClick = { showStatistics = false }) { Text("Done") } }
        )

        if (showSettings) AlertDialog(
            onDismissRequest = { showSettings = false },
            title = { Text("Appearance") },
            text = {
                Column {
                    Appearance.entries.forEach { option ->
                        FilterChip(
                            selected = appearance == option,
                            onClick = { appearance = option; store.appearance = option },
                            label = { Text(option.name.lowercase().replaceFirstChar { it.uppercase() }) }
                        )
                    }
                }
            },
            confirmButton = { Button(onClick = { showSettings = false }) { Text("Done") } }
        )

        if (tutorialStep >= 0) {
            val titles = listOf("Nine boards. One big win.", "Your move chooses their board.", "Win three boards in a row.")
            val explanations = listOf(
                "Ultimate Tic/Tac/Toe is nine small games in one. Tap any open square to place your X.",
                "The square you choose sends the other player to the matching mini-board. That board has an outline in the next player's color.",
                "Win a mini-board with three in a row. Win three mini-boards in a row to take the whole game. If your destination is already finished, you may play in any unfinished board."
            )
            AlertDialog(
                onDismissRequest = { tutorialStep = -1; store.tutorialCompleted = true },
                title = { Text(titles[tutorialStep]) },
                text = {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(explanations[tutorialStep])
                        Text("Step " + (tutorialStep + 1) + " of 3",
                            style = MaterialTheme.typography.labelSmall)
                    }
                },
                confirmButton = {
                    Button(onClick = {
                        if (tutorialStep == 2) {
                            tutorialStep = -1
                            store.tutorialCompleted = true
                        } else tutorialStep++
                    }) { Text(if (tutorialStep == 2) "Let's play" else "Next") }
                },
                dismissButton = {
                    TextButton(onClick = { tutorialStep = -1; store.tutorialCompleted = true }) {
                        Text("Skip · Play now")
                    }
                }
            )
        }
    }
}

@Composable
private fun BoardGrid(game: Game, enabled: Boolean, onMove: (Move) -> Unit) {
    Column(
        modifier = Modifier.fillMaxWidth().aspectRatio(1f)
            .semantics { contentDescription = "Ultimate Tic Tac Toe board" },
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        for (row in 0..2) {
            Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                for (column in 0..2) {
                    val index = row * 3 + column
                    MiniBoard(
                        boardIndex = index,
                        game = game,
                        enabled = enabled,
                        onMove = onMove,
                        modifier = Modifier.weight(1f).fillMaxHeight()
                    )
                }
            }
        }
    }
}

@Composable
private fun MiniBoard(
    boardIndex: Int, game: Game, enabled: Boolean,
    onMove: (Move) -> Unit, modifier: Modifier = Modifier
) {
    val status = game.boardResults[boardIndex]
    val forced = game.forcedBoard == boardIndex && game.legalBoards.size == 1
    val available = boardIndex in game.legalBoards
    val isDark = MaterialTheme.colorScheme.background == Midnight
    val boardFill = when (status) {
        Outcome.X_WON -> if (isDark) Color(0xFF09665F) else Color(0xFF9ADBD2)
        Outcome.O_WON -> if (isDark) Color(0xFF994B4A) else Color(0xFFF9B1AA)
        Outcome.DRAW -> if (isDark) Color(0xFF344257) else Color(0xFFE2E7EA)
        Outcome.ONGOING -> MaterialTheme.colorScheme.surface
    }
    val turnColor = if (game.currentPlayer == Mark.X) MaterialTheme.colorScheme.primary
        else MaterialTheme.colorScheme.secondary
    val stroke = if (forced) turnColor else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.13f)
    val strokeWidth = if (forced) 3.dp else if (status == Outcome.ONGOING) 1.dp else 0.dp
    val shape = RoundedCornerShape(8.dp)
    Box(
        modifier = modifier.padding(1.dp).clip(shape).background(boardFill)
            .border(strokeWidth, stroke, shape)
            .semantics {
                contentDescription = "Board " + (boardIndex + 1) + ", " +
                    when (status) {
                        Outcome.X_WON -> "won by X"
                        Outcome.O_WON -> "won by O"
                        Outcome.DRAW -> "drawn"
                        Outcome.ONGOING -> if (forced) "required destination" else "open"
                    }
            }
            .padding(3.dp)
    ) {
        Column(Modifier.fillMaxSize()) {
            for (row in 0..2) {
                Row(Modifier.weight(1f)) {
                    for (column in 0..2) {
                        val cellIndex = row * 3 + column
                        val mark = game.cells[boardIndex][cellIndex]
                        val canTap = enabled && available && mark == null
                        val bg = if (status.isFinished) boardFill
                            else if (isDark) Color(0xFF25374A) else Color(0xFFEDF1F2)
                        Box(
                            modifier = Modifier.weight(1f).fillMaxHeight().padding(1.dp)
                                .clip(RoundedCornerShape(3.dp)).background(bg)
                                .clickable(enabled = canTap) { onMove(Move(boardIndex, cellIndex)) }
                                .semantics {
                                    contentDescription = "Board " + (boardIndex + 1) +
                                        ", square " + (cellIndex + 1) +
                                        ", " + (mark?.name ?: if (canTap) "empty, playable" else "empty")
                                },
                            contentAlignment = Alignment.Center
                        ) {
                            if (mark != null) {
                                Text(
                                    mark.name, fontSize = 22.sp, fontWeight = FontWeight.Black,
                                    color = if (status.isFinished && isDark) Color.White
                                        else if (mark == Mark.X) DeepTeal else Coral
                                )
                            }
                        }
                    }
                }
            }
        }
        // The same actual three winning squares as the iOS board; do not invent a line.
        Game.winningLine(game.cells[boardIndex])?.let { line ->
            Canvas(modifier = Modifier.fillMaxSize()) {
                fun center(cell: Int) = Offset(
                    (cell % 3 + 0.5f) * size.width / 3f,
                    (cell / 3 + 0.5f) * size.height / 3f
                )
                drawLine(
                    color = if (status == Outcome.X_WON) Teal else Coral,
                    start = center(line.first()), end = center(line.last()),
                    strokeWidth = 4.dp.toPx(), cap = StrokeCap.Round
                )
            }
        }
    }
}
