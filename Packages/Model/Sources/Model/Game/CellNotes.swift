/// A compact set of pencil-mark digits (1...16) backed by a bitmask.
public struct CellNotes: Hashable, Sendable, Codable {
    public private(set) var rawValue: UInt16

    public init() {
        rawValue = 0
    }

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public init(_ digits: some Sequence<Int>) {
        rawValue = digits.reduce(into: UInt16(0)) { partial, digit in
            partial |= Self.mask(for: digit)
        }
    }

    public var isEmpty: Bool {
        rawValue == 0
    }

    public var count: Int {
        rawValue.nonzeroBitCount
    }

    /// The noted digits in ascending order.
    public var digits: [Int] {
        (1 ... 16).filter { contains($0) }
    }

    public func contains(_ digit: Int) -> Bool {
        rawValue & Self.mask(for: digit) != 0
    }

    public mutating func insert(_ digit: Int) {
        rawValue |= Self.mask(for: digit)
    }

    public mutating func remove(_ digit: Int) {
        rawValue &= ~Self.mask(for: digit)
    }

    public mutating func toggle(_ digit: Int) {
        rawValue ^= Self.mask(for: digit)
    }

    public mutating func removeAll() {
        rawValue = 0
    }

    private static func mask(for digit: Int) -> UInt16 {
        guard digit >= 1, digit <= 16 else { return 0 }
        return UInt16(1) << UInt16(digit - 1)
    }
}
