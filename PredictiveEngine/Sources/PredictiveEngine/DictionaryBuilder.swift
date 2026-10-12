import Foundation

/// Compiles a lexicon and bigram model into the `.sdict` binary format.
///
/// Used by the offline `sdict-compile` tool to produce the bundled dictionary,
/// and by `PredictiveEngine.init(lexicon:bigrams:)` so tests and small callers
/// exercise exactly the same reader code path as the shipped file.
public enum DictionaryBuilder {

    /// Build the bytes of an `.sdict` file.
    ///
    /// Words are lowercased and keyed by their UTF-8 bytes; duplicate words have
    /// their frequencies summed. Frequencies are normalized so the most frequent
    /// word has weight 1.0 (only relative weights matter to the engine).
    public static func build(
        lexicon: [(word: String, frequency: Double)],
        bigrams: BigramModel = BigramModel()
    ) -> Data {
        // 1. Pointer trie over UTF-8 bytes.
        let root = BuildNode(label: 0)
        var maxFrequency = 0.0
        for entry in lexicon {
            let bytes = Array(entry.word.lowercased().utf8)
            guard !bytes.isEmpty, bytes.count <= 255 else { continue }
            var node = root
            for byte in bytes {
                node = node.child(for: byte)
            }
            node.isTerminal = true
            node.wordFrequency += entry.frequency
            maxFrequency = max(maxFrequency, node.wordFrequency)
        }
        let scale = maxFrequency > 0 ? 1.0 / maxFrequency : 1.0
        root.finalize(scale: scale)

        // 2. Breadth-first numbering: a node's children are consecutive and
        //    sorted by label so the reader can binary-search them.
        var ordered: [BuildNode] = [root]
        root.index = 0
        var cursor = 0
        while cursor < ordered.count {
            let node = ordered[cursor]
            cursor += 1
            let children = node.sortedChildren
            node.firstChild = ordered.count
            for child in children {
                child.index = ordered.count
                ordered.append(child)
            }
        }

        // 3. Bigram section.
        var pool = StringPool()
        var heads: [(stringOffset: Int, followerStart: Int, followerCount: Int)] = []
        var followers: [(stringOffset: Int, score: Float)] = []
        let entries = bigrams.entries
            .map { (bytes: Array($0.previous.utf8), followers: $0.followers) }
            .filter { !$0.bytes.isEmpty && $0.bytes.count <= 255 }
            .sorted { $0.bytes.lexicographicallyPrecedes($1.bytes) }
        for entry in entries {
            let start = followers.count
            for follower in entry.followers {
                guard let offset = pool.intern(follower.word.lowercased()) else { continue }
                followers.append((offset, Float(follower.score)))
            }
            let count = followers.count - start
            guard count > 0, let headOffset = pool.intern(bytes: entry.bytes) else { continue }
            heads.append((headOffset, start, count))
        }

        // 4. Layout.
        let nodesOffset = SDictFormat.headerSize
        let nodesLength = ordered.count * SDictFormat.nodeSize
        let headsOffset = SDictFormat.padded(nodesOffset + nodesLength)
        let headsLength = heads.count * SDictFormat.headSize
        let followersOffset = SDictFormat.padded(headsOffset + headsLength)
        let followersLength = followers.count * SDictFormat.followerSize
        let poolOffset = SDictFormat.padded(followersOffset + followersLength)
        let poolLength = pool.bytes.count
        let total = SDictFormat.padded(poolOffset + poolLength)

        var out = Data(count: total)
        out.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            let w = Writer(buffer: raw)

            // Header.
            for (i, byte) in SDictFormat.magic.enumerated() { raw[SDictFormat.HeaderField.magic + i] = byte }
            w.put(UInt32(SDictFormat.version), at: SDictFormat.HeaderField.version)
            w.put(UInt32(ordered.count), at: SDictFormat.HeaderField.nodeCount)
            w.put(UInt32(nodesOffset), at: SDictFormat.HeaderField.nodesOffset)
            w.put(UInt32(heads.count), at: SDictFormat.HeaderField.headCount)
            w.put(UInt32(headsOffset), at: SDictFormat.HeaderField.headsOffset)
            w.put(UInt32(followers.count), at: SDictFormat.HeaderField.followerCount)
            w.put(UInt32(followersOffset), at: SDictFormat.HeaderField.followersOffset)
            w.put(UInt32(poolOffset), at: SDictFormat.HeaderField.stringPoolOffset)
            w.put(UInt32(poolLength), at: SDictFormat.HeaderField.stringPoolLength)

            // Nodes.
            for (i, node) in ordered.enumerated() {
                let base = nodesOffset + i * SDictFormat.nodeSize
                raw[base + SDictFormat.NodeField.label] = node.label
                raw[base + SDictFormat.NodeField.flags] = node.isTerminal ? SDictFormat.terminalFlag : 0
                w.put(UInt16(node.children.count), at: base + SDictFormat.NodeField.childCount)
                w.put(UInt32(node.firstChild), at: base + SDictFormat.NodeField.firstChild)
                w.put(Float(node.isTerminal ? node.wordFrequency : 0), at: base + SDictFormat.NodeField.wordFrequency)
                w.put(Float(node.aggregateFrequency), at: base + SDictFormat.NodeField.aggregateFrequency)
            }

            // Heads.
            for (i, head) in heads.enumerated() {
                let base = headsOffset + i * SDictFormat.headSize
                w.put(UInt32(head.stringOffset), at: base + SDictFormat.HeadField.stringOffset)
                w.put(UInt32(head.followerStart), at: base + SDictFormat.HeadField.followerStart)
                w.put(UInt32(head.followerCount), at: base + SDictFormat.HeadField.followerCount)
            }

            // Followers.
            for (i, follower) in followers.enumerated() {
                let base = followersOffset + i * SDictFormat.followerSize
                w.put(UInt32(follower.stringOffset), at: base + SDictFormat.FollowerField.stringOffset)
                w.put(follower.score, at: base + SDictFormat.FollowerField.score)
            }

            // String pool.
            for (i, byte) in pool.bytes.enumerated() { raw[poolOffset + i] = byte }
        }
        return out
    }

    // MARK: - Build-time structures

    private final class BuildNode {
        let label: UInt8
        var children: [UInt8: BuildNode] = [:]
        var isTerminal = false
        var wordFrequency = 0.0
        var aggregateFrequency = 0.0
        var index = 0
        var firstChild = 0

        init(label: UInt8) { self.label = label }

        func child(for byte: UInt8) -> BuildNode {
            if let existing = children[byte] { return existing }
            let node = BuildNode(label: byte)
            children[byte] = node
            return node
        }

        var sortedChildren: [BuildNode] {
            children.values.sorted { $0.label < $1.label }
        }

        /// Normalize frequencies and fill in subtree aggregates (post-order).
        @discardableResult
        func finalize(scale: Double) -> Double {
            wordFrequency *= scale
            var total = isTerminal ? wordFrequency : 0
            for child in children.values {
                total += child.finalize(scale: scale)
            }
            aggregateFrequency = total
            return total
        }
    }

    private struct StringPool {
        private(set) var bytes: [UInt8] = []
        private var offsets: [[UInt8]: Int] = [:]

        /// Offset of the `[length][utf8]` record for `string`, interning it on
        /// first use. `nil` if the string is empty or longer than 255 bytes.
        mutating func intern(_ string: String) -> Int? {
            intern(bytes: Array(string.utf8))
        }

        mutating func intern(bytes utf8: [UInt8]) -> Int? {
            guard !utf8.isEmpty, utf8.count <= 255 else { return nil }
            if let existing = offsets[utf8] { return existing }
            let offset = bytes.count
            bytes.append(UInt8(utf8.count))
            bytes.append(contentsOf: utf8)
            offsets[utf8] = offset
            return offset
        }
    }

    private struct Writer {
        let buffer: UnsafeMutableRawBufferPointer

        func put(_ value: UInt16, at offset: Int) {
            buffer.storeBytes(of: value.littleEndian, toByteOffset: offset, as: UInt16.self)
        }
        func put(_ value: UInt32, at offset: Int) {
            buffer.storeBytes(of: value.littleEndian, toByteOffset: offset, as: UInt32.self)
        }
        func put(_ value: Float, at offset: Int) {
            buffer.storeBytes(of: value.bitPattern.littleEndian, toByteOffset: offset, as: UInt32.self)
        }
    }
}
