import XCTest
@testable import UltimateTTTCore

final class UltimateGameTests: XCTestCase {
    func testOpeningAllowsAll81Cells() {
        let game = UltimateGame()
        XCTAssertEqual(game.legalMoves.count, 81)
        XCTAssertNil(game.forcedBoard)
        XCTAssertEqual(game.currentPlayer, .x)
    }

    func testMoveSendsOpponentToMatchingBoard() {
        var game = UltimateGame()
        XCTAssertTrue(game.play(Move(board: 4, cell: 2)))
        XCTAssertEqual(game.forcedBoard, 2)
        XCTAssertEqual(game.legalBoards, [2])
        XCTAssertFalse(game.play(Move(board: 3, cell: 4)))
        XCTAssertTrue(game.play(Move(board: 2, cell: 0)))
        XCTAssertEqual(game.forcedBoard, 0)
    }

    func testWonDestinationReleasesConstraint() {
        var boards = emptyBoards()
        boards[2][0] = .x; boards[2][1] = .x; boards[2][2] = .x
        let game = UltimateGame(cells: boards, forcedBoard: 2)
        XCTAssertEqual(game.legalBoards, [0, 1, 3, 4, 5, 6, 7, 8])
        var played = game
        XCTAssertTrue(played.play(Move(board: 4, cell: 2)))
        XCTAssertNil(played.forcedBoard)
    }

    func testLocalWinAndOverallWin() {
        var boards = emptyBoards()
        for board in [0, 1, 2] { boards[board][0] = .x; boards[board][1] = .x; boards[board][2] = .x }
        let game = UltimateGame(cells: boards)
        XCTAssertEqual(game.boardResults[0], .won(.x))
        XCTAssertEqual(game.result, .won(.x))
        XCTAssertTrue(game.legalMoves.isEmpty)
    }

    func testDrawnBoardDoesNotCountAsAWonBoard() {
        var boards = emptyBoards()
        boards[0] = [.x, .o, .x, .x, .o, .o, .o, .x, .x]
        XCTAssertEqual(UltimateGame.result(boards[0]), .drawn)
        boards[1][0] = .x; boards[1][1] = .x; boards[1][2] = .x
        boards[2][0] = .x; boards[2][1] = .x; boards[2][2] = .x
        XCTAssertEqual(UltimateGame(cells: boards).result, .ongoing)
    }

    func testUndoRewindsBoardAndForcedMove() {
        var game = UltimateGame()
        _ = game.play(Move(board: 4, cell: 6))
        _ = game.play(Move(board: 6, cell: 0))
        XCTAssertTrue(game.undo())
        XCTAssertEqual(game.moves.count, 1)
        XCTAssertEqual(game.currentPlayer, .o)
        XCTAssertEqual(game.forcedBoard, 6)
        XCTAssertNil(game.cells[6][0])
    }

    func testInvalidIndicesNeverCrashOrMutate() {
        var game = UltimateGame()
        XCTAssertFalse(game.play(Move(board: -1, cell: 1)))
        XCTAssertFalse(game.play(Move(board: 0, cell: 9)))
        XCTAssertTrue(game.moves.isEmpty)
    }

    func testWinningLineIdentifiesTheActualThreeSquares() {
        let horizontal: [Mark?] = [.o, .o, .o, nil, .x, nil, nil, nil, .x]
        let diagonal: [Mark?] = [.x, .o, nil, .o, .x, nil, nil, nil, .x]
        let unfinished: [Mark?] = [.x, .o, nil, nil, nil, nil, nil, nil, nil]
        XCTAssertEqual(UltimateGame.winningLine(in: horizontal), [0, 1, 2])
        XCTAssertEqual(UltimateGame.winningLine(in: diagonal), [0, 4, 8])
        XCTAssertNil(UltimateGame.winningLine(in: unfinished))
        XCTAssertNil(UltimateGame.winningLine(in: []))
    }

    func testComputerAlwaysChoosesLegalMove() {
        var game = UltimateGame()
        _ = game.play(Move(board: 4, cell: 4))
        for difficulty in Difficulty.allCases {
            let move = ComputerOpponent.chooseMove(in: game, difficulty: difficulty)
            XCTAssertNotNil(move)
            if let move { XCTAssertTrue(game.canPlay(move)) }
        }
    }

    private func emptyBoards() -> [[Mark?]] {
        Array(repeating: Array(repeating: nil, count: 9), count: 9)
    }
}
