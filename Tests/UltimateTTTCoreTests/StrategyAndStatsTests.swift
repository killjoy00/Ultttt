import XCTest
@testable import UltimateTTTCore

final class ComputerStrategyTests: XCTestCase {
    func testHardTakesImmediateMacroWin() {
        var boards = Array(repeating: Array<Mark?>(repeating: nil, count: 9), count: 9)
        for board in [0, 1] {
            boards[board][0] = .o
            boards[board][1] = .o
            boards[board][2] = .o
        }
        boards[2][0] = .o
        boards[2][1] = .o

        let game = UltimateGame(cells: boards, currentPlayer: .o, forcedBoard: 2)
        let move = ComputerOpponent.chooseMove(in: game, difficulty: .hard)
        XCTAssertEqual(move, Move(board: 2, cell: 2))
    }

    func testAllLevelsMakeLegalMovesInForcedBoard() {
        var game = UltimateGame()
        _ = game.play(Move(board: 4, cell: 6))
        XCTAssertEqual(game.currentPlayer, .o)
        for difficulty in Difficulty.allCases {
            for _ in 0..<3 {
                guard let move = ComputerOpponent.chooseMove(in: game, difficulty: difficulty) else {
                    return XCTFail("Expected a legal move at \(difficulty)")
                }
                XCTAssertTrue(game.canPlay(move))
                XCTAssertEqual(move.board, 6)
            }
        }
    }
}

final class MatchHistoryTests: XCTestCase {
    func testIdempotentOnlineRecordingAndWinStreaks() {
        var history = MatchHistory()
        let first = FinishedMatch(id: "online:a", mode: .online, difficulty: nil, outcome: .win, moves: 24)
        XCTAssertTrue(history.record(first))
        XCTAssertFalse(history.record(first))
        XCTAssertTrue(history.record(FinishedMatch(
            id: "online:b", mode: .online, difficulty: nil, outcome: .win, moves: 35
        )))
        XCTAssertEqual(history.summary(for: .online).wins, 2)
        XCTAssertEqual(history.winStreak(for: .online), 2)
        XCTAssertTrue(history.record(FinishedMatch(
            id: "online:c", mode: .online, difficulty: nil, outcome: .loss, moves: 38
        )))
        XCTAssertEqual(history.winStreak(for: .online), 0)
        XCTAssertEqual(history.bestWinStreak(for: .online), 2)
        XCTAssertEqual(history.summary(for: .online).winPercentage, 67)
    }

    func testUndoReopensOnlyOneGameAndDifficultyIsTracked() {
        var history = MatchHistory()
        let first = FinishedMatch(id: "solo:1", mode: .solo, difficulty: .hard, outcome: .win, moves: 22)
        let second = FinishedMatch(id: "solo:2", mode: .solo, difficulty: .easy, outcome: .loss, moves: 32)
        history.record(first)
        history.record(second)
        XCTAssertEqual(history.summary(for: .solo).total, 2)
        XCTAssertEqual(history.summary(for: .solo, difficulty: .hard).wins, 1)
        XCTAssertEqual(history.summary(for: .solo, difficulty: .easy).losses, 1)
        XCTAssertTrue(history.remove(id: first.id))
        XCTAssertFalse(history.remove(id: first.id))
        XCTAssertEqual(history.summary(for: .solo).total, 1)
    }

    func testHistoryRoundTrips() throws {
        var history = MatchHistory()
        history.record(FinishedMatch(id: "solo:a", mode: .solo, difficulty: .medium, outcome: .draw, moves: 45))
        let data = try JSONEncoder().encode(history)
        XCTAssertEqual(try JSONDecoder().decode(MatchHistory.self, from: data), history)
    }
}
