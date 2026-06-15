import Foundation

protocol WordDictionary {
    func contains(_ word: String) -> Bool
    // Returns true if any word in the dictionary starts with the given prefix.
    // Used for live (typing-in-progress) layout detection.
    func hasWordWithPrefix(_ prefix: String) -> Bool
}

final class SetDictionary: WordDictionary {
    private let words: Set<String>
    private let sortedWords: [String]

    init(words: Set<String>) {
        self.words = words
        self.sortedWords = words.sorted()
    }

    convenience init(contentsOf url: URL) throws {
        let data = try String(contentsOf: url, encoding: .utf8)
        var set = Set<String>()
        set.reserveCapacity(1_000_000)
        for line in data.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()
            if !trimmed.isEmpty { set.insert(trimmed) }
        }
        self.init(words: set)
    }

    func contains(_ word: String) -> Bool {
        return words.contains(word.lowercased())
    }

    func hasWordWithPrefix(_ prefix: String) -> Bool {
        let p = prefix.lowercased()
        guard !p.isEmpty, !sortedWords.isEmpty else { return false }
        var lo = 0
        var hi = sortedWords.count
        while lo < hi {
            let mid = (lo &+ hi) / 2
            if sortedWords[mid] < p { lo = mid + 1 } else { hi = mid }
        }
        return lo < sortedWords.count && sortedWords[lo].hasPrefix(p)
    }
}

final class BloomDictionary: WordDictionary {
    private let bits: [UInt64]
    private let bitCount: Int
    private let hashCount: Int

    init(bits: [UInt64], bitCount: Int, hashCount: Int) {
        self.bits = bits
        self.bitCount = bitCount
        self.hashCount = hashCount
    }

    static func build(words: [String], falsePositiveRate p: Double = 0.001) -> BloomDictionary {
        let n = max(words.count, 1)
        let m = Int(ceil(-Double(n) * log(p) / pow(log(2.0), 2)))
        let k = max(1, Int(round(Double(m) / Double(n) * log(2.0))))
        let wordCount = (m + 63) / 64
        var bits = [UInt64](repeating: 0, count: wordCount)
        for w in words {
            let lower = w.lowercased()
            for i in 0..<k {
                let idx = hash(lower, seed: UInt64(i)) % UInt64(m)
                bits[Int(idx) / 64] |= (1 << (UInt64(idx) % 64))
            }
        }
        return BloomDictionary(bits: bits, bitCount: m, hashCount: k)
    }

    func contains(_ word: String) -> Bool {
        let lower = word.lowercased()
        for i in 0..<hashCount {
            let idx = BloomDictionary.hash(lower, seed: UInt64(i)) % UInt64(bitCount)
            if bits[Int(idx) / 64] & (1 << (UInt64(idx) % 64)) == 0 { return false }
        }
        return true
    }

    // Bloom filters can't answer prefix queries without storing prefixes
    // separately. Live correction is disabled when only a Bloom dict is loaded.
    func hasWordWithPrefix(_ prefix: String) -> Bool {
        return false
    }

    private static func hash(_ s: String, seed: UInt64) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325 &+ seed &* 0x100000001b3
        for byte in s.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100000001b3
        }
        return h
    }

    // Binary format: [magic 4][version 1][hashCount u32][bitCount u64][bits...]
    private static let magic: [UInt8] = [0x4B, 0x42, 0x53, 0x44] // "KBSD"

    func write(to url: URL) throws {
        var data = Data()
        data.append(contentsOf: Self.magic)
        data.append(1)
        var h = UInt32(hashCount).littleEndian
        withUnsafeBytes(of: &h) { data.append(contentsOf: $0) }
        var bc = UInt64(bitCount).littleEndian
        withUnsafeBytes(of: &bc) { data.append(contentsOf: $0) }
        bits.withUnsafeBufferPointer { buf in
            let raw = UnsafeRawBufferPointer(start: buf.baseAddress, count: buf.count * MemoryLayout<UInt64>.stride)
            data.append(contentsOf: raw)
        }
        try data.write(to: url)
    }

    convenience init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        guard data.count >= 4 + 1 + 4 + 8 else {
            throw NSError(domain: "BloomDictionary", code: 1, userInfo: [NSLocalizedDescriptionKey: "file too small"])
        }
        for (i, b) in Self.magic.enumerated() where data[i] != b {
            throw NSError(domain: "BloomDictionary", code: 2, userInfo: [NSLocalizedDescriptionKey: "bad magic"])
        }
        let hashCount = data.subdata(in: 5..<9).withUnsafeBytes { Int(UInt32(littleEndian: $0.load(as: UInt32.self))) }
        let bitCount = data.subdata(in: 9..<17).withUnsafeBytes { Int(UInt64(littleEndian: $0.load(as: UInt64.self))) }
        let bitsData = data.subdata(in: 17..<data.count)
        let wordCount = bitsData.count / 8
        var bits = [UInt64](repeating: 0, count: wordCount)
        bitsData.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: UInt64.self)
            for i in 0..<wordCount { bits[i] = UInt64(littleEndian: src[i]) }
        }
        self.init(bits: bits, bitCount: bitCount, hashCount: hashCount)
    }
}
