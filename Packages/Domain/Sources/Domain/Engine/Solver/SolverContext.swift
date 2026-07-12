import Model

/// Immutable precomputation shared by every solve over one puzzle shape:
/// peer lists, house membership, cage lookups, and intersecting house pairs.
/// Built once per puzzle and reused across all solver runs and retries.
struct SolverContext {
    struct HousePair {
        /// House whose candidates may be confined to the shared cells.
        let source: Int
        /// House losing candidates outside the shared cells.
        let target: Int
        let sharedCells: [Int]
    }

    let topology: GridTopology
    let size: Int
    let cellCount: Int
    let houses: [[Int]]
    let houseKinds: [HouseKind]
    /// House indices containing each cell.
    let housesForCell: [[Int]]
    /// Distinct cells sharing a house or cage with each cell.
    let peers: [[Int]]
    let cages: [Cage]
    /// Cage index per cell, -1 when the cell is not caged.
    let cageIndexForCell: [Int]
    let parities: [Int: CellParity]
    /// Ordered pairs of distinct houses sharing at least two cells.
    let housePairs: [HousePair]
    /// Bitmask with one bit set per digit 1...size.
    let fullMask: UInt16

    init(topology: GridTopology, cages: [Cage] = [], parities: [Int: CellParity] = [:]) {
        self.topology = topology
        self.cages = cages
        self.parities = parities
        size = topology.size
        cellCount = topology.cellCount
        houses = topology.houses
        houseKinds = topology.houseKinds
        fullMask = UInt16((1 << topology.size) - 1)

        var membership = [[Int]](repeating: [], count: topology.cellCount)
        for (houseIndex, house) in topology.houses.enumerated() {
            for cell in house {
                membership[cell].append(houseIndex)
            }
        }
        housesForCell = membership

        var cageIndex = [Int](repeating: -1, count: topology.cellCount)
        for (index, cage) in cages.enumerated() {
            for cell in cage.cells {
                cageIndex[cell] = index
            }
        }
        cageIndexForCell = cageIndex

        var peerSets = [Set<Int>](repeating: [], count: topology.cellCount)
        for house in topology.houses {
            for cell in house {
                peerSets[cell].formUnion(house)
            }
        }
        // Cliques (argyle's short diagonals) are pairwise-distinct only:
        // they widen peer sets but never participate in house logic.
        for clique in topology.cliques {
            for cell in clique {
                peerSets[cell].formUnion(clique)
            }
        }
        for cage in cages {
            for cell in cage.cells {
                peerSets[cell].formUnion(cage.cells)
            }
        }
        peers = peerSets.enumerated().map { cell, set in
            set.subtracting([cell]).sorted()
        }

        var pairs: [HousePair] = []
        let houseSets = topology.houses.map(Set.init)
        for source in topology.houses.indices {
            for target in topology.houses.indices where source != target {
                let shared = houseSets[source].intersection(houseSets[target])
                guard shared.count >= 2 else { continue }
                // Pointless when the target has nothing outside the overlap.
                guard shared.count < topology.houses[target].count else { continue }
                pairs.append(HousePair(
                    source: source,
                    target: target,
                    sharedCells: shared.sorted(),
                ))
            }
        }
        housePairs = pairs
    }

    static func mask(for digit: Int) -> UInt16 {
        UInt16(1) << UInt16(digit - 1)
    }

    /// Digits present in a candidate mask, ascending.
    func digits(in mask: UInt16) -> [Int] {
        (1 ... size).filter { mask & Self.mask(for: $0) != 0 }
    }
}
