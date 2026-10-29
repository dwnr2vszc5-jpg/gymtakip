import Foundation
import SwiftData

/// Antrenman başlatma, egzersiz ekleme ve ilerleme önerileriyle ilgili yardımcılar.
enum Training {
    static func startSession(from day: PlanDay?, in context: ModelContext, history: [WorkoutSession]) -> WorkoutSession {
        let session = WorkoutSession(title: day?.name ?? "Serbest antrenman", planDayUID: day?.uid ?? "")
        context.insert(session)
        if let day {
            for planExercise in day.sortedExercises {
                addExercise(
                    id: planExercise.exerciseID, name: planExercise.name, to: session,
                    sets: planExercise.sets, repsLow: planExercise.repsLow,
                    repsHigh: planExercise.repsHigh, rest: planExercise.restSeconds,
                    history: history
                )
            }
        }
        return session
    }

    @discardableResult
    static func addExercise(id: String, name: String, to session: WorkoutSession,
                            sets: Int = 3, repsLow: Int = 8, repsHigh: Int = 12, rest: Int = 90,
                            history: [WorkoutSession]) -> LoggedExercise {
        let order = (session.exercises ?? []).map(\.order).max().map { $0 + 1 } ?? 0
        let logged = LoggedExercise(exerciseID: id, name: name, order: order, repsLow: repsLow, repsHigh: repsHigh, restSeconds: rest)
        let suggestion = suggestion(for: id, repsLow: repsLow, repsHigh: repsHigh, history: history, excluding: session)
        logged.sets = (0..<max(1, sets)).map { index in
            SetEntry(order: index, weight: suggestion?.weight ?? 0, reps: suggestion?.reps ?? repsLow)
        }
        logged.session = session
        session.exercises = (session.exercises ?? []) + [logged]
        return logged
    }

    static func addSet(to exercise: LoggedExercise) {
        let last = exercise.sortedSets.last
        let set = SetEntry(order: (last?.order ?? -1) + 1, weight: last?.weight ?? 0, reps: last?.reps ?? exercise.repsLow)
        set.exercise = exercise
        exercise.sets = (exercise.sets ?? []) + [set]
    }

    /// Aynı hareketin en son tamamlanmış kaydı.
    static func previous(for exerciseID: String, history: [WorkoutSession], excluding session: WorkoutSession? = nil) -> LoggedExercise? {
        history
            .filter { $0.isFinished && $0.persistentModelID != session?.persistentModelID }
            .sorted { $0.date > $1.date }
            .lazy
            .compactMap { $0.sortedExercises.first { $0.exerciseID == exerciseID && !$0.completedSets.isEmpty } }
            .first
    }

    struct Suggestion {
        let weight: Double
        let reps: Int
        let message: String
    }

    /// Basit "çift ilerleme" kuralı: tüm setlerde üst tekrar sınırına ulaşıldıysa ağırlığı artır,
    /// ulaşılamadıysa aynı ağırlıkla tekrar sayısını artırmaya çalış.
    static func suggestion(for exerciseID: String, repsLow: Int, repsHigh: Int, history: [WorkoutSession], excluding session: WorkoutSession? = nil) -> Suggestion? {
        guard let last = previous(for: exerciseID, history: history, excluding: session) else { return nil }
        let sets = last.completedSets
        guard let topWeight = sets.map(\.weight).max() else { return nil }
        let working = sets.filter { $0.weight == topWeight }
        let minReps = working.map(\.reps).min() ?? 0

        if topWeight == 0 {
            let target = min(minReps + 1, repsHigh + 5)
            return Suggestion(weight: 0, reps: target, message: "Geçen sefer \(minReps) tekrar. Bugün \(target) dene.")
        }
        if minReps >= repsHigh {
            let increment = topWeight >= 60 ? 5.0 : 2.5
            let newWeight = topWeight + increment
            return Suggestion(weight: newWeight, reps: repsLow,
                              message: "Tüm setlerde \(repsHigh) tekrarı geçtin. Ağırlığı \(newWeight.clean) kg yap.")
        }
        return Suggestion(weight: topWeight, reps: max(repsLow, min(minReps + 1, repsHigh)),
                          message: "\(topWeight.clean) kg ile devam et, \(repsHigh) tekrara ulaşınca ağırlık artır.")
    }

    /// Plandaki sıradaki gün: o plandan yapılan son antrenmandan sonraki gün.
    static func nextDay(in plan: WorkoutPlan, history: [WorkoutSession]) -> PlanDay? {
        let days = plan.sortedDays
        guard !days.isEmpty else { return nil }
        let uids = Set(days.map(\.uid))
        guard let last = history.filter({ $0.isFinished && uids.contains($0.planDayUID) }).max(by: { $0.date < $1.date }),
              let index = days.firstIndex(where: { $0.uid == last.planDayUID }) else {
            return days.first
        }
        return days[(index + 1) % days.count]
    }
}

/// Özet ekranı ve gelişim grafikleri için hesaplamalar.
enum Stats {
    static func sessions(_ history: [WorkoutSession], since date: Date) -> [WorkoutSession] {
        history.filter { $0.isFinished && $0.date >= date }
    }

    static var startOfWeek: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
    }

    /// Son 7 günde kas grubu başına tamamlanan çalışma seti sayısı (ana kaslar 1, yardımcı kaslar 0,5 set sayılır).
    static func weeklySets(_ history: [WorkoutSession], library: ExerciseLibrary = .shared) -> [MuscleGroup: Double] {
        let since = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        var result: [MuscleGroup: Double] = [:]
        for session in sessions(history, since: since) {
            for logged in session.sortedExercises {
                guard let exercise = library.exercise(id: logged.exerciseID) else { continue }
                let count = Double(logged.completedSets.count)
                for group in exercise.muscleGroups {
                    result[group, default: 0] += count
                }
                let secondary = Set(exercise.secondaryMuscles.compactMap(MuscleGroup.init(datasetMuscle:))).subtracting(exercise.muscleGroups)
                for group in secondary {
                    result[group, default: 0] += count * 0.5
                }
            }
        }
        return result
    }

    /// Art arda antrenman yapılan hafta sayısı.
    static func weekStreak(_ history: [WorkoutSession]) -> Int {
        let calendar = Calendar.current
        let weeks = Set(history.filter(\.isFinished).compactMap { calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start })
        var streak = 0
        var cursor = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        if !weeks.contains(cursor) {
            cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) ?? cursor
        }
        while weeks.contains(cursor) {
            streak += 1
            cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    struct StrengthPoint: Identifiable {
        let date: Date
        let oneRepMax: Double
        let bestWeight: Double
        var id: Date { date }
    }

    static func strengthHistory(for exerciseID: String, history: [WorkoutSession]) -> [StrengthPoint] {
        history
            .filter(\.isFinished)
            .compactMap { session -> StrengthPoint? in
                let logged = session.sortedExercises.filter { $0.exerciseID == exerciseID }
                let sets = logged.flatMap(\.completedSets)
                guard !sets.isEmpty else { return nil }
                let orm = sets.map { oneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
                let best = sets.map(\.weight).max() ?? 0
                return StrengthPoint(date: session.date, oneRepMax: orm, bestWeight: best)
            }
            .sorted { $0.date < $1.date }
    }

    /// Antrenman geçmişinde en az bir kez yapılmış hareketler, en sık yapılandan başlayarak.
    static func trainedExercises(_ history: [WorkoutSession]) -> [(id: String, name: String, count: Int)] {
        var counts: [String: (name: String, count: Int)] = [:]
        for session in history where session.isFinished {
            for logged in session.sortedExercises where !logged.completedSets.isEmpty {
                counts[logged.exerciseID, default: (logged.name, 0)].count += 1
            }
        }
        return counts.map { (id: $0.key, name: $0.value.name, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    struct WeeklyVolume: Identifiable {
        let weekStart: Date
        let volume: Double
        let sessions: Int
        var id: Date { weekStart }
    }

    static func weeklyVolume(_ history: [WorkoutSession], weeks: Int = 12) -> [WeeklyVolume] {
        let calendar = Calendar.current
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        return (0..<weeks).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeek),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return nil }
            let inWeek = history.filter { $0.isFinished && $0.date >= start && $0.date < end }
            return WeeklyVolume(weekStart: start, volume: inWeek.reduce(0) { $0 + $1.totalVolume }, sessions: inWeek.count)
        }
    }
}

extension Double {
    /// 80.0 -> "80", 82.5 -> "82,5"
    var clean: String {
        formatted(.number.precision(.fractionLength(0...1)))
    }
}

extension TimeInterval {
    var durationText: String {
        let minutes = Int(self) / 60
        if minutes >= 60 {
            return "\(minutes / 60) sa \(minutes % 60) dk"
        }
        return "\(minutes) dk"
    }
}
