import Foundation

public enum Mark: String, Codable, CaseIterable, Sendable {
    case x, o

    public var opponent: Mark { self == .x ? .o : .x }
    public var symbol: String { rawValue.uppercased() }
}

public enum GameResult: Equatable, Codable, Sendable {
    case ongoing
    case won(Mark)
    case drawn

    public var isFinished: Bool { self != .ongoing }
}

public struct Move: Hashable, Codable, Sendable {
    public let board: Int
    public let cell: Int

    public init(board: Int, cell: Int) {
        self.board = board
        self.cell = cell
    }
}

public struct UltimateGame: Codable, Equatable, Sendable {
    public private(set) var cells: [[Mark?]]
    public private(set) var currentPlayer: Mark
    public private(set) var forcedBoard: Int?
    public private(set) var moves: [Move]

    public init() {
        cells = Array(repeating: Array(repeating: nil, count: 9), count: 9)
        currentPlayer = .x
        forcedBoard = nil
        moves = []
    }

    // Internal fixture initializer for rules tests.
    init(cells: [[Mark?]], currentPlayer: Mark = .x, forcedBoard: Int? = nil) {
        precondition(cells.count == 9 && cells.allSatisfy { $0.count == 9 })
        self.cells = cells
        self.currentPlayer = currentPlayer
        self.forcedBoard = forcedBoard
        self.moves = []
    }

    public var boardResults: [GameResult] { cells.map(Self.result) }

    /// The three squares that completed a small-board win, if there is one.
    public static func winningLine(in cells: [Mark?]) -> [Int]? {
        guard cells.count == 9 else { return nil }
        return lines.first { line in
            if let mark = cells[line[0]] {
                return cells[line[1]] == mark && cells[line[2]] == mark
            }
            return false
        }
    }


    public var result: GameResult {
        let owners = boardResults.map { result -> Mark? in
            if case .won(let mark) = result { return mark }
            return nil
        }
        for line in Self.lines {
            if let mark = owners[line[0]], owners[line[1]] == mark, owners[line[2]] == mark {
                return .won(mark)
            }
        }
        return boardResults.allSatisfy(\.isFinished) ? .drawn : .ongoing
    }

    public var legalBoards: [Int] {
        guard result == .ongoing else { return [] }
        let results = boardResults
        if let forcedBoard, (0..<9).contains(forcedBoard), results[forcedBoard] == .ongoing {
            return [forcedBoard]
        }
        return (0..<9).filter { results[$0] == .ongoing }
    }

    public var legalMoves: [Move] {
        legalBoards.flatMap { board in
            (0..<9).compactMap { cell in
                cells[board][cell] == nil ? Move(board: board, cell: cell) : nil
            }
        }
    }

    public func canPlay(_ move: Move) -> Bool {
        guard (0..<9).contains(move.board), (0..<9).contains(move.cell) else { return false }
        return legalBoards.contains(move.board) && cells[move.board][move.cell] == nil
    }

    @discardableResult
    public mutating func play(_ move: Move) -> Bool {
        guard canPlay(move) else { return false }
        cells[move.board][move.cell] = currentPlayer
        moves.append(move)
        forcedBoard = Self.result(cells[move.cell]) == .ongoing ? move.cell : nil
        currentPlayer = currentPlayer.opponent
        return true
    }

    @discardableResult
    public mutating func undo() -> Bool {
        guard !moves.isEmpty else { return false }
        let previousMoves = Array(moves.dropLast())
        self = UltimateGame()
        for move in previousMoves { _ = play(move) }
        return true
    }

    static let lines: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6]
    ]

    static func result(_ cells: [Mark?]) -> GameResult {
        for line in lines {
            if let mark = cells[line[0]], cells[line[1]] == mark, cells[line[2]] == mark {
                return .won(mark)
            }
        }
        return cells.contains(where: { $0 == nil }) ? .ongoing : .drawn
    }
}
