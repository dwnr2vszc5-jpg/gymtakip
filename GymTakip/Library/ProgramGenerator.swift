import Foundation

/// Hedef, seviye, ekipman ve haftalık gün sayısına göre antrenman programı üretir.
struct ProgramGenerator {
    enum Slot {
        case squat, hinge, horizontalPush, inclinePush, verticalPush, horizontalPull, verticalPull
        case lunge, legCurl, legExtension, calf, glute, lateralRaise, rearDelt, chestFly
        case biceps, triceps, core, conditioning

        var isCompound: Bool {
            switch self {
            case .squat, .hinge, .horizontalPush, .inclinePush, .verticalPush, .horizontalPull, .verticalPull, .lunge:
                true
            default:
                false
            }
        }

        /// Tercih sırasına göre aday hareketler. Ekipmana uymayanlar atlanır.
        var candidates: [String] {
            switch self {
            case .squat:
                ["Barbell_Squat", "Leg_Press", "Goblet_Squat", "Dumbbell_Squat", "Bodyweight_Squat"]
            case .hinge:
                ["Barbell_Deadlift", "Romanian_Deadlift", "Stiff-Legged_Dumbbell_Deadlift", "Hyperextensions_With_No_Hyperextension_Bench", "Butt_Lift_Bridge"]
            case .horizontalPush:
                ["Barbell_Bench_Press_-_Medium_Grip", "Dumbbell_Bench_Press", "Machine_Bench_Press", "Dumbbell_Floor_Press", "Pushups", "Push-Up_Wide"]
            case .inclinePush:
                ["Incline_Dumbbell_Press", "Barbell_Incline_Bench_Press_-_Medium_Grip", "Push-Ups_With_Feet_Elevated", "Decline_Push-Up"]
            case .verticalPush:
                ["Standing_Military_Press", "Dumbbell_Shoulder_Press", "Machine_Shoulder_Military_Press", "Arnold_Dumbbell_Press", "Decline_Push-Up", "Handstand_Push-Ups"]
            case .horizontalPull:
                ["Bent_Over_Barbell_Row", "Seated_Cable_Rows", "One-Arm_Dumbbell_Row", "Bent_Over_Two-Dumbbell_Row", "Inverted_Row"]
            case .verticalPull:
                ["Wide-Grip_Lat_Pulldown", "Pullups", "Close-Grip_Front_Lat_Pulldown", "Chin-Up"]
            case .lunge:
                ["Dumbbell_Lunges", "Split_Squat_with_Dumbbells", "Dumbbell_Step_Ups", "Bodyweight_Walking_Lunge"]
            case .legCurl:
                ["Lying_Leg_Curls", "Seated_Leg_Curl", "Stiff-Legged_Dumbbell_Deadlift", "Single_Leg_Glute_Bridge"]
            case .legExtension:
                ["Leg_Extensions", "Split_Squat_with_Dumbbells", "Bodyweight_Walking_Lunge"]
            case .calf:
                ["Standing_Calf_Raises", "Seated_Calf_Raise", "Standing_Dumbbell_Calf_Raise"]
            case .glute:
                ["Barbell_Hip_Thrust", "Barbell_Glute_Bridge", "Single_Leg_Glute_Bridge", "Butt_Lift_Bridge"]
            case .lateralRaise:
                ["Side_Lateral_Raise", "Cable_Seated_Lateral_Raise", "Seated_Side_Lateral_Raise"]
            case .rearDelt:
                ["Face_Pull", "Reverse_Flyes", "Reverse_Machine_Flyes"]
            case .chestFly:
                ["Dumbbell_Flyes", "Butterfly", "Flat_Bench_Cable_Flyes", "Incline_Dumbbell_Flyes", "Push-Up_Wide"]
            case .biceps:
                ["Barbell_Curl", "Dumbbell_Bicep_Curl", "Hammer_Curls", "Incline_Dumbbell_Curl", "Chin-Up"]
            case .triceps:
                ["Triceps_Pushdown", "Triceps_Pushdown_-_Rope_Attachment", "EZ-Bar_Skullcrusher", "Tricep_Dumbbell_Kickback", "Bench_Dips", "Push-Ups_-_Close_Triceps_Position"]
            case .core:
                ["Plank", "Hanging_Leg_Raise", "Cable_Crunch", "Dead_Bug", "Russian_Twist", "Crunches"]
            case .conditioning:
                ["Mountain_Climbers", "Rope_Jumping", "Battling_Ropes", "Rowing_Stationary"]
            }
        }
    }

    struct SlotRef {
        let slot: Slot
        let variant: Int

        init(_ slot: Slot, _ variant: Int = 0) {
            self.slot = slot
            self.variant = variant
        }
    }

    struct DayTemplate {
        let name: String
        let focus: String
        let slots: [SlotRef]
    }

    struct Prescription {
        let sets: Int
        let repsLow: Int
        let repsHigh: Int
        let rest: Int
    }

    let goal: Goal
    let level: Level
    let equipment: EquipmentProfile
    let daysPerWeek: Int
    var library: ExerciseLibrary = .shared

    // MARK: - Gün şablonları

    private static let fullBodyA = DayTemplate(name: "Tüm vücut A", focus: "Bacak, göğüs, sırt", slots: [
        .init(.squat), .init(.horizontalPush), .init(.verticalPull), .init(.lateralRaise), .init(.biceps), .init(.core),
    ])
    private static let fullBodyB = DayTemplate(name: "Tüm vücut B", focus: "Arka zincir, omuz, sırt", slots: [
        .init(.hinge), .init(.verticalPush), .init(.horizontalPull), .init(.lunge), .init(.triceps), .init(.core, 1),
    ])
    private static let fullBodyC = DayTemplate(name: "Tüm vücut C", focus: "Bacak, üst göğüs, kalça", slots: [
        .init(.squat, 1), .init(.inclinePush), .init(.verticalPull, 1), .init(.glute), .init(.rearDelt), .init(.calf),
    ])
    private static let upperA = DayTemplate(name: "Üst vücut A", focus: "Göğüs, sırt, omuz, kol", slots: [
        .init(.horizontalPush), .init(.horizontalPull), .init(.verticalPush), .init(.verticalPull), .init(.biceps), .init(.triceps),
    ])
    private static let lowerA = DayTemplate(name: "Alt vücut A", focus: "Ön bacak ağırlıklı", slots: [
        .init(.squat), .init(.hinge, 1), .init(.legExtension), .init(.legCurl), .init(.calf), .init(.core),
    ])
    private static let upperB = DayTemplate(name: "Üst vücut B", focus: "Üst göğüs, kanat, omuz", slots: [
        .init(.inclinePush), .init(.verticalPull, 1), .init(.verticalPush, 1), .init(.horizontalPull, 1), .init(.lateralRaise), .init(.rearDelt),
    ])
    private static let lowerB = DayTemplate(name: "Alt vücut B", focus: "Arka bacak ve kalça", slots: [
        .init(.hinge), .init(.squat, 1), .init(.lunge), .init(.glute), .init(.calf, 1), .init(.core, 1),
    ])
    private static func push(_ v: Int) -> DayTemplate {
        DayTemplate(name: v == 0 ? "İtiş (Push) A" : "İtiş (Push) B", focus: "Göğüs, omuz, arka kol", slots: [
            .init(.horizontalPush, v), .init(.inclinePush, v), .init(.verticalPush, v), .init(.chestFly, v), .init(.lateralRaise, v), .init(.triceps, v),
        ])
    }
    private static func pull(_ v: Int) -> DayTemplate {
        DayTemplate(name: v == 0 ? "Çekiş (Pull) A" : "Çekiş (Pull) B", focus: "Sırt, arka omuz, pazu", slots: [
            .init(.verticalPull, v), .init(.horizontalPull, v), .init(.horizontalPull, v + 1), .init(.rearDelt, v), .init(.biceps, v), .init(.biceps, v + 1),
        ])
    }
    private static func legs(_ v: Int) -> DayTemplate {
        DayTemplate(name: v == 0 ? "Bacak A" : "Bacak B", focus: "Ön/arka bacak, kalça, baldır", slots: [
            .init(.squat, v), .init(.hinge, v + 1), .init(.legExtension, v), .init(.legCurl, v), .init(.calf, v), .init(.core, v),
        ])
    }

    var templates: [DayTemplate] {
        switch daysPerWeek {
        case ...2: [Self.fullBodyA, Self.fullBodyB]
        case 3: [Self.fullBodyA, Self.fullBodyB, Self.fullBodyC]
        case 4: [Self.upperA, Self.lowerA, Self.upperB, Self.lowerB]
        case 5: [Self.push(0), Self.pull(0), Self.legs(0), Self.upperB, Self.lowerB]
        default: [Self.push(0), Self.pull(0), Self.legs(0), Self.push(1), Self.pull(1), Self.legs(1)]
        }
    }

    var splitName: String {
        switch daysPerWeek {
        case ...3: "Tüm vücut"
        case 4: "Üst / Alt vücut"
        case 5: "Push / Pull / Legs + Üst / Alt"
        default: "Push / Pull / Legs"
        }
    }

    // MARK: - Set / tekrar reçetesi

    func prescription(for slot: Slot) -> Prescription {
        let base: Prescription
        switch (goal, slot.isCompound) {
        case (.hypertrophy, true): base = .init(sets: 4, repsLow: 6, repsHigh: 10, rest: 120)
        case (.hypertrophy, false): base = .init(sets: 3, repsLow: 10, repsHigh: 15, rest: 75)
        case (.strength, true): base = .init(sets: 5, repsLow: 3, repsHigh: 5, rest: 180)
        case (.strength, false): base = .init(sets: 3, repsLow: 6, repsHigh: 10, rest: 90)
        case (.fatLoss, true): base = .init(sets: 3, repsLow: 10, repsHigh: 15, rest: 60)
        case (.fatLoss, false): base = .init(sets: 3, repsLow: 12, repsHigh: 20, rest: 45)
        case (.endurance, true): base = .init(sets: 3, repsLow: 12, repsHigh: 15, rest: 60)
        case (.endurance, false): base = .init(sets: 2, repsLow: 15, repsHigh: 20, rest: 45)
        }
        if slot == .core || slot == .conditioning {
            return .init(sets: 3, repsLow: slot == .core ? 10 : 20, repsHigh: slot == .core ? 15 : 30, rest: 45)
        }
        let setAdjust = level == .beginner ? -1 : 0
        return .init(sets: max(2, base.sets + setAdjust), repsLow: base.repsLow, repsHigh: base.repsHigh, rest: base.rest)
    }

    private var exercisesPerDay: Int {
        switch level {
        case .beginner: 5
        case .intermediate, .expert: 6
        }
    }

    // MARK: - Üretim

    func pick(_ ref: SlotRef, excluding used: Set<String>) -> Exercise? {
        let allowed = ref.slot.candidates
            .compactMap { library.exercise(id: $0) }
            .filter { equipment.allows($0.equipment) || isGobletWithDumbbell($0) }
        let fresh = allowed.filter { !used.contains($0.id) }
        guard !fresh.isEmpty else { return nil }
        return fresh[min(ref.variant, fresh.count - 1)]
    }

    /// Goblet squat dambılla da yapılabildiği için evde dambıl profilinde kabul edilir.
    private func isGobletWithDumbbell(_ exercise: Exercise) -> Bool {
        exercise.id == "Goblet_Squat" && equipment == .dumbbells
    }

    struct GeneratedDay {
        let name: String
        let focus: String
        let items: [(exercise: Exercise, prescription: Prescription)]
    }

    func generateDays() -> [GeneratedDay] {
        templates.map { template in
            var used = Set<String>()
            var items: [(exercise: Exercise, prescription: Prescription)] = []
            var slots = Array(template.slots.prefix(exercisesPerDay))
            if goal == .fatLoss || goal == .endurance {
                slots.append(.init(.conditioning))
            }
            for ref in slots {
                guard let exercise = pick(ref, excluding: used) else { continue }
                used.insert(exercise.id)
                items.append((exercise, prescription(for: ref.slot)))
            }
            return GeneratedDay(name: template.name, focus: template.focus, items: items)
        }
    }

    func makePlan() -> WorkoutPlan {
        let plan = WorkoutPlan(
            name: "\(goal.title) · \(splitName)",
            goal: goal, level: level, equipment: equipment, daysPerWeek: daysPerWeek
        )
        var days: [PlanDay] = []
        for (dayIndex, generated) in generateDays().enumerated() {
            let day = PlanDay(name: generated.name, focus: generated.focus, order: dayIndex)
            day.exercises = generated.items.enumerated().map { index, item in
                PlanExercise(
                    exerciseID: item.exercise.id, name: item.exercise.name, order: index,
                    sets: item.prescription.sets, repsLow: item.prescription.repsLow,
                    repsHigh: item.prescription.repsHigh, restSeconds: item.prescription.rest
                )
            }
            days.append(day)
        }
        plan.days = days
        return plan
    }
}
