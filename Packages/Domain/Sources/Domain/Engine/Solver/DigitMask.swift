/// The candidate bitmask type: one bit per digit 1...size. UInt32 admits
/// grids up to 32 digits (alphadoku's 25×25); anything larger must widen
/// this alias and `CellNotes.rawValue` together.
typealias DigitMask = UInt32
