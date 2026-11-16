import SwiftUI
import UltimateTTTCore

struct ReplayMoment: Identifiable {
    let turn: Int
    let label: String
    var id: Int { turn }
}

struct MatchReplaySheet: View {
    @Environment(\.dismiss) private var dismiss
    let finalGame: UltimateGame
    let moments: [ReplayMoment]

    @State private var turn: Int

    init(game: UltimateGame) {
        self.finalGame = game
        self.moments = Self.findMoments(in: game)
        _turn = State(initialValue: game.moves.count)
    }

    private var replayed: UltimateGame {
        var copy = UltimateGame()
        for move in finalGame.moves.prefix(turn) {
            _ = copy.play(move)
        }
        return copy
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Relive every move.")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(GameStyle.text)
                    Text("\(finalGame.moves.count) turns played")
                        .font(.subheadline)
                        .foregroundStyle(GameStyle.muted)

                    UltimateBoardView(game: replayed, canInteract: false) { _, _ in }
                        .animation(.easeOut(duration: 0.2), value: turn)

                    HStack {
                        Text("MOVE \(turn) OF \(finalGame.moves.count)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .tracking(1.0)
                            .foregroundStyle(GameStyle.muted)
                        Spacer()
                        Text(turnDescription)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(GameStyle.text)
                    }
                    if !finalGame.moves.isEmpty {
                        Slider(
                            value: Binding(
                                get: { Double(turn) },
                                set: { turn = min(finalGame.moves.count, max(0, Int($0.rounded()))) }
                            ),
                            in: 0...Double(finalGame.moves.count),
                            step: 1
                        )
                        .tint(GameStyle.x)
                    }

                    HStack(spacing: 10) {
                        Button {
                            turn = max(0, turn - 1)
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                        }
                        .disabled(turn == 0)
                        .buttonStyle(.bordered)

                        Button {
                            turn = min(finalGame.moves.count, turn + 1)
                        } label: {
                            Label("Next", systemImage: "chevron.right")
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                        }
                        .disabled(turn == finalGame.moves.count)
                        .buttonStyle(.borderedProminent)
                    }

                    if !moments.isEmpty {
                        Text("KEY MOMENTS")
                            .font(.caption.weight(.bold))
                            .tracking(1.6)
                            .foregroundStyle(GameStyle.muted)
                            .padding(.top, 10)
                        VStack(spacing: 0) {
                            ForEach(moments) { moment in
                                Button {
                                    withAnimation { turn = moment.turn }
                                } label: {
                                    HStack(spacing: 12) {
                                        Text("\(moment.turn)")
                                            .font(.subheadline.monospacedDigit().bold())
                                            .foregroundStyle(GameStyle.x)
                                            .frame(width: 32)
                                        Text(moment.label)
                                            .font(.subheadline)
                                            .foregroundStyle(GameStyle.text)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(GameStyle.muted)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                if moment.id != moments.last?.id {
                                    Divider().overlay(GameStyle.outline)
                                }
                            }
                        }
                        .background(GameStyle.surface, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .frame(maxWidth: 520)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(GameStyle.background.ignoresSafeArea())
            .navigationTitle("Game replay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var turnDescription: String {
        guard turn > 0 else { return "Opening board" }
        return "\(turn % 2 == 1 ? "X" : "O") played · board \(finalGame.moves[turn - 1].board + 1)"
    }

    private static func findMoments(in game: UltimateGame) -> [ReplayMoment] {
        var replay = UltimateGame()
        var found = [ReplayMoment]()
        for (offset, move) in game.moves.enumerated() {
            let earlier = replay.boardResults[move.board]
            _ = replay.play(move)
            let number = offset + 1
            let player = number % 2 == 1 ? "X" : "O"
            if earlier == .ongoing,
               case .won = replay.boardResults[move.board] {
                found.append(ReplayMoment(
                    turn: number, label: "\(player) claimed small board \(move.board + 1)"
                ))
            }
            if replay.result.isFinished {
                let description: String
                switch replay.result {
                case .won(let winner): description = "\(winner.symbol) won the whole match"
                case .drawn: description = "The match finished in a draw"
                case .ongoing: description = ""
                }
                found.append(ReplayMoment(turn: number, label: description))
            }
        }

        // Show a few actual pivotal events, not fabricated AI assessments.
        if found.count <= 3 { return found }
        let selected = [found[0], found[found.count / 2], found[found.count - 1]]
        return Array(Dictionary(grouping: selected, by: \.turn).values.compactMap(\.first))
            .sorted { $0.turn < $1.turn }
    }
}
