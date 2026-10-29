import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// iCloud kullanılamadığında verileri Mac ile iPhone arasında dosya (AirDrop, Dosyalar) ile taşımak için yedek.
struct BackupData: Codable {
    struct SetDTO: Codable {
        var weight: Double
        var reps: Int
        var isWarmup: Bool
        var isCompleted: Bool
    }

    struct ExerciseDTO: Codable {
        var exerciseID: String
        var name: String
        var order: Int
        var repsLow: Int
        var repsHigh: Int
        var restSeconds: Int
        var sets: [SetDTO]
    }

    struct SessionDTO: Codable {
        var uid: String
        var date: Date
        var endDate: Date?
        var title: String
        var notes: String
        var planDayUID: String
        var exercises: [ExerciseDTO]
    }

    struct MeasurementDTO: Codable {
        var date: Date
        var values: [String: Double]
        var notes: String
    }

    var version = 1
    var exportedAt = Date.now
    var sessions: [SessionDTO]
    var measurements: [MeasurementDTO]

    init(sessions: [WorkoutSession], measurements: [BodyMeasurement]) {
        self.sessions = sessions.filter(\.isFinished).map { session in
            SessionDTO(
                uid: session.uid, date: session.date, endDate: session.endDate, title: session.title,
                notes: session.notes, planDayUID: session.planDayUID,
                exercises: session.sortedExercises.map { logged in
                    ExerciseDTO(
                        exerciseID: logged.exerciseID, name: logged.name, order: logged.order,
                        repsLow: logged.repsLow, repsHigh: logged.repsHigh, restSeconds: logged.restSeconds,
                        sets: logged.sortedSets.map { SetDTO(weight: $0.weight, reps: $0.reps, isWarmup: $0.isWarmup, isCompleted: $0.isCompleted) }
                    )
                }
            )
        }
        self.measurements = measurements.map { m in
            var values: [String: Double] = [:]
            for metric in BodyMetric.allCases {
                if let value = m[keyPath: metric.keyPath] { values[metric.rawValue] = value }
            }
            return MeasurementDTO(date: m.date, values: values, notes: m.notes)
        }
    }

    /// Yedeği içe aktarır. Zaten var olan antrenmanlar (aynı kimlik) ve ölçümler (aynı tarih) atlanır.
    /// Dönen değer: (eklenen antrenman, eklenen ölçüm)
    func restore(into context: ModelContext, existingSessions: [WorkoutSession], existingMeasurements: [BodyMeasurement]) -> (Int, Int) {
        let knownUIDs = Set(existingSessions.map(\.uid))
        let knownDates = Set(existingMeasurements.map(\.date))
        var addedSessions = 0
        var addedMeasurements = 0

        for dto in sessions where !knownUIDs.contains(dto.uid) {
            let session = WorkoutSession(title: dto.title, date: dto.date, planDayUID: dto.planDayUID)
            session.uid = dto.uid
            session.endDate = dto.endDate
            session.notes = dto.notes
            context.insert(session)
            session.exercises = dto.exercises.map { e in
                let logged = LoggedExercise(exerciseID: e.exerciseID, name: e.name, order: e.order,
                                            repsLow: e.repsLow, repsHigh: e.repsHigh, restSeconds: e.restSeconds)
                logged.sets = e.sets.enumerated().map { index, s in
                    let set = SetEntry(order: index, weight: s.weight, reps: s.reps, isWarmup: s.isWarmup)
                    set.isCompleted = s.isCompleted
                    return set
                }
                return logged
            }
            addedSessions += 1
        }

        for dto in measurements where !knownDates.contains(dto.date) {
            let m = BodyMeasurement(date: dto.date)
            m.notes = dto.notes
            for metric in BodyMetric.allCases {
                if let value = dto.values[metric.rawValue] { m[keyPath: metric.keyPath] = value }
            }
            context.insert(m)
            addedMeasurements += 1
        }
        return (addedSessions, addedMeasurements)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
