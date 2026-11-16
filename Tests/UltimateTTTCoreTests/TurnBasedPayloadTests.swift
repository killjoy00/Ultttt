import Foundation
import XCTest
@testable import UltimateTTTCore

final class TurnBasedPayloadTests: XCTestCase {
    func testEmptyMatchStartsNewGame() throws {
        let payload = try TurnBasedPayload.decoded(from: nil)
        XCTAssertEqual(payload.game, UltimateGame())
    }

    func testLegalMovesRoundTrip() throws {
        var game = UltimateGame()
        XCTAssertTrue(game.play(Move(board: 4, cell: 2)))
        XCTAssertTrue(game.play(Move(board: 2, cell: 8)))
        let payload = try TurnBasedPayload.decoded(from: TurnBasedPayload(game: game).encoded())
        XCTAssertEqual(payload.game, game)
    }

    func testInvalidStateRejected() throws {
        var game = UltimateGame()
        XCTAssertTrue(game.play(Move(board: 0, cell: 8)))
        // Bad JSON replaces the advertised currentPlayer even though the moves are unchanged.
        let original = try TurnBasedPayload(game: game).encoded()
        var dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        var board = try XCTUnwrap(dictionary["game"] as? [String: Any])
        board["currentPlayer"] = "x"
        dictionary["game"] = board
        let invalid = try JSONSerialization.data(withJSONObject: dictionary)
        XCTAssertThrowsError(try TurnBasedPayload.decoded(from: invalid))
    }

    func testUnknownProtocolRejected() throws {
        let original = try TurnBasedPayload(game: UltimateGame()).encoded()
        var dictionary = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        dictionary["version"] = 999
        XCTAssertThrowsError(try TurnBasedPayload.decoded(from:
            JSONSerialization.data(withJSONObject: dictionary)))
    }
}
