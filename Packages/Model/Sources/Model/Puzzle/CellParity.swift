/// Even-Odd sudoku marks: a constrained cell only accepts digits of its parity.
public enum CellParity: String, Equatable, Sendable, Codable {
    case even
    case odd

    public func accepts(_ digit: Int) -> Bool {
        switch self {
        case .even: digit.isMultiple(of: 2)
        case .odd: !digit.isMultiple(of: 2)
        }
    }
}
