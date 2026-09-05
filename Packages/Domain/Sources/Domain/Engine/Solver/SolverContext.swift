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

    /// Every bent line meeting one face, grouped by face so a solve scans the
    /// face's candidates once instead of once per line.
    struct FoldFace {
        /// Face whose candidates may be confined to its part of a bent line.
        let face: Int
        /// Per bent line: the face's cells on it, then the line's cells beyond
        /// the fold, on the neighbouring face.
        let lines: [(cells: [Int], continuation: [Int])]
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
    /// Every face met by a bent line on fold variants; empty elsewhere.
    let foldFaces: [FoldFace]
    /// Bitmask with one bit set per digit 1...size.
    let fullMask: DigitMask
    /// Pairwise constraints (marks plus expanded negatives). Thermometers
    /// are chains of strict greater-than edges, so they live here too.
    let relationEdges: [RelationEdge]
    /// Indices into `relationEdges` touching each cell.
    let relationsForCell: [[Int]]
    /// Summed runs (arrow shafts; little-killer diagonals).
    let sumLines: [SumLine]
    /// Indices into `sumLines` involving each cell (shaft or target).
    let sumLinesForCell: [[Int]]
    /// Sandwich and skyscraper clues with their resolved lines (edge-first).
    let outsideLines: [OutsideLine]
    /// Indices into `outsideLines` involving each cell.
    let outsideLinesForCell: [[Int]]

    /// `expandsNegativeConvention` exists for one caller: generation-time
    /// filling of mark-deriving variants (kropki/XV/consecutive), where
    /// marks don't exist yet and "no mark" must not mean "constrained".
    init(
        topology: GridTopology,
        cages: [Cage] = [],
        parities: [Int: CellParity] = [:],
        relations: [RelationClue] = [],
        thermometers: [[Int]] = [],
        arrows: [Arrow] = [],
        outsideClues: [OutsideClue] = [],
        expandsNegativeConvention: Bool = true,
    ) {
        self.topology = topology
        self.cages = cages
        self.parities = parities
        size = topology.size
        cellCount = topology.cellCount
        houses = topology.houses
        houseKinds = topology.houseKinds
        fullMask = DigitMask((1 << topology.size) - 1)

        relationEdges = Self.buildRelationEdges(
            topology: topology,
            relations: relations,
            thermometers: thermometers,
            includeNegatives: expandsNegativeConvention,
        )
        relationsForCell = Self.endpointMembership(of: relationEdges, cellCount: cellCount)

        let resolved = Self.buildLines(
            arrows: arrows,
            outsideClues: outsideClues,
            topology: topology,
        )
        sumLines = resolved.sumLines
        outsideLines = resolved.outsideLines
        sumLinesForCell = Self.sumLineMembership(of: sumLines, cellCount: cellCount)
        outsideLinesForCell = Self.outsideLineMembership(of: outsideLines, cellCount: cellCount)

        housesForCell = Self.houseMembership(of: topology)
        cageIndexForCell = Self.cageIndexMap(cages: cages, cellCount: cellCount)
        peers = Self.buildPeers(topology: topology, cages: cages)
        housePairs = Self.buildHousePairs(of: topology)
        foldFaces = Self.buildFoldFaces(of: topology)
    }

    static func mask(for digit: Int) -> DigitMask {
        DigitMask(1) << DigitMask(digit - 1)
    }

    /// Digits present in a candidate mask, ascending.
    func digits(in mask: DigitMask) -> [Int] {
        (1 ... size).filter { mask & Self.mask(for: $0) != 0 }
    }

    // MARK: - Construction

    /// Marks (plus their variant's negative convention) and thermometers,
    /// flattened into pairwise solver edges.
    private static func buildRelationEdges(
        topology: GridTopology,
        relations: [RelationClue],
        thermometers: [[Int]],
        includeNegatives: Bool,
    ) -> [RelationEdge] {
        var edges = RelationExpansion.edges(
            variant: topology.variant,
            relations: relations,
            topology: topology,
            includeNegatives: includeNegatives,
        )
        for path in thermometers {
            for step in 1 ..< path.count {
                edges.append(RelationEdge(a: path[step], b: path[step - 1], constraint: .greater))
            }
        }
        return edges
    }

    private static func endpointMembership(
        of edges: [RelationEdge],
        cellCount: Int,
    ) -> [[Int]] {
        var membership = [[Int]](repeating: [], count: cellCount)
        for (index, edge) in edges.enumerated() {
            membership[edge.a].append(index)
            membership[edge.b].append(index)
        }
        return membership
    }

    /// Little-killer diagonals are plain fixed-sum lines; sandwich and
    /// skyscraper clues need their own reasoning.
    private static func buildLines(
        arrows: [Arrow],
        outsideClues: [OutsideClue],
        topology: GridTopology,
    ) -> (sumLines: [SumLine], outsideLines: [OutsideLine]) {
        var summed = arrows.map { SumLine(cells: $0.shaft, target: .cell($0.circle)) }
        var edgeClued: [OutsideLine] = []
        for clue in outsideClues {
            let cells = OutsideClues.line(for: clue, topology: topology)
            guard cells.count >= 2 else { continue }
            switch clue.kind {
            case .diagonalSum:
                summed.append(SumLine(cells: cells, target: .fixed(clue.value)))

            case .sandwichSum, .skyscraperCount:
                edgeClued.append(OutsideLine(clue: clue, cells: cells))
            }
        }
        return (summed, edgeClued)
    }

    private static func sumLineMembership(of lines: [SumLine], cellCount: Int) -> [[Int]] {
        var membership = [[Int]](repeating: [], count: cellCount)
        for (index, line) in lines.enumerated() {
            for cell in line.cells {
                membership[cell].append(index)
            }
            if case let .cell(target) = line.target {
                membership[target].append(index)
            }
        }
        return membership
    }

    private static func outsideLineMembership(
        of lines: [OutsideLine],
        cellCount: Int,
    ) -> [[Int]] {
        var membership = [[Int]](repeating: [], count: cellCount)
        for (index, line) in lines.enumerated() {
            for cell in line.cells {
                membership[cell].append(index)
            }
        }
        return membership
    }

    private static func houseMembership(of topology: GridTopology) -> [[Int]] {
        var membership = [[Int]](repeating: [], count: topology.cellCount)
        for (houseIndex, house) in topology.houses.enumerated() {
            for cell in house {
                membership[cell].append(houseIndex)
            }
        }
        return membership
    }

    private static func cageIndexMap(cages: [Cage], cellCount: Int) -> [Int] {
        var cageIndex = [Int](repeating: -1, count: cellCount)
        for (index, cage) in cages.enumerated() {
            for cell in cage.cells {
                cageIndex[cell] = index
            }
        }
        return cageIndex
    }

    private static func buildPeers(topology: GridTopology, cages: [Cage]) -> [[Int]] {
        var peerSets = [Set<Int>](repeating: [], count: topology.cellCount)
        for house in topology.houses {
            for cell in house {
                peerSets[cell].formUnion(house)
            }
        }
        // Cliques (argyle's short diagonals, chess-move pairs) are
        // pairwise-distinct only: they widen peer sets but never
        // participate in house logic.
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
        return peerSets.enumerated().map { cell, set in
            set.subtracting([cell]).sorted()
        }
    }

    private static func buildHousePairs(of topology: GridTopology) -> [HousePair] {
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
        return pairs
    }

    /// Bent lines are the one kind of clique house logic reasons over: a
    /// face holds every digit, so a digit confined to the face's part of a
    /// bent line is locked out of the continuation. The deduction would be
    /// sound for any clique, but argyle diagonals and chess moves stay
    /// pairwise-only so those variants keep grading as they ship today.
    private static func buildFoldFaces(of topology: GridTopology) -> [FoldFace] {
        guard topology.variant == .cube || topology.variant == .tredoku else { return [] }
        var faces: [FoldFace] = []
        for (face, house) in topology.houses.enumerated() {
            let houseSet = Set(house)
            var lines: [(cells: [Int], continuation: [Int])] = []
            for clique in topology.cliques {
                let lineCells = clique.filter(houseSet.contains)
                guard lineCells.count >= 2, lineCells.count < clique.count else { continue }
                lines.append((cells: lineCells, continuation: clique.filter { !houseSet.contains($0) }))
            }
            guard !lines.isEmpty else { continue }
            faces.append(FoldFace(face: face, lines: lines))
        }
        return faces
    }
}
