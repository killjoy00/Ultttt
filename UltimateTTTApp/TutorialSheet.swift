import SwiftUI
import UltimateTTTCore

/// Three hands-on lessons. The first two moves use the actual game engine;
/// the final example shows the free-choice rule with a completed center board.
struct TutorialSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var practice = UltimateGame()
    @State private var freeChoice: Int?

    private let names = [
        "top-left", "top-middle", "top-right",
        "middle-left", "center", "middle-right",
        "bottom-left", "bottom-middle", "bottom-right"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    HStack {
                        Text(step == 3 ? "YOU'RE READY" : "LESSON \(step + 1) OF 3")
                            .font(.caption.weight(.bold))
                            .tracking(1.8)
                            .foregroundStyle(GameStyle.x)
                        Spacer()
                        if step < 3 {
                            Text("\(step + 1) / 3")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(GameStyle.muted)
                        }
                    }

                    Text(lessonTitle)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(GameStyle.text)

                    Text(lessonDetail)
                        .font(.subheadline)
                        .foregroundStyle(GameStyle.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    if step <= 1 {
                        UltimateBoardView(game: practice, canInteract: true) { board, cell in
                            if practice.play(Move(board: board, cell: cell)) {
                                GameFeedback.shared.play(.move)
                                withAnimation(.easeOut(duration: 0.2)) { step += 1 }
                            }
                        }
                    } else if step == 2 {
                        freeChoiceBoard
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 70, weight: .light))
                            .foregroundStyle(GameStyle.x)
                            .frame(maxWidth: .infinity)
                            .frame(height: 185)
                    }

                    if step == 1 {
                        Label("Only one small board is outlined. Your O must go there.",
                              systemImage: "arrow.turn.down.right")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GameStyle.x)
                    }

                    if step == 3 {
                        Button {
                            dismiss()
                        } label: {
                            Text("Let's play")
                                .font(.headline)
                                .foregroundStyle(GameStyle.onAccent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(GameStyle.x, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        Button("Practice again") {
                            practice = UltimateGame()
                            freeChoice = nil
                            step = 0
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                    } else {
                        Button("Start over") {
                            practice = UltimateGame()
                            freeChoice = nil
                            step = 0
                        }
                        .font(.subheadline)
                        .foregroundStyle(GameStyle.muted)
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: 520)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(GameStyle.background.ignoresSafeArea())
            .navigationTitle("Learn to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var lessonTitle: String {
        switch step {
        case 0: "Make your first move"
        case 1: "Follow the next board"
        case 2: "What if a board is closed?"
        default: "That's Ultimate Tic Tac Toe."
        }
    }

    private var lessonDetail: String {
        switch step {
        case 0:
            "Each square belongs to one of nine small boards. You're X. Tap any empty square to start."
        case 1:
            "The square you picked sends O to that same position in the big grid. Place an O in the outlined board."
        case 2:
            "Imagine your opponent just sent you to the center, but that board has already been won. Tap ANY other board to take a free turn."
        default:
            "Win three small boards in a row to take the big board. Remember: every square you choose sends your opponent to their next board."
        }
    }

    private var freeChoiceBoard: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(0..<9, id: \.self) { board in
                    Button {
                        guard board != 4 else { return }
                        freeChoice = board
                        GameFeedback.shared.play(.move)
                        withAnimation(.easeOut(duration: 0.2)) { step = 3 }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: board == 4 ? "xmark" : "plus")
                                .font(.system(size: 27, weight: .semibold))
                            Text(board == 4 ? "WON" : "OPEN")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                        }
                        .foregroundStyle(board == 4 ? GameStyle.muted : GameStyle.x)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(
                            board == 4 ? GameStyle.cell : GameStyle.tile,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(board == 4 ? GameStyle.outline : GameStyle.x.opacity(0.55))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(board == 4)
                    .accessibilityLabel("\(names[board]) board, \(board == 4 ? "already won" : "available")")
                }
            }
            .padding(9)
            .background(GameStyle.board, in: RoundedRectangle(cornerRadius: 20))
            Text("Center is closed. All eight other boards are playable.")
                .font(.caption)
                .foregroundStyle(GameStyle.muted)
        }
    }
}
