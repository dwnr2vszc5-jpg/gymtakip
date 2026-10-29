import SwiftUI
import SwiftData
import Charts

struct ExerciseFilter {
    var search = ""
    var muscle: String?
    var equipment: String?
    var category: String?

    func apply(to exercises: [Exercise]) -> [Exercise] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return exercises.filter { exercise in
            if let muscle, !exercise.primaryMuscles.contains(muscle) { return false }
            if let equipment, exercise.equipment != equipment { return false }
            if let category, exercise.category != category { return false }
            if !query.isEmpty {
                let haystack = exercise.name + " " + exercise.primaryMuscles.map(Labels.muscle).joined(separator: " ")
                if !haystack.localizedCaseInsensitiveContains(query) { return false }
            }
            return true
        }
    }

    var isActive: Bool { muscle != nil || equipment != nil || category != nil }
}

struct ExerciseFilterMenu: View {
    @Binding var filter: ExerciseFilter
    private let library = ExerciseLibrary.shared

    var body: some View {
        Menu {
            Picker("Kas", selection: $filter.muscle) {
                Text("Tüm kaslar").tag(String?.none)
                ForEach(library.allMuscles, id: \.self) { Text(Labels.muscle($0)).tag(String?.some($0)) }
            }
            Picker("Ekipman", selection: $filter.equipment) {
                Text("Tüm ekipmanlar").tag(String?.none)
                ForEach(library.allEquipment, id: \.self) { Text(Labels.equipment($0)).tag(String?.some($0)) }
            }
            Picker("Tür", selection: $filter.category) {
                Text("Tüm türler").tag(String?.none)
                ForEach(library.allCategories, id: \.self) { Text(Labels.category($0)).tag(String?.some($0)) }
            }
            if filter.isActive {
                Button("Filtreleri temizle") {
                    filter.muscle = nil
                    filter.equipment = nil
                    filter.category = nil
                }
            }
        } label: {
            Label("Filtre", systemImage: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }
}

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            ExerciseThumbnail(exercise: exercise)
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name).font(.body.weight(.medium))
                Text("\(exercise.primaryMuscleText) · \(Labels.equipment(exercise.equipment))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct ExerciseLibraryView: View {
    @State private var filter = ExerciseFilter()
    private let library = ExerciseLibrary.shared

    var body: some View {
        let results = filter.apply(to: library.all)
        List {
            if !filter.isActive && filter.search.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(library.allMuscles, id: \.self) { muscle in
                                Button {
                                    filter.muscle = muscle
                                } label: {
                                    Chip(text: Labels.muscle(muscle))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            Section("\(results.count) hareket") {
                ForEach(results) { exercise in
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        ExerciseRow(exercise: exercise)
                    }
                }
            }
        }
        .searchable(text: $filter.search, prompt: "Hareket veya kas ara")
        .navigationTitle("Hareketler")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ExerciseFilterMenu(filter: $filter)
            }
        }
    }
}

struct ExercisePickerView: View {
    let onPick: (Exercise) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var filter = ExerciseFilter()

    var body: some View {
        let results = filter.apply(to: ExerciseLibrary.shared.all)
        List(results) { exercise in
            Button {
                onPick(exercise)
                dismiss()
            } label: {
                ExerciseRow(exercise: exercise)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .searchable(text: $filter.search, prompt: "Hareket veya kas ara")
        .navigationTitle("Hareket seç")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Vazgeç") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                ExerciseFilterMenu(filter: $filter)
            }
        }
    }
}

struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @State private var added = false

    private var activeSession: WorkoutSession? { sessions.first { !$0.isFinished } }

    var body: some View {
        let history = Stats.strengthHistory(for: exercise.id, history: sessions)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ExerciseAnimationView(exercise: exercise)

                FlowLayout {
                    Chip(text: Labels.level(exercise.level), tint: .purple)
                    Chip(text: Labels.category(exercise.category), tint: .blue)
                    Chip(text: Labels.equipment(exercise.equipment), tint: .teal)
                    if let mechanic = Labels.mechanic(exercise.mechanic) { Chip(text: mechanic, tint: .indigo) }
                    if let force = Labels.force(exercise.force) { Chip(text: force, tint: .gray) }
                }

                Card("Çalışan kaslar", systemImage: "figure.arms.open") {
                    LabeledContent("Ana", value: exercise.primaryMuscles.map(Labels.muscle).joined(separator: ", "))
                    if !exercise.secondaryMuscles.isEmpty {
                        LabeledContent("Yardımcı", value: exercise.secondaryMuscles.map(Labels.muscle).joined(separator: ", "))
                    }
                }

                Card("Nasıl yapılır?", systemImage: "list.number") {
                    ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .frame(width: 22, height: 22)
                                .background(Color.accentColor.opacity(0.15), in: Circle())
                            Text(step)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Link(destination: youtubeURL) {
                        Label("YouTube'da video izle", systemImage: "play.rectangle.fill")
                    }
                    .padding(.top, 4)
                }

                if !history.isEmpty {
                    Card("Gelişimin", systemImage: "chart.line.uptrend.xyaxis") {
                        StrengthChart(points: history)
                        if let best = history.max(by: { $0.oneRepMax < $1.oneRepMax }) {
                            Text("En iyi tahmini 1RM: \(best.oneRepMax.clean) kg (\(best.date.formatted(date: .abbreviated, time: .omitted)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let activeSession {
                    Button {
                        _ = Training.addExercise(id: exercise.id, name: exercise.name, to: activeSession, history: sessions)
                        added = true
                    } label: {
                        Label(added ? "Antrenmana eklendi" : "Devam eden antrenmana ekle", systemImage: added ? "checkmark" : "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(added)
                }
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(exercise.name)
        .inlineNavigationTitle()
    }

    private var youtubeURL: URL {
        let query = (exercise.name + " exercise form").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.youtube.com/results?search_query=\(query)")!
    }
}

struct StrengthChart: View {
    let points: [Stats.StrengthPoint]

    var body: some View {
        Chart(points) { point in
            LineMark(x: .value("Tarih", point.date), y: .value("Tahmini 1RM", point.oneRepMax))
                .interpolationMethod(.catmullRom)
            PointMark(x: .value("Tarih", point.date), y: .value("Tahmini 1RM", point.oneRepMax))
        }
        .chartYAxisLabel("kg")
        .frame(height: 180)
    }
}
