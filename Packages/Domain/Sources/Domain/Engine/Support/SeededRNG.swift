// Deterministic pseudo-random generators for puzzle generation.
//
// The engine never touches `SystemRandomNumberGenerator`: daily challenges
// must produce byte-identical puzzles on every device from a date-derived
// seed, so all randomness flows through these seeded generators.

/// SplitMix64 — fast seed expansion and deterministic seed evolution
/// (`nextAttemptSeed`) between generation retries.
public struct SplitMix64: Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }

    /// The deterministic successor seed used when a generation attempt misses
    /// its difficulty target and the pipeline retries.
    public static func evolve(_ seed: UInt64) -> UInt64 {
        var mix = Self(seed: seed)
        return mix.next()
    }
}

/// xoshiro256** — the general-purpose deterministic generator handed to
/// shuffles and choices throughout the engine.
public struct Xoshiro256StarStar: RandomNumberGenerator, Sendable {
    private var state0: UInt64
    private var state1: UInt64
    private var state2: UInt64
    private var state3: UInt64

    public init(seed: UInt64) {
        var mix = SplitMix64(seed: seed)
        state0 = mix.next()
        state1 = mix.next()
        state2 = mix.next()
        state3 = mix.next()
        // The all-zero state is the one invalid seed for xoshiro.
        if state0 | state1 | state2 | state3 == 0 {
            state0 = 0x9E37_79B9_7F4A_7C15
        }
    }

    public mutating func next() -> UInt64 {
        let result = rotl(state1 &* 5, 7) &* 9
        let shifted = state1 << 17
        state2 ^= state0
        state3 ^= state1
        state1 ^= state2
        state0 ^= state3
        state2 ^= shifted
        state3 = rotl(state3, 45)
        return result
    }

    private func rotl(_ value: UInt64, _ amount: UInt64) -> UInt64 {
        (value << amount) | (value >> (64 - amount))
    }
}
