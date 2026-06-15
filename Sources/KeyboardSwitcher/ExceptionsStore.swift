import Foundation

final class ExceptionsStore {
    private let url: URL
    private var set: Set<String>
    private let queue = DispatchQueue(label: "kbswitcher.exceptions")

    init(url: URL) {
        self.url = url
        if let data = try? Data(contentsOf: url),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            self.set = Set(arr)
        } else {
            self.set = []
        }
    }

    static func defaultURL() -> URL {
        let support = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = (support ?? FileManager.default.temporaryDirectory).appendingPathComponent("KeyFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("exceptions.json")
    }

    func contains(_ word: String) -> Bool {
        queue.sync { set.contains(word.lowercased()) }
    }

    func add(_ word: String) {
        queue.sync {
            set.insert(word.lowercased())
            persist()
        }
    }

    func remove(_ word: String) {
        queue.sync {
            set.remove(word.lowercased())
            persist()
        }
    }

    func all() -> [String] {
        queue.sync { Array(set).sorted() }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(Array(set).sorted()) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
