import Foundation

public enum Difficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case easy, medium, hard

    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

/// Offline computer opponent. X always starts; the computer plays O.
public enum ComputerOpponent {
    public static func chooseMove(in game: UltimateGame, difficulty: Difficulty) -> Move? {
        let legal = game.legalMoves
        guard !legal.isEmpty else { return nil }
        guard game.currentPlayer == .o else { return nil }
        if difficulty == .easy { return legal.randomElement() }

        var bestMove = legal[0]
        var bestScore = -Double.infinity
        for move in legal.shuffled() {
            var after = game
            _ = after.play(move)
            let score: Double
            if difficulty == .medium {
                score = evaluate(after) + Double.random(in: -5...5)
            } else if after.result == .won(.o) {
                return move
            } else {
                // Account for the opponent's strongest immediate reply.
                let replies = after.legalMoves
                let worstReply = replies.map { reply -> Double in
                    var next = after
                    _ = next.play(reply)
                    return evaluate(next)
                }.min() ?? evaluate(after)
                score = 0.3 * evaluate(after) + 0.7 * worstReply
            }
            if score > bestScore {
                bestScore = score
                bestMove = move
            }
        }
        return bestMove
    }

    private static func evaluate(_ game: UltimateGame) -> Double {
        switch game.result {
        case .won(.o): return 100_000
        case .won(.x): return -100_000
        case .drawn: return 0
        case .ongoing: break
        }
        let results = game.boardResults
        var score = 0.0
        let positionWeight: [Double] = [1.4, 1, 1.4, 1, 1.8, 1, 1.4, 1, 1.4]

        for board in 0..<9 {
            switch results[board] {
            case .won(.o): score += 24 * positionWeight[board]
            case .won(.x): score -= 24 * positionWeight[board]
            case .drawn: break
            case .ongoing:
                for line in UltimateGame.lines {
                    let marks = line.compactMap { game.cells[board][$0] }
                    let o = marks.filter { $0 == .o }.count
                    let x = marks.count - o
                    if o > 0 && x > 0 { continue }
                    if o > 0 { score += (o == 2 ? 5.0 : 0.8) * positionWeight[board] }
                    if x > 0 { score -= (x == 2 ? 5.4 : 0.8) * positionWeight[board] }
                }
            }
        }

        for line in UltimateGame.lines {
            var o = 0
            var x = 0
            var blocked = false
            for board in line {
                switch results[board] {
                case .won(.o): o += 1
                case .won(.x): x += 1
                case .drawn: blocked = true
                case .ongoing: break
                }
            }
            if blocked || (o > 0 && x > 0) { continue }
            if o > 0 { score += o == 2 ? 140 : 15 }
            if x > 0 { score -= x == 2 ? 150 : 15 }
        }
        return score
    }
}
