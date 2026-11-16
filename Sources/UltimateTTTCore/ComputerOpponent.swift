import Foundation

public enum Difficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case easy, medium, hard

    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }
}

/// Offline opponent. The human is X and the computer is O.
///
/// Easy makes varied, mostly random decisions. Medium prioritizes local wins
/// and useful positions. Hard searches both players' replies and considers the
/// nine-board win condition as well as which board a move forces next.
public enum ComputerOpponent {
    public static func chooseMove(in game: UltimateGame, difficulty: Difficulty) -> Move? {
        let legal = game.legalMoves
        guard !legal.isEmpty, game.currentPlayer == .o else { return nil }
        if difficulty == .easy { return legal.randomElement() }

        if difficulty == .medium {
            // Some variety prevents the medium opponent from always finding
            // the best move, while still favoring better board positions.
            let options = legal.map { move in
                (move: move, score: evaluatedMove(move, in: game) + Double.random(in: -7...7))
            }
            return options.max(by: { $0.score < $1.score })?.move
        }

        // Searching every branch of a free turn is exponential. Keep the most
        // promising root moves and use alpha-beta pruning at subsequent plies.
        let roots = orderedMoves(in: game, maxCount: legal.count > 18 ? 18 : legal.count)
        var best = roots[0]
        var bestScore = -Double.infinity
        var alpha = -Double.infinity
        let beta = Double.infinity
        var nodesRemaining = 6_000

        for move in roots {
            var next = game
            _ = next.play(move)
            let score = minimax(
                next, depth: 2, alpha: alpha, beta: beta,
                nodesRemaining: &nodesRemaining
            )
            if score > bestScore {
                bestScore = score
                best = move
            }
            alpha = max(alpha, bestScore)
        }
        return best
    }

    private static func evaluatedMove(_ move: Move, in game: UltimateGame) -> Double {
        var next = game
        _ = next.play(move)
        return evaluate(next)
    }

    private static func orderedMoves(in game: UltimateGame, maxCount: Int) -> [Move] {
        let maximize = game.currentPlayer == .o
        // Tiebreakers are stable so Hard behaves consistently across launches.
        return Array(game.legalMoves.sorted { left, right in
            let a = evaluatedMove(left, in: game)
            let b = evaluatedMove(right, in: game)
            if a != b { return maximize ? a > b : a < b }
            if left.board != right.board { return left.board < right.board }
            return left.cell < right.cell
        }.prefix(maxCount))
    }

    private static func minimax(
        _ game: UltimateGame,
        depth: Int,
        alpha: Double,
        beta: Double,
        nodesRemaining: inout Int
    ) -> Double {
        nodesRemaining -= 1
        guard depth > 0, game.result == .ongoing, nodesRemaining > 0 else {
            return evaluate(game)
        }

        let maximizing = game.currentPlayer == .o
        let moves = orderedMoves(in: game, maxCount: depth == 2 ? 10 : 8)
        var low = alpha
        var high = beta
        var best = maximizing ? -Double.infinity : Double.infinity

        for move in moves {
            var child = game
            _ = child.play(move)
            let value = minimax(
                child, depth: depth - 1, alpha: low, beta: high,
                nodesRemaining: &nodesRemaining
            )
            if maximizing {
                best = max(best, value)
                low = max(low, best)
            } else {
                best = min(best, value)
                high = min(high, best)
            }
            if high <= low || nodesRemaining <= 0 { break }
        }
        return best.isFinite ? best : evaluate(game)
    }

    private static func evaluate(_ game: UltimateGame) -> Double {
        switch game.result {
        case .won(.o): return 1_000_000
        case .won(.x): return -1_000_000
        case .drawn: return 0
        case .ongoing: break
        }

        let results = game.boardResults
        let weights: [Double] = [1.3, 1.0, 1.3, 1.0, 1.6, 1.0, 1.3, 1.0, 1.3]
        var score = 0.0

        for board in 0..<9 {
            let weight = weights[board]
            switch results[board] {
            case .won(.o): score += 80 * weight
            case .won(.x): score -= 80 * weight
            case .drawn: continue
            case .ongoing:
                for line in UltimateGame.lines {
                    let marks = line.compactMap { game.cells[board][$0] }
                    let oCount = marks.filter { $0 == .o }.count
                    let xCount = marks.count - oCount
                    if oCount > 0 && xCount > 0 { continue }
                    if oCount > 0 { score += (oCount == 2 ? 12 : 1.6) * weight }
                    if xCount > 0 { score -= (xCount == 2 ? 14 : 1.6) * weight }
                }
            }
        }

        // Owning two boards in a macro line is much more consequential than
        // simply accumulating isolated small boards.
        for line in UltimateGame.lines {
            let values = line.map { results[$0] }
            let oCount = values.filter { $0 == .won(.o) }.count
            let xCount = values.filter { $0 == .won(.x) }.count
            let hasDraw = values.contains(.drawn)
            if hasDraw || (oCount > 0 && xCount > 0) { continue }
            if oCount > 0 { score += oCount == 2 ? 360 : 32 }
            if xCount > 0 { score -= xCount == 2 ? 390 : 35 }
        }

        // A forced move to a nearly full board can be a tactical disadvantage:
        // the turn's destination matters, not just the square's local value.
        if let forced = game.forcedBoard, results[forced] == .ongoing {
            let empty = game.cells[forced].filter { $0 == nil }.count
            if empty <= 2 {
                score += game.currentPlayer == .o ? -2 : 2
            }
        }
        return score
    }
}
