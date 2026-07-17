/// An arrow clue: the digits along the shaft sum to the digit in the
/// circled cell. Shaft order runs outward from the circle.
public struct Arrow: Hashable, Sendable, Codable {
    public let circle: Int
    public let shaft: [Int]

    public init(circle: Int, shaft: [Int]) {
        self.circle = circle
        self.shaft = shaft
    }
}
