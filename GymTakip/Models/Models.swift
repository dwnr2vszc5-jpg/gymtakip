import Foundation
import SwiftData

// iCloud (CloudKit) senkronu için kurallar: her alanın varsayılan değeri olmalı,
// ilişkiler opsiyonel olmalı ve @Attribute(.unique) kullanılmamalı.

@Model
final class WorkoutSession {
    var uid: String = UUID().uuidString
    var date: Date = Date.now
    var endDate: Date?
    var title: String = ""
    var notes: String = ""
    var planDayUID: String = ""
    @Relationship(deleteRule: .cascade, inverse: \LoggedExercise.session)
    var exercises: [LoggedExercise]? = []

    init(title: String, date: Date = .now, planDayUID: String = "") {
        self.title = title
        self.date = date
        self.planDayUID = planDayUID
    }

    var isFinished: Bool { endDate != nil }

    var sortedExercises: [LoggedExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    var totalVolume: Double {
        sortedExercises.reduce(0) { $0 + $1.volume }
    }

    var completedSetCount: Int {
        sortedExercises.reduce(0) { $0 + $1.completedSets.count }
    }

    var duration: TimeInterval {
        (endDate ?? .now).timeIntervalSince(date)
    }
}

@Model
final class LoggedExercise {
    var exerciseID: String = ""
    var name: String = ""
    var order: Int = 0
    var repsLow: Int = 8
    var repsHigh: Int = 12
    var restSeconds: Int = 90
    var session: WorkoutSession?
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.exercise)
    var sets: [SetEntry]? = []

    init(exerciseID: String, name: String, order: Int, repsLow: Int = 8, repsHigh: Int = 12, restSeconds: Int = 90) {
        self.exerciseID = exerciseID
        self.name = name
        self.order = order
        self.repsLow = repsLow
        self.repsHigh = repsHigh
        self.restSeconds = restSeconds
    }

    var sortedSets: [SetEntry] {
        (sets ?? []).sorted { $0.order < $1.order }
    }

    var completedSets: [SetEntry] {
        sortedSets.filter { $0.isCompleted && !$0.isWarmup }
    }

    var volume: Double {
        completedSets.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    /// Bu egzersizdeki en iyi tahmini 1 tekrar maksimumu (Epley formülü).
    var bestOneRepMax: Double {
        completedSets.map { oneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
    }
}

@Model
final class SetEntry {
    var order: Int = 0
    var weight: Double = 0
    var reps: Int = 0
    var isWarmup: Bool = false
    var isCompleted: Bool = false
    var completedAt: Date?
    var exercise: LoggedExercise?

    init(order: Int, weight: Double = 0, reps: Int = 0, isWarmup: Bool = false) {
        self.order = order
        self.weight = weight
        self.reps = reps
        self.isWarmup = isWarmup
    }
}

@Model
final class BodyMeasurement {
    var date: Date = Date.now
    var weight: Double?
    var bodyFat: Double?
    var chest: Double?
    var shoulders: Double?
    var waist: Double?
    var hips: Double?
    var arm: Double?
    var forearm: Double?
    var thigh: Double?
    var calf: Double?
    var neck: Double?
    var notes: String = ""

    init(date: Date = .now) {
        self.date = date
    }
}

@Model
final class WorkoutPlan {
    var uid: String = UUID().uuidString
    var name: String = ""
    var goalRaw: String = Goal.hypertrophy.rawValue
    var levelRaw: String = Level.beginner.rawValue
    var equipmentRaw: String = EquipmentProfile.gym.rawValue
    var daysPerWeek: Int = 3
    var createdAt: Date = Date.now
    var isActive: Bool = true
    @Relationship(deleteRule: .cascade, inverse: \PlanDay.plan)
    var days: [PlanDay]? = []

    init(name: String, goal: Goal, level: Level, equipment: EquipmentProfile, daysPerWeek: Int) {
        self.name = name
        self.goalRaw = goal.rawValue
        self.levelRaw = level.rawValue
        self.equipmentRaw = equipment.rawValue
        self.daysPerWeek = daysPerWeek
    }

    var goal: Goal { Goal(rawValue: goalRaw) ?? .hypertrophy }
    var level: Level { Level(rawValue: levelRaw) ?? .beginner }
    var equipment: EquipmentProfile { EquipmentProfile(rawValue: equipmentRaw) ?? .gym }

    var sortedDays: [PlanDay] {
        (days ?? []).sorted { $0.order < $1.order }
    }
}

@Model
final class PlanDay {
    var uid: String = UUID().uuidString
    var name: String = ""
    var focus: String = ""
    var order: Int = 0
    var plan: WorkoutPlan?
    @Relationship(deleteRule: .cascade, inverse: \PlanExercise.day)
    var exercises: [PlanExercise]? = []

    init(name: String, focus: String, order: Int) {
        self.name = name
        self.focus = focus
        self.order = order
    }

    var sortedExercises: [PlanExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }
}

@Model
final class PlanExercise {
    var exerciseID: String = ""
    var name: String = ""
    var order: Int = 0
    var sets: Int = 3
    var repsLow: Int = 8
    var repsHigh: Int = 12
    var restSeconds: Int = 90
    var day: PlanDay?

    init(exerciseID: String, name: String, order: Int, sets: Int, repsLow: Int, repsHigh: Int, restSeconds: Int) {
        self.exerciseID = exerciseID
        self.name = name
        self.order = order
        self.sets = sets
        self.repsLow = repsLow
        self.repsHigh = repsHigh
        self.restSeconds = restSeconds
    }

    var repsText: String {
        repsLow == repsHigh ? "\(repsLow)" : "\(repsLow)-\(repsHigh)"
    }
}

@Model
final class UserProfile {
    var name: String = ""
    var heightCm: Double = 0
    var birthYear: Int = 0
    var goalRaw: String = Goal.hypertrophy.rawValue
    var targetWeight: Double = 0
    var weeklyWorkoutTarget: Int = 3
    var createdAt: Date = Date.now

    init() {}

    var goal: Goal {
        get { Goal(rawValue: goalRaw) ?? .hypertrophy }
        set { goalRaw = newValue.rawValue }
    }
}

/// Epley formülü ile tahmini 1RM.
func oneRepMax(weight: Double, reps: Int) -> Double {
    guard weight > 0, reps > 0 else { return 0 }
    if reps == 1 { return weight }
    return weight * (1 + Double(reps) / 30)
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        WorkoutSession.self, LoggedExercise.self, SetEntry.self,
        BodyMeasurement.self, WorkoutPlan.self, PlanDay.self, PlanExercise.self,
        UserProfile.self,
    ]
}
