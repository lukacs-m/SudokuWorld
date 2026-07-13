import Model

// Techniques+Chains: XY-wing and XY-chain — see the finders below.
extension Techniques {
    /// XY-wing: a bi-value pivot {x,y} sees two bi-value pincers {x,z} and
    /// {y,z}. Whichever value the pivot takes, one pincer becomes z — so any
    /// cell seeing both pincers loses z.
    static func xyWing(in grid: SolverGrid) -> SolveStep? {
        let context = grid.context
        let bivalue = bivalueCells(in: grid)
        guard bivalue.count >= 3 else { return nil }
        let masks = Dictionary(uniqueKeysWithValues: bivalue)

        for (pivot, pivotMask) in bivalue {
            let pincers = context.peers[pivot].filter { masks[$0] != nil }
            guard pincers.count >= 2 else { continue }

            for pair in combinations(of: pincers, choose: 2) {
                guard let firstMask = masks[pair[0]], let secondMask = masks[pair[1]] else {
                    continue
                }
                // Shared digit z between the pincers, not in the pivot; each
                // pincer shares its other digit with the pivot, covering it.
                let sharedZ = firstMask & secondMask & ~pivotMask
                guard sharedZ.nonzeroBitCount == 1 else { continue }
                guard (firstMask & pivotMask).nonzeroBitCount == 1,
                      (secondMask & pivotMask).nonzeroBitCount == 1,
                      (firstMask | secondMask) & pivotMask == pivotMask
                else { continue }

                let zDigit = sharedZ.trailingZeroBitCount + 1
                let exclusions: Set<Int> = [pivot, pair[0], pair[1]]
                let eliminations = commonPeerEliminations(
                    in: grid,
                    of: pair[0],
                    and: pair[1],
                    digit: zDigit,
                    excluding: exclusions,
                )
                guard !eliminations.isEmpty else { continue }
                return SolveStep(
                    technique: .xyWing,
                    eliminations: eliminations,
                    focusCells: [pivot, pair[0], pair[1]].sorted(),
                    focusDigits: [zDigit],
                )
            }
        }
        return nil
    }

    /// XY-chain: a path of bi-value cells where each link is forced by the
    /// previous cell's assignment. If assuming "the first cell is not `a`"
    /// forces the last cell to be `a`, then one of the two ends is `a` —
    /// so any cell seeing both ends loses `a`. Depth-bounded so stuck-proofs
    /// stay cheap; xyWing (the 3-cell case) runs first at a lower rank.
    static func xyChain(in grid: SolverGrid) -> SolveStep? {
        let context = grid.context
        let bivalue = bivalueCells(in: grid)
        guard bivalue.count >= 4 else { return nil }
        let masks = Dictionary(uniqueKeysWithValues: bivalue)
        let maxChainLength = 8

        for (start, startMask) in bivalue {
            for startDigit in context.digits(in: startMask) {
                let targetMask = SolverContext.mask(for: startDigit)
                var path = [start]
                var visited: Set<Int> = [start]

                func search(from cell: Int, forced: DigitMask) -> SolveStep? {
                    for peer in context.peers[cell] {
                        guard !visited.contains(peer),
                              let peerMask = masks[peer],
                              peerMask & forced != 0
                        else { continue }
                        let peerForced = peerMask & ~forced
                        guard peerForced.nonzeroBitCount == 1 else { continue }

                        if peerForced == targetMask, path.count >= 3 {
                            let eliminations = commonPeerEliminations(
                                in: grid,
                                of: start,
                                and: peer,
                                digit: startDigit,
                                excluding: visited.union([peer]),
                            )
                            if !eliminations.isEmpty {
                                return SolveStep(
                                    technique: .xyChain,
                                    eliminations: eliminations,
                                    focusCells: (path + [peer]).sorted(),
                                    focusDigits: [startDigit],
                                )
                            }
                        }
                        if path.count < maxChainLength {
                            path.append(peer)
                            visited.insert(peer)
                            if let step = search(from: peer, forced: peerForced) {
                                return step
                            }
                            path.removeLast()
                            visited.remove(peer)
                        }
                    }
                    return nil
                }

                // Assume start ≠ startDigit → start takes its other value.
                if let step = search(from: start, forced: startMask & ~targetMask) {
                    return step
                }
            }
        }
        return nil
    }

    // MARK: - Shared helpers

    /// Unsolved cells with exactly two candidates, ascending.
    private static func bivalueCells(in grid: SolverGrid) -> [(Int, DigitMask)] {
        let context = grid.context
        var cells: [(Int, DigitMask)] = []
        for cell in 0 ..< context.cellCount where grid.values[cell] == 0 {
            let mask = grid.candidates[cell]
            if mask.nonzeroBitCount == 2 {
                cells.append((cell, mask))
            }
        }
        return cells
    }

    /// Candidate eliminations for `digit` in cells seeing both endpoints.
    private static func commonPeerEliminations(
        in grid: SolverGrid,
        of first: Int,
        and second: Int,
        digit: Int,
        excluding: Set<Int>,
    ) -> [(cell: Int, digit: Int)] {
        let context = grid.context
        let mask = SolverContext.mask(for: digit)
        let secondPeers = Set(context.peers[second])
        var eliminations: [(cell: Int, digit: Int)] = []
        for cell in context.peers[first]
            where secondPeers.contains(cell)
            && !excluding.contains(cell)
            && grid.values[cell] == 0
            && grid.candidates[cell] & mask != 0
        {
            eliminations.append((cell: cell, digit: digit))
        }
        return eliminations
    }
}
