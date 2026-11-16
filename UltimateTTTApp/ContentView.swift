import SwiftUI
import UltimateTTTCore

struct ContentView: View {
    @ObservedObject var session: GameSession
    @ObservedObject var gameCenter: GameCenterManager
    @ObservedObject var purchases: PurchaseManager
    @ObservedObject var ads: AdManager
    @ObservedObject var statistics: GameStatisticsStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingNewGame = false
    @State private var showingRules = false
    @State private var showingShop = false
    @State private var showingTutorial = false
    @State private var showingStatistics = false
    @State private var showingSettings = false
    @State private var showingReplay = false

    private var online: Bool { gameCenter.isOnline }
    private var displayedGame: UltimateGame { gameCenter.game ?? session.game }
    private var canPlay: Bool { online ? gameCenter.canPlay : !session.isThinking }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                modeControls
                turnPanel

                UltimateBoardView(game: displayedGame, canInteract: canPlay) { board, cell in
                    if online {
                        gameCenter.submitMove(board: board, cell: cell)
                    } else {
                        session.play(board: board, cell: cell)
                    }
                }
                .padding(.vertical, 2)

                if !online {
                    scoreboard
                }

                gameActions
                if displayedGame.result.isFinished {
                    Button { showingReplay = true } label: {
                        Label("Watch the game replay", systemImage: "play.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GameStyle.x)
                            .frame(maxWidth: .infinity).padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                } else if !online && session.game.moves.isEmpty {
                    Button { showingTutorial = true } label: {
                        Label("New here? Try the tutorial", systemImage: "hand.tap")
                            .font(.subheadline)
                            .foregroundStyle(GameStyle.muted)
                            .frame(maxWidth: .infinity).padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(GameStyle.background.ignoresSafeArea())
        .foregroundStyle(GameStyle.text)
        .tint(GameStyle.x)
        .safeAreaInset(edge: .bottom) {
            if ads.canShowAds && !purchases.adsRemoved {
                AdBanner()
                    .frame(width: 320, height: 50)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(GameStyle.background)
                    .accessibilityLabel("Advertisement")
            }
        }
        .sheet(isPresented: $showingNewGame) {
            NewGameSheet(mode: session.mode, difficulty: session.difficulty) { mode, difficulty in
                session.startNewGame(mode: mode, difficulty: difficulty)
            }
        }
        .sheet(isPresented: $showingRules) {
            RulesSheet()
        }
        .sheet(isPresented: $showingShop) {
            RemoveAdsSheet(purchases: purchases, ads: ads)
        }
        .sheet(isPresented: $showingTutorial) { TutorialSheet() }
        .sheet(isPresented: $showingStatistics) {
            StatisticsSheet(statistics: statistics) { gameCenter.showLeaderboards() }
        }
        .sheet(isPresented: $showingSettings) { GameSettingsSheet() }
        .sheet(isPresented: $showingReplay) {
            MatchReplaySheet(game: displayedGame)
        }
        .alert("Game Center", isPresented: Binding(
            get: { gameCenter.errorMessage != nil },
            set: { if !$0 { gameCenter.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { gameCenter.errorMessage = nil }
        } message: {
            Text(gameCenter.errorMessage ?? "")
        }
        .onAppear {
            gameCenter.statistics = statistics
            session.onSoloWin = { gameCenter.achievements.recordSoloWin() }
            session.onSoloGameFinished = { id, result, difficulty, moves in
                statistics.recordSolo(id: id, result: result, difficulty: difficulty, moves: moves)
            }
            session.onSoloGameReopened = { id in statistics.reopenSolo(id: id) }
            session.recordCompletedGameIfNeeded()
            session.resumeComputerTurn()
            gameCenter.refreshTurnCounts()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { gameCenter.refreshTurnCounts() }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(GameStyle.x)
                .frame(width: 44, height: 44)
                .background(GameStyle.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                Text("ULTIMATE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(3.1)
                    .foregroundStyle(GameStyle.muted)
                Text("Tic Tac Toe")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .tracking(-0.55)
                    .foregroundStyle(GameStyle.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            Menu {
                Button("Interactive tutorial", systemImage: "hand.tap") { showingTutorial = true }
                Button("Quick rules", systemImage: "questionmark.circle") { showingRules = true }
                Button("Statistics", systemImage: "chart.bar") { showingStatistics = true }
                Button("Leaderboards", systemImage: "list.number") { gameCenter.showLeaderboards() }
                Button("Achievements", systemImage: "trophy") { gameCenter.showAchievements() }
                Button(purchases.adsRemoved ? "Ads removed" : "Remove ads", systemImage: "cart") {
                    showingShop = true
                }
                Button("Settings", systemImage: "gearshape") { showingSettings = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(GameStyle.text)
                    .frame(width: 44, height: 44)
                    .background(GameStyle.surface, in: Circle())
                    .overlay(Circle().strokeBorder(GameStyle.outline))
            }
            .accessibilityLabel("More options")
        }
    }

    private var modeControls: some View {
        HStack(spacing: 10) {
            Button {
                if online {
                    gameCenter.playOnline()
                } else {
                    showingNewGame = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: online ? "person.2.fill" : session.mode == .solo ? "cpu" : "person.2")
                        .font(.system(size: 13, weight: .semibold))
                    Text(modeLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(GameStyle.muted)
                }
                .foregroundStyle(GameStyle.text)
                .padding(.horizontal, 13)
                .frame(height: 40)
                .background(GameStyle.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(GameStyle.outline))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(online ? "Game Center matches" : "Change local game mode")

            Spacer(minLength: 0)

            Button {
                if online {
                    gameCenter.closeOnlineBoard()
                } else {
                    gameCenter.playOnline()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: online ? "iphone" : "person.2.fill")
                    Text(online ? "Local game" :
                         gameCenter.yourTurnCount > 0 ? "Your turn ((gameCenter.yourTurnCount))" : "Play online")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(GameStyle.onAccent)
                .padding(.horizontal, 15)
                .frame(height: 40)
                .background(GameStyle.x, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var modeLabel: String {
        if online { return "Game Center" }
        if session.mode == .solo { return "Computer · \(session.difficulty.label)" }
        return "Pass and play"
    }

    private var turnPanel: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(turnColor.opacity(0.12))
                if displayedGame.result == .drawn {
                    Image(systemName: "equal")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(GameStyle.muted)
                } else if displayedGame.result.isFinished {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(turnColor)
                } else {
                    Text(displayedGame.currentPlayer.symbol)
                        .font(.system(size: 29, weight: .heavy, design: .rounded))
                        .foregroundStyle(turnColor)
                }
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .tracking(-0.35)
                    .foregroundStyle(GameStyle.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(statusDetail)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(GameStyle.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GameStyle.surface, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .strokeBorder(GameStyle.outline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("turn-status")
    }

    private var turnColor: Color {
        switch displayedGame.result {
        case .won(let mark): return GameStyle.color(for: mark)
        case .ongoing: return GameStyle.color(for: displayedGame.currentPlayer)
        case .drawn: return GameStyle.muted
        }
    }

    private var statusTitle: String {
        if online && gameCenter.isSubmitting { return "Sending move…" }
        if online && gameCenter.currentMatch?.status == .ended && !displayedGame.result.isFinished {
            return "Match ended"
        }
        switch displayedGame.result {
        case .won(let mark):
            if online { return gameCenter.localMark == mark ? "You win!" : "Opponent wins" }
            if session.mode == .solo { return mark == .x ? "You win!" : "Computer wins" }
            return "\(mark.symbol) wins!"
        case .drawn: return "It's a draw"
        case .ongoing:
            if online { return gameCenter.isMyTurn ? "Your turn" : "Waiting for opponent" }
            if session.isThinking { return "Computer is thinking…" }
            if session.mode == .solo { return "Your move" }
            return "\(session.game.currentPlayer.symbol)'s turn"
        }
    }

    private var statusDetail: String {
        if displayedGame.result.isFinished {
            return online ? "The Game Center match is complete." : "Start a new game to play again."
        }
        if online && gameCenter.currentMatch?.status == .ended {
            return "Open your matches or return to a local game."
        }
        if online && !gameCenter.isMyTurn {
            return "Your opponent has the next move."
        }
        if !online && session.isThinking {
            return "The computer is choosing a square."
        }
        if let destination = displayedGame.forcedBoard,
           displayedGame.legalBoards == [destination] {
            return "Play in the \(BoardPosition.names[destination]) board."
        }
        return displayedGame.moves.isEmpty ? "Choose any square to begin." : "Free choice — play in any open board."
    }

    private var scoreboard: some View {
        HStack(spacing: 0) {
            scoreCell(
                title: session.mode == .solo ? "YOU" : "PLAYER X",
                value: session.scores.xWins,
                mark: .x
            )
            scoreDivider
            scoreCell(title: "DRAWS", value: session.scores.draws, mark: nil)
            scoreDivider
            scoreCell(
                title: session.mode == .solo ? "COMPUTER" : "PLAYER O",
                value: session.scores.oWins,
                mark: .o
            )
        }
        .padding(.vertical, 11)
        .background(GameStyle.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(GameStyle.outline))
        .accessibilityIdentifier("match-scores")
    }

    private var scoreDivider: some View {
        Rectangle()
            .fill(GameStyle.outline)
            .frame(width: 1, height: 25)
    }

    private func scoreCell(title: String, value: Int, mark: Mark?) -> some View {
        HStack(spacing: 6) {
            if let mark {
                Text(mark.symbol)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(GameStyle.color(for: mark))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(GameStyle.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(value.formatted())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(GameStyle.text)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    private var gameActions: some View {
        HStack(spacing: 10) {
            if online {
                if gameCenter.currentMatch?.status == .ended {
                    actionButton("Matches", icon: "person.2", prominent: false, enabled: true) {
                        gameCenter.playOnline()
                    }
                    actionButton(
                        gameCenter.isRematching ? "Starting…" : "Rematch",
                        icon: "arrow.triangle.2.circlepath", prominent: true,
                        enabled: !gameCenter.isRematching
                    ) { gameCenter.rematch() }
                } else {
                    actionButton("Refresh", icon: "arrow.clockwise", prominent: false, enabled: true) {
                        gameCenter.refresh()
                        gameCenter.refreshTurnCounts()
                    }
                    actionButton("Matches", icon: "person.2", prominent: true, enabled: true) {
                        gameCenter.playOnline()
                    }
                }
            } else {
                actionButton(
                    "Undo", icon: "arrow.uturn.backward",
                    prominent: false, enabled: !session.game.moves.isEmpty
                ) {
                    session.undoTurn()
                }
                actionButton("New game", icon: "plus", prominent: true, enabled: true) {
                    showingNewGame = true
                }
            }
        }
    }

    private func actionButton(
        _ title: String,
        icon: String,
        prominent: Bool,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .foregroundStyle(prominent ? GameStyle.onAccent : GameStyle.text)
                .background(
                    prominent ? GameStyle.x : GameStyle.surface,
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(prominent ? Color.clear : GameStyle.outline)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.45)
    }
}

private enum BoardPosition {
    static let names = [
        "top-left", "top-middle", "top-right",
        "middle-left", "center", "middle-right",
        "bottom-left", "bottom-middle", "bottom-right"
    ]
}

struct UltimateBoardView: View {
    let game: UltimateGame
    let canInteract: Bool
    let onSelect: (Int, Int) -> Void

    var body: some View {
        VStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { column in
                        let index = row * 3 + column
                        MiniBoardView(
                            index: index,
                            cells: game.cells[index],
                            result: game.boardResults[index],
                            canInteract: canInteract && game.legalBoards.contains(index),
                            isForced: game.legalBoards == [index],
                            lastCell: game.moves.last?.board == index ? game.moves.last?.cell : nil,
                            onSelect: { onSelect(index, $0) }
                        )
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(9)
        .background(
            GameStyle.board,
            in: RoundedRectangle(cornerRadius: 23, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .strokeBorder(GameStyle.outline, lineWidth: 1)
        )
        .shadow(color: GameStyle.shadow, radius: 18, x: 0, y: 9)
        .aspectRatio(1, contentMode: .fit)
        .animation(.easeOut(duration: 0.17), value: game.moves.count)
        .accessibilityIdentifier("ultimate-board")
    }
}

private struct MiniBoardView: View {
    let index: Int
    let cells: [Mark?]
    let result: GameResult
    let canInteract: Bool
    let isForced: Bool
    let lastCell: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(backgroundColor)

            // Keep every played square visible after a small board is won.
            VStack(spacing: 2.5) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 2.5) {
                        ForEach(0..<3, id: \.self) { column in
                            let cell = row * 3 + column
                            Button {
                                onSelect(cell)
                            } label: {
                                GeometryReader { geometry in
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                            .fill(GameStyle.cell.opacity(cells[cell] == nil ? 0.66 : 1.0))
                                        if let mark = cells[cell] {
                                            Text(mark.symbol)
                                                .font(.system(
                                                    size: geometry.size.width * 0.70,
                                                    weight: .bold,
                                                    design: .rounded
                                                ))
                                                .foregroundStyle(GameStyle.color(for: mark))
                                        }
                                    }
                                    .overlay {
                                        if lastCell == cell {
                                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                                .strokeBorder(GameStyle.text.opacity(0.6), lineWidth: 1.5)
                                        }
                                    }
                                }
                                .aspectRatio(1, contentMode: .fit)
                            }
                            .buttonStyle(.plain)
                            .disabled(!canInteract || result != .ongoing || cells[cell] != nil)
                            .accessibilityLabel(
                                "\(BoardPosition.names[index]) board, \(BoardPosition.names[cell]) square, " +
                                "\(cells[cell]?.symbol ?? "empty")"
                            )
                            .accessibilityHint(
                                canInteract && result == .ongoing && cells[cell] == nil
                                    ? "Double tap to place a mark" : "Unavailable"
                            )
                            .accessibilityIdentifier("board-\(index)-cell-\(cell)")
                        }
                    }
                }
            }
            .padding(5)

            if case .won(let mark) = result {
                WinningLineOverlay(line: UltimateGame.winningLine(in: cells), mark: mark)
                    .padding(5)
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(borderColor, lineWidth: result == .ongoing ? (isForced ? 2.5 : 1) : 3)
        }
        .shadow(color: isForced ? GameStyle.x.opacity(0.24) : .clear, radius: isForced ? 6 : 0)
        .animation(.easeOut(duration: 0.22), value: isForced)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(BoardPosition.names[index]) board, \(boardDescription)")
    }

    private var backgroundColor: Color {
        switch result {
        case .won(let mark): return GameStyle.color(for: mark).opacity(0.11)
        case .drawn: return GameStyle.muted.opacity(0.12)
        case .ongoing: return isForced ? GameStyle.x.opacity(0.13) : GameStyle.tile
        }
    }

    private var borderColor: Color {
        switch result {
        case .won(let mark): return GameStyle.color(for: mark)
        case .drawn: return GameStyle.muted.opacity(0.5)
        case .ongoing: return isForced ? GameStyle.x : GameStyle.outline
        }
    }

    private var boardDescription: String {
        switch result {
        case .won(let mark): return "won by \(mark.symbol)"
        case .drawn: return "drawn"
        case .ongoing: return isForced ? "required destination" : "unfinished"
        }
    }
}

private struct WinningLineOverlay: View {
    let line: [Int]?
    let mark: Mark

    var body: some View {
        GeometryReader { geometry in
            if let line, line.count == 3 {
                Path { path in
                    let gap: CGFloat = 2.5
                    let width = (geometry.size.width - gap * 2) / 3
                    func center(_ index: Int) -> CGPoint {
                        CGPoint(
                            x: CGFloat(index % 3) * (width + gap) + width / 2,
                            y: CGFloat(index / 3) * (width + gap) + width / 2
                        )
                    }
                    path.move(to: center(line[0]))
                    path.addLine(to: center(line[2]))
                }
                .stroke(
                    GameStyle.color(for: mark).opacity(0.78),
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                )
            }
        }
    }
}

private struct NewGameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: GameMode
    @State private var selectedDifficulty: Difficulty
    let onStart: (GameMode, Difficulty) -> Void

    init(mode: GameMode, difficulty: Difficulty, onStart: @escaping (GameMode, Difficulty) -> Void) {
        _selectedMode = State(initialValue: mode)
        _selectedDifficulty = State(initialValue: difficulty)
        self.onStart = onStart
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("How do you want to play?")
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                        Text("Your match scores carry over between games.")
                            .font(.subheadline)
                            .foregroundStyle(GameStyle.muted)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("PLAYERS").font(.caption.weight(.semibold)).tracking(1.5)
                            .foregroundStyle(GameStyle.muted)
                        Picker("Players", selection: $selectedMode) {
                            ForEach(GameMode.allCases) { mode in Text(mode.label).tag(mode) }
                        }
                        .pickerStyle(.segmented)
                    }

                    if selectedMode == .solo {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("DIFFICULTY").font(.caption.weight(.semibold)).tracking(1.5)
                                .foregroundStyle(GameStyle.muted)
                            Picker("Difficulty", selection: $selectedDifficulty) {
                                ForEach(Difficulty.allCases) { level in Text(level.label).tag(level) }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    Button {
                        onStart(selectedMode, selectedDifficulty)
                        dismiss()
                    } label: {
                        Text("Start game")
                            .font(.headline)
                            .foregroundStyle(GameStyle.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(GameStyle.x, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
            }
            .scrollIndicators(.hidden)
            .background(GameStyle.background.ignoresSafeArea())
            .navigationTitle("New game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct RulesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    rule("1", title: "Play in a small board",
                         detail: "There are nine boards. X starts and can play anywhere.")
                    rule("2", title: "Send the next player",
                         detail: "The square you choose determines your opponent's next board. A top-right move sends them to the top-right board.")
                    rule("3", title: "Free moves",
                         detail: "If the destination board is already won or filled, the next player may choose any unfinished board.")
                    rule("4", title: "Win the big board",
                         detail: "Win three small boards in a row. Drawn boards count for neither player. If all boards finish without a winner, the match is a draw.")

                    Text("A teal outline shows the board where you can play next.")
                        .font(.subheadline)
                        .foregroundStyle(GameStyle.muted)
                        .padding(.top, 5)
                }
                .padding(24)
            }
            .background(GameStyle.background.ignoresSafeArea())
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func rule(_ number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.headline.monospacedDigit())
                .foregroundStyle(GameStyle.x)
                .frame(width: 24, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.body).foregroundStyle(GameStyle.muted)
            }
        }
    }
}

#if DEBUG
#Preview("Light") {
    ContentView(
        session: GameSession(),
        gameCenter: GameCenterManager(),
        purchases: PurchaseManager(),
        ads: AdManager(),
        statistics: GameStatisticsStore()
    )
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    ContentView(
        session: GameSession(),
        gameCenter: GameCenterManager(),
        purchases: PurchaseManager(),
        ads: AdManager(),
        statistics: GameStatisticsStore()
    )
    .preferredColorScheme(.dark)
}
#endif
