import Foundation
import Testing
@testable import Model

@Suite
struct CellNotesTests {
    @Test func startsEmpty() {
        let notes = CellNotes()
        #expect(notes.isEmpty)
        #expect(notes.digits.isEmpty)
    }

    @Test func insertRemoveContains() {
        var notes = CellNotes()
        notes.insert(3)
        notes.insert(9)
        #expect(notes.contains(3))
        #expect(notes.contains(9))
        #expect(!notes.contains(4))
        #expect(notes.digits == [3, 9])
        #expect(notes.count == 2)

        notes.remove(3)
        #expect(!notes.contains(3))
        #expect(notes.digits == [9])
    }

    @Test func toggleFlips() {
        var notes = CellNotes()
        notes.toggle(5)
        #expect(notes.contains(5))
        notes.toggle(5)
        #expect(!notes.contains(5))
    }

    @Test func insertIsIdempotent() {
        var notes = CellNotes()
        notes.insert(7)
        notes.insert(7)
        #expect(notes.count == 1)
    }

    @Test func sequenceInitializer() {
        let notes = CellNotes([1, 2, 16])
        #expect(notes.digits == [1, 2, 16])
    }

    @Test func digitsBeyondSixteenFitTheWidenedMask() {
        let notes = CellNotes([17, 20, 25])
        #expect(notes.digits == [17, 20, 25])
        #expect(notes.contains(25))
    }

    /// Saves written before the UInt16 → UInt32 widening stored the raw
    /// value as a JSON number; it must decode into the wider type as-is.
    @Test func legacySixteenBitRawValueDecodes() throws {
        let legacy = Data(#"{"rawValue": 65535}"#.utf8)
        let notes = try JSONDecoder().decode(CellNotes.self, from: legacy)
        #expect(notes.digits == Array(1 ... 16))
    }

    @Test func outOfRangeDigitsAreIgnored() {
        var notes = CellNotes()
        notes.insert(0)
        notes.insert(33)
        #expect(notes.isEmpty)
    }

    @Test func removeAllClears() {
        var notes = CellNotes([4, 5, 6])
        notes.removeAll()
        #expect(notes.isEmpty)
    }

    @Test func codableRoundtrip() throws {
        let original = CellNotes([2, 4, 8])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CellNotes.self, from: data)
        #expect(decoded == original)
    }
}
