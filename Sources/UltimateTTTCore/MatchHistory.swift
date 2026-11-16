import Foundation

public enum PlayedMode: String, Codable, Sendable {
    case solo, online
}

public enum PlayedOutcome: String, Codable, Sendable {
    case win, loss, draw
}

public struct FinishedMatch: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let mode: PlayedMode
    public let difficulty: Difficulty?
    public let outcome: PlayedOutcome
    public let moves: Int
    public let finishedAt: Date

    public init(
        id: String, mode: PlayedMode, difficulty: Difficulty?,
        outcome: PlayedOutcome, moves: Int, finishedAt: Date = Date()
    ) {
        self.id = id
        self.mode = mode
        self.difficulty = difficulty
        self.outcome = outcome
        self.moves = moves
        self.finishedAt = finishedAt
    }
}

public struct MatchSummary: Equatable, Sendable {
    public var wins = 0
    public var losses = 0
    public var draws = 0

    public var total: Int { wins + losses + draws }
    public var winPercentage: Int {
        guard total > 0 else { return 0 }
        return Int((Double(wins) / Double(total) * 100).rounded())
    }
}

public struct MatchHistory: Codable, Equatable, Sendable {
    public private(set) var matches: [FinishedMatch] = []

    public init() {}

    /// Returns false for repeat Game Center match notifications or app restarts.
    @discardableResult
    public mutating func record(_ match: FinishedMatch) -> Bool {
        guard !matches.contains(where: { $0.id == match.id }) else { return false }
        matches.append(match)
        return true
    }

    @discardableResult
    public mutating func remove(id: String) -> Bool {
        guard let index = matches.firstIndex(where: { $0.id == id }) else { return false }
        matches.remove(at: index)
        return true
    }

    public func contains(id: String) -> Bool { matches.contains(where: { $0.id == id }) }

    public func summary(for mode: PlayedMode, difficulty: Difficulty? = nil) -> MatchSummary {
        var result = MatchSummary()
        for match in matches where match.mode == mode && (difficulty == nil || match.difficulty == difficulty) {
            switch match.outcome {
            case .win: result.wins += 1
            case .loss: result.losses += 1
            case .draw: result.draws += 1
            }
        }
        return result
    }

    public func winStreak(for mode: PlayedMode) -> Int {
        var streak = 0
        for match in matches.reversed() where match.mode == mode {
            guard match.outcome == .win else { break }
            streak += 1
        }
        return streak
    }

    public func bestWinStreak(for mode: PlayedMode) -> Int {
        var current = 0
        var best = 0
        for match in matches where match.mode == mode {
            if match.outcome == .win {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }
}
