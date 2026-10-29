import SwiftUI
import SwiftData

struct ProgramView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \WorkoutPlan.createdAt, order: .reverse) private var plans: [WorkoutPlan]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @State private var showBuilder = false

    private var activePlan: WorkoutPlan? { plans.first(where: \.isActive) }

    var body: some View {
        List {
            if let plan = activePlan {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(plan.goal.title, systemImage: plan.goal.icon)
                            .font(.headline)
                        Text("\(plan.daysPerWeek) gün/hafta · \(plan.level.title) · \(plan.equipment.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(plan.goal.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                let next = Training.nextDay(in: plan, history: sessions)
                ForEach(plan.sortedDays) { day in
                    Section {
                        NavigationLink {
                            PlanDayEditor(day: day)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(day.name).font(.headline)
                                    if day.uid == next?.uid { Chip(text: "Sıradaki", tint: .green) }
                                }
                                Text(day.focus).font(.caption).foregroundStyle(.secondary)
                                ForEach(day.sortedExercises) { item in
                                    HStack {
                                        Text(item.name).font(.callout)
                                        Spacer()
                                        Text("\(item.sets) × \(item.repsText)")
                                            .font(.callout.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        Button {
                            _ = Training.startSession(from: day, in: context, history: sessions)
                            appState.selectedTab = .workout
                        } label: {
                            Label("Bu günü başlat", systemImage: "play.fill")
                        }
                        .disabled(sessions.contains { !$0.isFinished })
                    }
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(Color.accentColor)
                        Text("Sana özel program").font(.title2.bold())
                        Text("Hedefini (kas kazanımı, güç, yağ yakımı, genel fitness), seviyeni, ekipmanını ve haftada kaç gün çalışacağını seç. Uygulama buna göre bölünmüş bir program, set ve tekrar sayıları hazırlar.")
                            .foregroundStyle(.secondary)
                        Button("Program oluştur") { showBuilder = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 8)
                }
            }

            let oldPlans = plans.filter { !$0.isActive }
            if !oldPlans.isEmpty {
                Section("Eski programlar") {
                    ForEach(oldPlans) { plan in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(plan.name)
                                Text(plan.createdAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Etkinleştir") { activate(plan) }
                                .buttonStyle(.bordered)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(oldPlans[index]) }
                    }
                }
            }
        }
        .navigationTitle("Program")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showBuilder = true
                } label: {
                    Label("Yeni program", systemImage: "wand.and.stars")
                }
            }
        }
        .sheet(isPresented: $showBuilder) {
            NavigationStack {
                PlanBuilderView { plan in
                    for old in plans { old.isActive = false }
                    context.insert(plan)
                }
            }
            #if os(macOS)
            .frame(minWidth: 560, minHeight: 680)
            #endif
        }
    }

    private func activate(_ plan: WorkoutPlan) {
        for other in plans { other.isActive = false }
        plan.isActive = true
    }
}

struct PlanBuilderView: View {
    let onSave: (WorkoutPlan) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    @State private var goal: Goal = .hypertrophy
    @State private var level: Level = .beginner
    @State private var equipment: EquipmentProfile = .gym
    @State private var days = 3
    @State private var didLoadProfile = false

    private var generator: ProgramGenerator {
        ProgramGenerator(goal: goal, level: level, equipment: equipment, daysPerWeek: days)
    }

    var body: some View {
        Form {
            Section("Hedefin") {
                Picker("Hedef", selection: $goal) {
                    ForEach(Goal.allCases) { goal in
                        Label(goal.title, systemImage: goal.icon).tag(goal)
                    }
                }
                Text(goal.summary).font(.caption).foregroundStyle(.secondary)
            }
            Section("Seviye ve ekipman") {
                Picker("Seviye", selection: $level) {
                    ForEach(Level.allCases) { Text($0.title).tag($0) }
                }
                Picker("Ekipman", selection: $equipment) {
                    ForEach(EquipmentProfile.allCases) { Text($0.title).tag($0) }
                }
                Stepper("Haftada \(days) gün", value: $days, in: 2...6)
                Text("Bölünme: \(generator.splitName)").font(.caption).foregroundStyle(.secondary)
            }
            Section("Önizleme") {
                ForEach(Array(generator.generateDays().enumerated()), id: \.offset) { _, day in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(day.name).font(.headline)
                        ForEach(Array(day.items.enumerated()), id: \.offset) { _, item in
                            HStack {
                                Text(item.exercise.name).font(.callout)
                                Spacer()
                                Text("\(item.prescription.sets) × \(item.prescription.repsLow)-\(item.prescription.repsHigh)")
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Program oluştur")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Vazgeç") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Kaydet") {
                    onSave(generator.makePlan())
                    dismiss()
                }
            }
        }
        .onAppear {
            guard !didLoadProfile else { return }
            didLoadProfile = true
            if let profile = profiles.first {
                goal = profile.goal
                days = min(6, max(2, profile.weeklyWorkoutTarget))
            }
        }
    }
}

struct PlanDayEditor: View {
    @Bindable var day: PlanDay
    @State private var showPicker = false

    var body: some View {
        Form {
            Section {
                TextField("Gün adı", text: $day.name)
                TextField("Odak", text: $day.focus)
            }
            Section("Hareketler") {
                ForEach(day.sortedExercises) { item in
                    PlanExerciseRow(item: item)
                }
                .onDelete { offsets in
                    let items = day.sortedExercises
                    for index in offsets {
                        let item = items[index]
                        day.exercises?.removeAll { $0.persistentModelID == item.persistentModelID }
                        item.modelContext?.delete(item)
                    }
                }
                .onMove { source, destination in
                    var items = day.sortedExercises
                    items.move(fromOffsets: source, toOffset: destination)
                    for (index, item) in items.enumerated() { item.order = index }
                }
                Button {
                    showPicker = true
                } label: {
                    Label("Hareket ekle", systemImage: "plus")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(day.name)
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                ExercisePickerView { exercise in
                    let order = (day.exercises ?? []).map(\.order).max().map { $0 + 1 } ?? 0
                    let item = PlanExercise(exerciseID: exercise.id, name: exercise.name, order: order,
                                            sets: 3, repsLow: 8, repsHigh: 12, restSeconds: 90)
                    item.day = day
                    day.exercises = (day.exercises ?? []) + [item]
                }
            }
            #if os(macOS)
            .frame(minWidth: 560, minHeight: 640)
            #endif
        }
    }
}

struct PlanExerciseRow: View {
    @Bindable var item: PlanExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            NavigationLink {
                if let exercise = ExerciseLibrary.shared.exercise(id: item.exerciseID) {
                    ExerciseDetailView(exercise: exercise)
                }
            } label: {
                Text(item.name).font(.headline)
            }
            Stepper("Set: \(item.sets)", value: $item.sets, in: 1...10)
            Stepper("Tekrar alt sınırı: \(item.repsLow)", value: $item.repsLow, in: 1...50)
            Stepper("Tekrar üst sınırı: \(item.repsHigh)", value: $item.repsHigh, in: item.repsLow...60)
            Stepper("Dinlenme: \(item.restSeconds) sn", value: $item.restSeconds, in: 15...600, step: 15)
        }
        .padding(.vertical, 4)
    }
}
