import SwiftUI
import UltimateTTTCore

/// Optional, hands-on first-launch tour. Practice never touches GameSession,
/// Game Center, the player's statistics, purchases, or saved match.
struct TutorialSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var titleIsFocused: Bool

    let isFirstLaunch: Bool
    let onClose: (() -> Void)?

    @State private var stage: Stage = .welcome
    @State private var practice = UltimateGame()
    @State private var freeBoardChosen: Int?
    @State private var artworkIsFloating = false

    init(isFirstLaunch: Bool = false, onClose: (() -> Void)? = nil) {
        self.isFirstLaunch = isFirstLaunch
        self.onClose = onClose
    }

    private enum Stage: Int {
        case welcome, playAnywhere, followBoard, freeTurn, ready
    }

    private let positions = [
        "top-left", "top-middle", "top-right",
        "middle-left", "center", "middle-right",
        "bottom-left", "bottom-middle", "bottom-right"
    ]

    var body: some View {
        ZStack {
            GameStyle.background.ignoresSafeArea()

            // Quiet color, no flashing or animation when Reduce Motion is on.
            Circle()
                .fill(GameStyle.x.opacity(0.065))
                .frame(width: 330, height: 330)
                .blur(radius: 80)
                .offset(x: 175, y: -280)
                .accessibilityHidden(true)

            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    header
                    progressIndicator

                    VStack(alignment: .leading, spacing: 11) {
                        Text(heading)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .tracking(-0.7)
                            .foregroundStyle(GameStyle.text)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($titleIsFocused)

                        Text(explanation)
                            .font(.system(size: 15.5, weight: .regular))
                            .foregroundStyle(GameStyle.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    scene
                        .frame(maxWidth: .infinity)
                        .id(stage)
                        .transition(reduceMotion ? .opacity :
                            .opacity.combined(with: .move(edge: .trailing)))

                    if stage == .followBoard, let forced = practice.forcedBoard {
                        HStack(spacing: 9) {
                            Image(systemName: "scope")
                                .font(.system(size: 16, weight: .bold))
                            Text("O must play in the \(positions[forced]) board")
                                .font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(GameStyle.o)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(GameStyle.o.opacity(0.10), in:
                            RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityIdentifier("tutorial-forced-board-tip")
                    }
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 20)
                .padding(.top, 17)
                .padding(.bottom, 26)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomControls
        }
        .foregroundStyle(GameStyle.text)
        .tint(GameStyle.x)
        .onChange(of: stage) { _, _ in
            titleIsFocused = true
        }
        .accessibilityIdentifier("tutorial-screen")
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(GameStyle.x)
                .frame(width: 46, height: 46)
                .background(GameStyle.surface, in:
                    RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(GameStyle.outline)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("ULTIMATE TIC/TAC/TOE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(GameStyle.text)
                Text(isFirstLaunch ? "Your first game" : "Practice mode")
                    .font(.caption)
                    .foregroundStyle(GameStyle.muted)
            }

            Spacer(minLength: 8)

            Button(action: close) {
                HStack(spacing: 5) {
                    Text(isFirstLaunch ? "Skip" : "Done")
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GameStyle.muted)
                .padding(.horizontal, 13)
                .frame(height: 38)
                .background(GameStyle.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(GameStyle.outline))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tutorial-skip")
        }
    }

    private var progressIndicator: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(stage == .welcome ? "THE QUICK TOUR" :
                     stage == .ready ? "READY TO PLAY" :
                     "STEP \(stage.rawValue) OF 3")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.55)
                    .foregroundStyle(GameStyle.x)

                Spacer()

                if stage == .welcome {
                    Text("Three quick moves")
                        .font(.caption)
                        .foregroundStyle(GameStyle.muted)
                } else if stage != .ready {
                    Text("Tap to learn")
                        .font(.caption)
                        .foregroundStyle(GameStyle.muted)
                }
            }

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index < stage.rawValue ? GameStyle.x : GameStyle.outline)
                        .frame(height: 5)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(stage == .welcome ? "Tutorial not started" :
                                stage == .ready ? "Tutorial complete" :
                                "Lesson \(stage.rawValue) of 3")
        }
    }

    private var heading: String {
        switch stage {
        case .welcome: "Nine boards. One big win."
        case .playAnywhere: "Start anywhere."
        case .followBoard: "Now you choose where O goes."
        case .freeTurn: "Closed board? Free turn."
        case .ready: "Three in a row wins it all."
        }
    }

    private var explanation: String {
        switch stage {
        case .welcome:
            "It's tic tac toe with a twist: every square you choose decides your opponent's next board. Give it three quick moves, or jump straight in."
        case .playAnywhere:
            "You're X. There are nine smaller boards, and the opening move can go in any empty square. Your turn!"
        case .followBoard:
            "Look at where you placed X. That square sends O to the matching board. The coral outline shows where O can play."
        case .freeTurn:
            "Here's an example: the center board has already been won. If a move sends you there, you can pick any board that's still open."
        case .ready:
            "Claim three small boards across, down, or diagonally to win the match. You know the trick. The rest is strategy."
        }
    }

    @ViewBuilder
    private var scene: some View {
        switch stage {
        case .welcome:
            welcomeArtwork
        case .playAnywhere, .followBoard:
            VStack(spacing: 13) {
                UltimateBoardView(game: practice, canInteract: true) { board, cell in
                    playPracticeMove(board: board, cell: cell)
                }
                .accessibilityIdentifier("tutorial-practice-board")

                HStack(spacing: 8) {
                    Image(systemName: stage == .playAnywhere
                          ? "hand.tap.fill" : "arrow.turn.down.right")
                        .foregroundStyle(GameStyle.x)
                    Text(stage == .playAnywhere
                         ? "Tap any empty square to place X."
                         : "Place O inside the coral-outlined board.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GameStyle.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .freeTurn:
            freeTurnBoard
        case .ready:
            completedArtwork
        }
    }

    private var welcomeArtwork: some View {
        VStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(GameStyle.x.opacity(0.13))
                    .frame(width: 235, height: 235)
                    .blur(radius: 55)

                UltimateBoardView(game: welcomePreview, canInteract: false) { _, _ in }
                    .frame(maxWidth: 280)
                    .allowsHitTesting(false)
                    .scaleEffect(artworkIsFloating ? 1.015 : 0.985)
                    .animation(reduceMotion ? nil :
                        .easeInOut(duration: 2.1).repeatForever(autoreverses: true),
                        value: artworkIsFloating)
                    .accessibilityHidden(true)
            }
            .frame(height: 293)

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(GameStyle.x)
                Text("Learn the one rule that changes everything")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GameStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [GameStyle.surface, GameStyle.board.opacity(0.65)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 29, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .strokeBorder(GameStyle.outline)
        }
        .shadow(color: GameStyle.shadow, radius: 16, x: 0, y: 8)
        .onAppear { artworkIsFloating = !reduceMotion }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("An illustrated Ultimate Tic Tac Toe board with X and O moves")
    }

    /// Preview follows the actual move rules; it doesn't modify the real match.
    private var welcomePreview: UltimateGame {
        var sample = UltimateGame()
        for cell in [4, 0, 6, 2, 8, 1, 7, 5, 3] {
            if let move = sample.legalMoves.first(where: { $0.cell == cell }) {
                _ = sample.play(move)
            }
        }
        return sample
    }

    private var freeTurnBoard: some View {
        VStack(spacing: 13) {
            HStack(spacing: 8) {
                Image(systemName: "lock.open.fill")
                    .foregroundStyle(GameStyle.x)
                Text("CENTER BOARD IS ALREADY WON")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(GameStyle.muted)
                Spacer(minLength: 0)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3),
                spacing: 9
            ) {
                ForEach(0..<9, id: \.self) { board in
                    Button {
                        guard board != 4 else { return }
                        freeBoardChosen = board
                        GameFeedback.shared.play(.move)
                        advance(to: .ready)
                    } label: {
                        VStack(spacing: 7) {
                            Image(systemName: board == 4 ? "xmark" : "plus")
                                .font(.system(size: board == 4 ? 40 : 28, weight: .bold))
                            Text(board == 4 ? "WON" : "OPEN")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(1.5)
                        }
                        .foregroundStyle(board == 4 ? GameStyle.muted : GameStyle.x)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(board == 4 ? GameStyle.cell : GameStyle.tile,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(board == 4 ? GameStyle.outline :
                                              GameStyle.x.opacity(0.62), lineWidth: board == 4 ? 1 : 1.8)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(board == 4)
                    .accessibilityLabel("\(positions[board]) board, \(board == 4 ? "already won" : "open")")
                    .accessibilityHint(board == 4 ? "Cannot play here" : "Tap to choose this board")
                    .accessibilityIdentifier("tutorial-free-board-\(board)")
                }
            }
            .padding(10)
            .background(GameStyle.board, in:
                RoundedRectangle(cornerRadius: 23, style: .continuous))

            Label("Choose any OPEN board.", systemImage: "hand.tap.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GameStyle.x)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var completedArtwork: some View {
        VStack(spacing: 17) {
            ZStack {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(GameStyle.board)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3),
                    spacing: 9
                ) {
                    ForEach(0..<9, id: \.self) { board in
                        let xWins = board < 3
                        let oWins = board == 4 || board == 7
                        Text(xWins ? "X" : oWins ? "O" : "")
                            .font(.system(size: 48, weight: .heavy, design: .rounded))
                            .foregroundStyle(xWins ? GameStyle.x : GameStyle.o)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(xWins ? GameStyle.x.opacity(0.13) : GameStyle.tile,
                                        in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(xWins ? GameStyle.x : GameStyle.outline,
                                                  lineWidth: xWins ? 2.2 : 1)
                            }
                    }
                }
                .padding(12)
            }

            Label("A winning row of three small boards", systemImage: "trophy.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GameStyle.x)

            if let freeBoardChosen {
                Text("You picked the \(positions[freeBoardChosen]) board on your free turn. Nice.")
                    .font(.subheadline)
                    .foregroundStyle(GameStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(GameStyle.surface, in:
            RoundedRectangle(cornerRadius: 27, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .strokeBorder(GameStyle.outline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("X has won the top three small boards in a row")
    }

    private var bottomControls: some View {
        VStack(spacing: 10) {
            switch stage {
            case .welcome:
                primaryButton("Show me how", systemImage: "arrow.right") {
                    advance(to: .playAnywhere)
                }
                Button("Skip tutorial · Play now", action: close)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GameStyle.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .accessibilityIdentifier("tutorial-play-now")
            case .ready:
                primaryButton("Let's play", systemImage: "checkmark") { close() }
                Button("Practice again", action: restart)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GameStyle.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .accessibilityIdentifier("tutorial-restart")
            case .playAnywhere, .followBoard, .freeTurn:
                HStack(spacing: 10) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(GameStyle.x)
                    Text("Try the move above to continue")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(GameStyle.muted)
                    Spacer(minLength: 0)
                    Button("Restart", action: restart)
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("tutorial-restart")
                }
                .frame(minHeight: 48)
            }
        }
        .frame(maxWidth: 520)
        .padding(.horizontal, 20)
        .padding(.top, 13)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background {
            GameStyle.background.opacity(0.97)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(GameStyle.outline).frame(height: 1)
        }
    }

    private func primaryButton(
        _ label: String, systemImage: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Text(label)
                Spacer()
                Image(systemName: systemImage)
            }
            .font(.headline)
            .foregroundStyle(GameStyle.onAccent)
            .padding(.horizontal, 20)
            .frame(height: 54)
            .background(GameStyle.x, in:
                RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tutorial-primary")
    }

    private func playPracticeMove(board: Int, cell: Int) {
        guard stage == .playAnywhere || stage == .followBoard else { return }
        guard practice.play(Move(board: board, cell: cell)) else { return }
        GameFeedback.shared.play(.move)
        advance(to: stage == .playAnywhere ? .followBoard : .freeTurn)
    }

    private func restart() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            practice = UltimateGame()
            freeBoardChosen = nil
            stage = .welcome
        }
    }

    private func advance(to newStage: Stage) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86)) {
            stage = newStage
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }
}

#if DEBUG
#Preview("First-launch welcome") {
    TutorialSheet(isFirstLaunch: true)
}
#Preview("Tutorial replay") {
    TutorialSheet()
}
#endif
