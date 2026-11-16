import SwiftUI
import UltimateTTTCore

struct ContentView: View {
    @ObservedObject var session: GameSession
    @ObservedObject var gameCenter: GameCenterManager
    @ObservedObject var purchases: PurchaseManager
    @ObservedObject var ads: AdManager

    @State private var showingNewGame = false
    @State private var showingRules = false
    @State private var showingShop = false

    private var displayedGame: UltimateGame { gameCenter.game ?? session.game }
    private var online: Bool { gameCenter.isOnline }

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    HStack(spacing: 10) {
                        Button {
                            gameCenter.playOnline()
                        } label: {
                            Label(online ? "Matches" : "Play online", systemImage: "person.2")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            gameCenter.showAchievements()
                        } label: {
                            Image(systemName: "trophy")
                                .frame(width: 36, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Game Center achievements")

                        Button {
                            showingShop = true
                        } label: {
                            Image(systemName: purchases.adsRemoved ? "checkmark.shield" : "cart")
                                .frame(width: 36, height: 24)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(purchases.adsRemoved ? "Ads removed" : "Remove ads")
                    }
                    .controlSize(.large)

                    if online {
                        HStack {
                            Label("Game Center match", systemImage: "gamecontroller")
                            Spacer()
                            if let mark = gameCenter.localMark {
                                Text("You are \(mark.symbol)")
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    } else {
                        scoreboard
                    }

                    status
                    UltimateBoardView(
                        game: displayedGame,
                        canInteract: online ? gameCenter.canPlay : !session.isThinking
                    ) { board, cell in
                        if online {
                            gameCenter.submitMove(board: board, cell: cell)
                        } else {
                            session.play(board: board, cell: cell)
                        }
                    }

                    if online {
                        HStack(spacing: 10) {
                            Button {
                                gameCenter.refresh()
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                gameCenter.closeOnlineBoard()
                            } label: {
                                Label("Local game", systemImage: "iphone")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .controlSize(.large)
                    } else {
                        HStack(spacing: 10) {
                            Button {
                                session.undoTurn()
                            } label: {
                                Label("Undo", systemImage: "arrow.uturn.backward")
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(session.game.moves.isEmpty)
                            .buttonStyle(.bordered)

                            Button {
                                showingNewGame = true
                            } label: {
                                Label("New game", systemImage: "plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .controlSize(.large)
                    }

                    Button {
                        showingRules = true
                    } label: {
                        Label("How to play", systemImage: "questionmark.circle")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
                }
                .frame(maxWidth: 540)
                .padding(.horizontal, 18)
                .padding(.top, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if ads.canShowAds && !purchases.adsRemoved {
                AdBanner()
                    .frame(width: 320, height: 50)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(.regularMaterial)
                    .accessibilityLabel("Advertisement")
            }
        }
        .sheet(isPresented: $showingNewGame) {
            NewGameSheet(mode: session.mode, difficulty: session.difficulty) { mode, difficulty in
                session.startNewGame(mode: mode, difficulty: difficulty)
            }
        }
        .sheet(isPresented: $showingRules) { RulesSheet() }
        .sheet(isPresented: $showingShop) {
            RemoveAdsSheet(purchases: purchases, ads: ads)
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
            session.onSoloWin = { gameCenter.achievements.recordSoloWin() }
            session.resumeComputerTurn()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ULTIMATE")
                .font(.caption.weight(.bold))
                .tracking(2.5)
                .foregroundStyle(.secondary)
            Text("Tic Tac Toe")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.8)
            Text(online ? "Game Center · Online match" :
                 session.mode == .solo ? "Vs computer · \(session.difficulty.label)" : "Two players · Pass and play")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var scoreboard: some View {
        HStack(spacing: 8) {
            scoreTile(name: session.mode == .solo ? "You" : "Player X", value: session.scores.xWins, mark: .x)
            scoreTile(name: "Draws", value: session.scores.draws, mark: nil)
            scoreTile(name: session.mode == .solo ? "Computer" : "Player O", value: session.scores.oWins, mark: .o)
        }
    }

    private func scoreTile(name: String, value: Int, mark: Mark?) -> some View {
        VStack(spacing: 5) {
            Text(name).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            Text(value.formatted())
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(mark == .x ? Color.indigo : mark == .o ? Color.orange : Color.primary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 13))
        .accessibilityElement(children: .combine)
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(statusTitle)
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text(statusDetail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
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
            return online ? "This Game Center match is complete." : "Start a new game to play again."
        }
        if online && gameCenter.currentMatch?.status == .ended {
            return "Return to your matches or start a local game."
        }
        if let destination = displayedGame.forcedBoard,
           displayedGame.legalBoards == [destination] {
            return "Play in the highlighted \(BoardPosition.names[destination]) board."
        }
        return "Choose a square in any open board."
    }
}

private enum BoardPosition {
    static let names = ["top-left", "top-middle", "top-right", "middle-left", "center", "middle-right", "bottom-left", "bottom-middle", "bottom-right"]
}

private struct UltimateBoardView: View {
    let game: UltimateGame
    let canInteract: Bool
    let onSelect: (Int, Int) -> Void

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { column in
                        let board = row * 3 + column
                        MiniBoardView(
                            index: board,
                            cells: game.cells[board],
                            result: game.boardResults[board],
                            isPlayable: canInteract && game.legalBoards.contains(board)
                        ) { cell in onSelect(board, cell) }
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(6)
        .background(Color(uiColor: .separator), in: RoundedRectangle(cornerRadius: 16))
        .aspectRatio(1, contentMode: .fit)
        .accessibilityIdentifier("ultimate-board")
    }
}

private struct MiniBoardView: View {
    let index: Int
    let cells: [Mark?]
    let result: GameResult
    let isPlayable: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(isPlayable ? Color.accentColor.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground))

            switch result {
            case .won(let mark):
                Text(mark.symbol)
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(mark == .x ? Color.indigo : Color.orange)
                    .accessibilityLabel("\(mark.symbol) won this board")
            case .drawn:
                Image(systemName: "minus")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Drawn board")
            case .ongoing:
                VStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { column in
                                let cell = row * 3 + column
                                Button { onSelect(cell) } label: {
                                    GeometryReader { geometry in
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                            if let mark = cells[cell] {
                                                Text(mark.symbol)
                                                    .font(.system(size: geometry.size.width * 0.65, weight: .bold, design: .rounded))
                                                    .foregroundStyle(mark == .x ? Color.indigo : Color.orange)
                                            }
                                        }
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                }
                                .buttonStyle(.plain)
                                .disabled(!isPlayable || cells[cell] != nil)
                                .accessibilityLabel("Board \(index + 1), cell \(cell + 1): \(cells[cell]?.symbol ?? "empty")")
                                .accessibilityHint(isPlayable && cells[cell] == nil ? "Double tap to place a mark" : "Unavailable")
                            }
                        }
                    }
                }
                .padding(5)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(isPlayable ? Color.accentColor : Color.clear, lineWidth: 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Small board \(index + 1)")
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
            Form {
                Section("Players") {
                    Picker("Mode", selection: $selectedMode) {
                        ForEach(GameMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if selectedMode == .solo {
                    Section("Computer difficulty") {
                        Picker("Difficulty", selection: $selectedDifficulty) {
                            ForEach(Difficulty.allCases) { difficulty in
                                Text(difficulty.label).tag(difficulty)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Section {
                    Text("Starting a new game clears the board but keeps your match scores.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        onStart(selectedMode, selectedDifficulty)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct RulesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    rule("1", title: "Play in a small board", detail: "There are nine tic tac toe boards. The first player can place an X anywhere.")
                    rule("2", title: "Send the next player", detail: "The square you choose determines which small board your opponent must play in next. For example, taking the top-right square sends them to the top-right board.")
                    rule("3", title: "Free moves", detail: "If the destination board has already been won or filled, the next player can choose any unfinished board.")
                    rule("4", title: "Win the big board", detail: "Win three small boards in a row to win the game. A drawn small board belongs to neither player. If all nine boards finish without a winner, the game is a draw.")
                    Text("The highlighted board shows where you can play.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
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
                .foregroundStyle(.tint)
                .frame(width: 24, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.body).foregroundStyle(.secondary)
            }
        }
    }
}
