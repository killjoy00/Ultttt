import Foundation

/// Compact, versioned state transferred between Game Center participants.
public struct TurnBasedPayload: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public let version: Int
    public let game: UltimateGame

    public init(game: UltimateGame) {
        self.version = Self.currentVersion
        self.game = game
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decoded(from data: Data?) throws -> TurnBasedPayload {
        guard let data, !data.isEmpty else {
            return TurnBasedPayload(game: UltimateGame())
        }
        let value = try JSONDecoder().decode(TurnBasedPayload.self, from: data)
        guard value.version == currentVersion else {
            throw PayloadError.unsupportedVersion
        }

        // A remote board must be reproducible by replaying legal moves. Never trust
        // arbitrary decoded cells, currentPlayer, or forcedBoard from the network.
        var replayed = UltimateGame()
        for move in value.game.moves {
            guard replayed.play(move) else { throw PayloadError.invalidMoves }
        }
        guard replayed == value.game else { throw PayloadError.invalidMoves }
        return value
    }

    public enum PayloadError: LocalizedError {
        case unsupportedVersion, invalidMoves

        public var errorDescription: String? {
            switch self {
            case .unsupportedVersion: return "This match uses an unsupported game version."
            case .invalidMoves: return "The Game Center match contains invalid moves."
            }
        }
    }
}
