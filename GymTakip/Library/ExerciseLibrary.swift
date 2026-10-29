import Foundation

/// Free Exercise DB (https://github.com/yuhonas/free-exercise-db) kaydı. Veri seti kamu malıdır (Unlicense).
struct Exercise: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let force: String?
    let level: String
    let mechanic: String?
    let equipment: String?
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let instructions: [String]
    let category: String
    let images: [String]

    static let imageBase = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"

    var imageURLs: [URL] {
        images.compactMap { path in
            let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
            return URL(string: Self.imageBase + encoded)
        }
    }

    var thumbnailURL: URL? { imageURLs.first }

    var muscleGroups: Set<MuscleGroup> {
        Set(primaryMuscles.compactMap(MuscleGroup.init(datasetMuscle:)))
    }

    var isCompound: Bool { mechanic == "compound" }

    var primaryMuscleText: String {
        primaryMuscles.map(Labels.muscle).joined(separator: ", ")
    }
}

final class ExerciseLibrary: Sendable {
    static let shared = ExerciseLibrary()

    let all: [Exercise]
    private let byID: [String: Exercise]

    init() {
        var loaded: [Exercise] = []
        if let url = Bundle.main.url(forResource: "exercises", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Exercise].self, from: data) {
            loaded = decoded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        all = loaded
        byID = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func exercise(id: String) -> Exercise? {
        byID[id]
    }

    var allMuscles: [String] {
        Array(Set(all.flatMap(\.primaryMuscles))).sorted { Labels.muscle($0) < Labels.muscle($1) }
    }

    var allEquipment: [String] {
        Array(Set(all.compactMap(\.equipment))).sorted { Labels.equipment($0) < Labels.equipment($1) }
    }

    var allCategories: [String] {
        Array(Set(all.map(\.category))).sorted()
    }
}
