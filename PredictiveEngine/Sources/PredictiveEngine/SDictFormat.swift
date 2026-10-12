import Foundation

/// Binary layout of a compiled `.sdict` dictionary.
///
/// The file is designed to be memory-mapped and read in place: fixed-size
/// records, 16-byte-aligned sections, no pointers to parse up front. Every
/// multi-byte integer and float is little-endian (the native order on all
/// Apple hardware, so reads are plain unaligned loads).
///
/// ```
/// header      64 bytes
/// nodes       nodeCount × 16   byte-level trie, root at index 0, children
///                              contiguous and sorted by label
/// heads       headCount × 16   bigram "previous word" entries, sorted by the
///                              UTF-8 bytes of the word for binary search
/// followers   followerCount × 8  per head, best-first
/// string pool                  [UInt8 length][UTF-8 bytes] records
/// ```
enum SDictFormat {
    /// "SDIC" as the first four bytes of the file.
    static let magic: [UInt8] = Array("SDIC".utf8)
    static let version: UInt32 = 1

    static let headerSize = 64
    static let nodeSize = 16
    static let headSize = 16
    static let followerSize = 8
    static let alignment = 16

    /// `Node.flags` bit: a word ends at this node.
    static let terminalFlag: UInt8 = 1

    // Header field byte offsets.
    enum HeaderField {
        static let magic = 0
        static let version = 4
        static let nodeCount = 8
        static let nodesOffset = 12
        static let headCount = 16
        static let headsOffset = 20
        static let followerCount = 24
        static let followersOffset = 28
        static let stringPoolOffset = 32
        static let stringPoolLength = 36
    }

    // Node field byte offsets (within a 16-byte record).
    enum NodeField {
        static let label = 0            // UInt8
        static let flags = 1            // UInt8
        static let childCount = 2       // UInt16
        static let firstChild = 4       // UInt32 node index
        static let wordFrequency = 8    // Float32, 0 when not terminal
        static let aggregateFrequency = 12  // Float32, subtree sum
    }

    // Head field byte offsets (within a 16-byte record).
    enum HeadField {
        static let stringOffset = 0     // UInt32 into the string pool
        static let followerStart = 4    // UInt32 follower index
        static let followerCount = 8    // UInt32
        // 12..<16 reserved
    }

    // Follower field byte offsets (within an 8-byte record).
    enum FollowerField {
        static let stringOffset = 0     // UInt32 into the string pool
        static let score = 4            // Float32
    }

    struct Header: Sendable {
        var nodeCount: Int
        var nodesOffset: Int
        var headCount: Int
        var headsOffset: Int
        var followerCount: Int
        var followersOffset: Int
        var stringPoolOffset: Int
        var stringPoolLength: Int
    }

    static func padded(_ length: Int) -> Int {
        (length + alignment - 1) / alignment * alignment
    }
}
