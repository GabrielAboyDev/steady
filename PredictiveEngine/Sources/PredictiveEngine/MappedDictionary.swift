import Foundation

/// Read-only view over the bytes of an `.sdict` file.
///
/// Nothing is parsed up front beyond the 64-byte header. When the backing
/// `Data` is memory-mapped (`Data(contentsOf:options:.mappedIfSafe)`), a query
/// touches only the pages holding the nodes it walks, so a multi-megabyte
/// dictionary costs a few hundred kilobytes of resident memory however much
/// of it exists on disk.
///
/// Reads are bounds-checked against the header so a truncated or corrupt
/// file degrades to empty results rather than reading out of bounds.
struct MappedDictionary: Sendable {

    enum LoadError: Error, Equatable {
        case truncated
        case badMagic
        case unsupportedVersion(UInt32)
        case corruptHeader
    }

    private let data: Data
    private let header: SDictFormat.Header

    /// Validate the header and section bounds. Does not read the sections.
    init(data: Data) throws {
        guard data.count >= SDictFormat.headerSize else { throw LoadError.truncated }
        let header: SDictFormat.Header = try data.withUnsafeBytes { raw in
            for (i, byte) in SDictFormat.magic.enumerated() where raw[i] != byte {
                throw LoadError.badMagic
            }
            let version = raw.loadLE(UInt32.self, at: SDictFormat.HeaderField.version)
            guard version == SDictFormat.version else { throw LoadError.unsupportedVersion(version) }
            return SDictFormat.Header(
                nodeCount: Int(raw.loadLE(UInt32.self, at: SDictFormat.HeaderField.nodeCount)),
                nodesOffset: Int(raw.loadLE(UInt32.self, at: SDictFormat.HeaderField.nodesOffset)),
                headCount: Int(raw.loadLE(UInt32.self, at: SDictFormat.HeaderField.headCount)),
                headsOffset: Int(raw.loadLE(UInt32.self, at: SDictFormat.HeaderField.headsOffset)),
                followerCount: Int(raw.loadLE(UInt32.self, at: SDictFormat.HeaderField.followerCount)),
                followersOffset: Int(raw.loadLE(UInt32.self, at: SDictFormat.HeaderField.followersOffset)),
                stringPoolOffset: Int(raw.loadLE(UInt32.self, at: SDictFormat.HeaderField.stringPoolOffset)),
                stringPoolLength: Int(raw.loadLE(UInt32.self, at: SDictFormat.HeaderField.stringPoolLength))
            )
        }
        func fits(_ offset: Int, _ count: Int, _ size: Int) -> Bool {
            offset >= SDictFormat.headerSize && count >= 0
                && offset + count * size <= data.count
        }
        guard header.nodeCount >= 1,
              fits(header.nodesOffset, header.nodeCount, SDictFormat.nodeSize),
              fits(header.headsOffset, header.headCount, SDictFormat.headSize),
              fits(header.followersOffset, header.followerCount, SDictFormat.followerSize),
              fits(header.stringPoolOffset, header.stringPoolLength, 1)
        else { throw LoadError.truncated }
        self.data = data
        self.header = header
    }

    // MARK: - Queries

    /// Aggregate weight of every word continuing through each byte that can
    /// follow `prefix`. Only ASCII labels map to a `Character`; multi-byte
    /// UTF-8 lead bytes are skipped (no key on the layout for them).
    func nextLetterWeights(forPrefix prefix: String) -> [Character: Double] {
        let bytes = Array(prefix.lowercased().utf8)
        return data.withUnsafeBytes { raw in
            let reader = Reader(raw: raw, header: header)
            guard let index = reader.nodeIndex(forPrefix: bytes) else { return [:] }
            let node = reader.node(index)
            var weights: [Character: Double] = [:]
            for childIndex in reader.childRange(of: node) {
                let child = reader.node(childIndex)
                guard child.label < 0x80 else { continue }
                weights[Character(UnicodeScalar(child.label))] = Double(child.aggregateFrequency)
            }
            return weights
        }
    }

    /// Top `limit` words under `prefix`, best first, via best-first search.
    ///
    /// A node's aggregate frequency bounds every word in its subtree, so the
    /// search pops nodes by aggregate and stops as soon as the worst collected
    /// word is at least as good as the best remaining bound. On Zipf-shaped
    /// data this terminates after a few dozen pops even for the empty prefix.
    func completions(forPrefix prefix: String, limit: Int) -> [WordScore] {
        guard limit > 0 else { return [] }
        let bytes = Array(prefix.lowercased().utf8)
        return data.withUnsafeBytes { raw in
            let reader = Reader(raw: raw, header: header)
            guard let start = reader.nodeIndex(forPrefix: bytes) else { return [] }

            var frontier = MaxHeap<Frontier>()
            frontier.push(Frontier(index: start, bound: reader.node(start).aggregateFrequency, path: bytes))
            var results: [WordScore] = []
            var expansions = 0

            while let top = frontier.pop() {
                if results.count >= limit, let worst = results.last, Float(worst.score) >= top.bound {
                    break
                }
                expansions += 1
                if expansions > MappedDictionary.maxExpansions { break }

                let node = reader.node(top.index)
                if node.isTerminal {
                    let candidate = WordScore(
                        word: String(decoding: top.path, as: UTF8.self),
                        score: Double(node.wordFrequency)
                    )
                    insert(candidate, into: &results, limit: limit)
                }
                for childIndex in reader.childRange(of: node) {
                    let child = reader.node(childIndex)
                    var path = top.path
                    path.append(child.label)
                    frontier.push(Frontier(index: childIndex, bound: child.aggregateFrequency, path: path))
                }
            }
            return results
        }
    }

    /// Likely next words after `previous`, best first.
    func predictNextWord(after previous: String, limit: Int) -> [WordScore] {
        guard limit > 0, header.headCount > 0 else { return [] }
        let key = Array(previous.lowercased().utf8)
        return data.withUnsafeBytes { raw in
            let reader = Reader(raw: raw, header: header)
            // Binary search the heads by the UTF-8 bytes of the word.
            var low = 0
            var high = header.headCount - 1
            while low <= high {
                let mid = (low + high) / 2
                let head = reader.head(mid)
                switch reader.compare(stringAt: head.stringOffset, to: key) {
                case .orderedSame:
                    var results: [WordScore] = []
                    let end = min(head.followerStart + head.followerCount, header.followerCount)
                    for i in head.followerStart..<min(end, head.followerStart + limit) {
                        let follower = reader.follower(i)
                        guard let word = reader.string(at: follower.stringOffset) else { continue }
                        results.append(WordScore(word: word, score: Double(follower.score)))
                    }
                    return results
                case .orderedAscending:
                    low = mid + 1
                case .orderedDescending:
                    high = mid - 1
                }
            }
            return []
        }
    }

    // MARK: - Internals

    /// Safety valve for pathological inputs (e.g. flat frequencies).
    static let maxExpansions = 5000

    private struct Frontier: Comparable {
        let index: Int
        let bound: Float
        let path: [UInt8]
        static func < (a: Frontier, b: Frontier) -> Bool { a.bound < b.bound }
        static func == (a: Frontier, b: Frontier) -> Bool { a.bound == b.bound && a.index == b.index }
    }

    /// Keep `results` sorted best-first and no longer than `limit`.
    private func insert(_ candidate: WordScore, into results: inout [WordScore], limit: Int) {
        if results.count >= limit, let worst = results.last, candidate.score <= worst.score { return }
        let position = results.firstIndex { $0.score < candidate.score } ?? results.count
        results.insert(candidate, at: position)
        if results.count > limit { results.removeLast() }
    }

    struct Node {
        let label: UInt8
        let flags: UInt8
        let childCount: Int
        let firstChild: Int
        let wordFrequency: Float
        let aggregateFrequency: Float
        var isTerminal: Bool { flags & SDictFormat.terminalFlag != 0 }
    }

    struct Head {
        let stringOffset: Int
        let followerStart: Int
        let followerCount: Int
    }

    struct Follower {
        let stringOffset: Int
        let score: Float
    }

    /// Record accessors over the raw bytes for the duration of one query.
    struct Reader {
        let raw: UnsafeRawBufferPointer
        let header: SDictFormat.Header

        func node(_ index: Int) -> Node {
            let base = header.nodesOffset + index * SDictFormat.nodeSize
            return Node(
                label: raw[base + SDictFormat.NodeField.label],
                flags: raw[base + SDictFormat.NodeField.flags],
                childCount: Int(raw.loadLE(UInt16.self, at: base + SDictFormat.NodeField.childCount)),
                firstChild: Int(raw.loadLE(UInt32.self, at: base + SDictFormat.NodeField.firstChild)),
                wordFrequency: raw.loadFloatLE(at: base + SDictFormat.NodeField.wordFrequency),
                aggregateFrequency: raw.loadFloatLE(at: base + SDictFormat.NodeField.aggregateFrequency)
            )
        }

        /// Indices of `node`'s children, clamped to the node array.
        func childRange(of node: Node) -> Range<Int> {
            let start = min(node.firstChild, header.nodeCount)
            let end = min(node.firstChild + node.childCount, header.nodeCount)
            return start..<max(start, end)
        }

        /// Binary search `node`'s (label-sorted) children for `label`.
        func child(of node: Node, label: UInt8) -> Int? {
            let range = childRange(of: node)
            var low = range.lowerBound
            var high = range.upperBound - 1
            while low <= high {
                let mid = (low + high) / 2
                let candidate = raw[header.nodesOffset + mid * SDictFormat.nodeSize + SDictFormat.NodeField.label]
                if candidate == label { return mid }
                if candidate < label { low = mid + 1 } else { high = mid - 1 }
            }
            return nil
        }

        func nodeIndex(forPrefix bytes: [UInt8]) -> Int? {
            var index = 0
            for byte in bytes {
                guard let next = child(of: node(index), label: byte) else { return nil }
                index = next
            }
            return index
        }

        func head(_ index: Int) -> Head {
            let base = header.headsOffset + index * SDictFormat.headSize
            return Head(
                stringOffset: Int(raw.loadLE(UInt32.self, at: base + SDictFormat.HeadField.stringOffset)),
                followerStart: Int(raw.loadLE(UInt32.self, at: base + SDictFormat.HeadField.followerStart)),
                followerCount: Int(raw.loadLE(UInt32.self, at: base + SDictFormat.HeadField.followerCount))
            )
        }

        func follower(_ index: Int) -> Follower {
            let base = header.followersOffset + index * SDictFormat.followerSize
            return Follower(
                stringOffset: Int(raw.loadLE(UInt32.self, at: base + SDictFormat.FollowerField.stringOffset)),
                score: raw.loadFloatLE(at: base + SDictFormat.FollowerField.score)
            )
        }

        /// The bytes of the `[length][utf8]` record at `offset` in the pool.
        func stringBytes(at offset: Int) -> UnsafeRawBufferPointer.SubSequence? {
            let start = header.stringPoolOffset + offset
            let poolEnd = header.stringPoolOffset + header.stringPoolLength
            guard offset >= 0, start < poolEnd else { return nil }
            let length = Int(raw[start])
            guard start + 1 + length <= poolEnd else { return nil }
            return raw[(start + 1)..<(start + 1 + length)]
        }

        func string(at offset: Int) -> String? {
            stringBytes(at: offset).map { String(decoding: $0, as: UTF8.self) }
        }

        func compare(stringAt offset: Int, to key: [UInt8]) -> ComparisonResult {
            guard let bytes = stringBytes(at: offset) else { return .orderedAscending }
            if bytes.elementsEqual(key) { return .orderedSame }
            return bytes.lexicographicallyPrecedes(key) ? .orderedAscending : .orderedDescending
        }
    }

    /// A minimal binary max-heap.
    private struct MaxHeap<Element: Comparable> {
        private var items: [Element] = []

        mutating func push(_ element: Element) {
            items.append(element)
            var child = items.count - 1
            while child > 0 {
                let parent = (child - 1) / 2
                guard items[parent] < items[child] else { break }
                items.swapAt(parent, child)
                child = parent
            }
        }

        mutating func pop() -> Element? {
            guard !items.isEmpty else { return nil }
            items.swapAt(0, items.count - 1)
            let top = items.removeLast()
            var parent = 0
            while true {
                let left = 2 * parent + 1
                let right = left + 1
                var largest = parent
                if left < items.count, items[largest] < items[left] { largest = left }
                if right < items.count, items[largest] < items[right] { largest = right }
                guard largest != parent else { break }
                items.swapAt(parent, largest)
                parent = largest
            }
            return top
        }
    }
}

private extension UnsafeRawBufferPointer {
    func loadLE<T: FixedWidthInteger>(_ type: T.Type, at offset: Int) -> T {
        T(littleEndian: loadUnaligned(fromByteOffset: offset, as: T.self))
    }

    func loadFloatLE(at offset: Int) -> Float {
        Float(bitPattern: loadLE(UInt32.self, at: offset))
    }
}
