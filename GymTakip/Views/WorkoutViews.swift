import SwiftUI
import SwiftData

struct WorkoutTabView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(filter: #Predicate<WorkoutPlan> { $0.isActive }, sort: \WorkoutPlan.createdAt, order: .reverse) private var activePlans: [WorkoutPlan]

    private var activeSession: WorkoutSession? { sessions.first { !$0.isFinished } }

    var body: some View {
        if let activeSession {
            ActiveWorkoutView(session: activeSession, history: sessions)
        } else {
            startAndHistory
        }
    }

    private var startAndHistory: some View {
        List {
            Section("Yeni antrenman") {
                if let plan = activePlans.first {
                    let next = Training.nextDay(in: plan, history: sessions)
                    ForEach(plan.sortedDays) { day in
                        Button {
                            _ = Training.startSession(from: day, in: context, history: sessions)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(day.name).font(.headline)
                                    Text("\(day.sortedExercises.count) hareket · \(day.focus)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if day.uid == next?.uid {
                                    Chip(text: "Sıradaki", tint: .green)
                                }
                                Image(systemName: "play.circle.fill").font(.title2)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button {
                    _ = Training.startSession(from: nil, in: context, history: sessions)
                } label: {
                    Label("Boş antrenman başlat", systemImage: "plus.circle")
                }
            }

            Section("Geçmiş") {
                let finished = sessions.filter(\.isFinished)
                if finished.isEmpty {
                    Text("Tamamlanan antrenmanlar burada listelenecek.")
                        .foregroundStyle(.secondary)
                }
                ForEach(finished) { session in
                    NavigationLink {
                        SessionDetailView(session: session)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title).font(.headline)
                            Text("\(session.date.formatted(date: .abbreviated, time: .shortened)) · \(session.duration.durationText) · \(session.completedSetCount) set · \(session.totalVolume.clean) kg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contextMenu {
                        Button("Sil", role: .destructive) { context.delete(session) }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(finished[index]) }
                }
            }
        }
        .navigationTitle("Antrenman")
    }
}

// MARK: - Aktif antrenman

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var context
    @Bindable var session: WorkoutSession
    let history: [WorkoutSession]

    @State private var showPicker = false
    @State private var restEnd: Date?
    @State private var restTotal: Int = 90
    @State private var confirmCancel = false
    @State private var detailExercise: Exercise?

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Antrenman adı", text: $session.title)
                        .font(.headline)
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(session.duration.durationText)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ForEach(session.sortedExercises) { logged in
                LoggedExerciseSection(
                    logged: logged,
                    suggestion: Training.suggestion(for: logged.exerciseID, repsLow: logged.repsLow, repsHigh: logged.repsHigh, history: history, excluding: session),
                    onSetCompleted: { startRest(seconds: logged.restSeconds) },
                    onShowDetail: { detailExercise = ExerciseLibrary.shared.exercise(id: logged.exerciseID) },
                    onDelete: { deleteExercise(logged) }
                )
            }

            Section {
                Button {
                    showPicker = true
                } label: {
                    Label("Hareket ekle", systemImage: "plus")
                }
                TextField("Notlar", text: $session.notes, axis: .vertical)
            }

            Section {
                Button {
                    finish()
                } label: {
                    Label("Antrenmanı bitir", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button("Antrenmanı iptal et", role: .destructive) { confirmCancel = true }
            }
        }
        .navigationTitle("Antrenman")
        .safeAreaInset(edge: .bottom) {
            if let restEnd {
                RestTimerBar(end: restEnd, total: restTotal) {
                    self.restEnd = nil
                } onAdd: {
                    self.restEnd = restEnd.addingTimeInterval(15)
                    restTotal += 15
                }
                .padding()
            }
        }
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                ExercisePickerView { exercise in
                    _ = Training.addExercise(id: exercise.id, name: exercise.name, to: session, history: history)
                }
            }
            #if os(macOS)
            .frame(minWidth: 560, minHeight: 640)
            #endif
        }
        .sheet(item: $detailExercise) { exercise in
            NavigationStack {
                ExerciseDetailView(exercise: exercise)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Kapat") { detailExercise = nil }
                        }
                    }
            }
            #if os(macOS)
            .frame(minWidth: 560, minHeight: 640)
            #endif
        }
        .confirmationDialog("Antrenman silinsin mi?", isPresented: $confirmCancel) {
            Button("Antrenmanı sil", role: .destructive) { context.delete(session) }
        }
    }

    private func startRest(seconds: Int) {
        restTotal = seconds
        restEnd = .now.addingTimeInterval(TimeInterval(seconds))
        Haptics.tap()
    }

    private func deleteExercise(_ logged: LoggedExercise) {
        session.exercises?.removeAll { $0.persistentModelID == logged.persistentModelID }
        context.delete(logged)
    }

    private func finish() {
        // Boş kalan (tamamlanmamış) setleri temizle.
        for logged in session.sortedExercises {
            for set in logged.sortedSets where !set.isCompleted {
                logged.sets?.removeAll { $0.persistentModelID == set.persistentModelID }
                context.delete(set)
            }
            if (logged.sets ?? []).isEmpty {
                session.exercises?.removeAll { $0.persistentModelID == logged.persistentModelID }
                context.delete(logged)
            }
        }
        session.endDate = .now
        Haptics.success()
    }
}

struct LoggedExerciseSection: View {
    @Bindable var logged: LoggedExercise
    let suggestion: Training.Suggestion?
    let onSetCompleted: () -> Void
    let onShowDetail: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Section {
            HStack(spacing: 12) {
                ExerciseThumbnail(exercise: ExerciseLibrary.shared.exercise(id: logged.exerciseID), size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(logged.name).font(.headline)
                    Text("Hedef: \(logged.repsLow)-\(logged.repsHigh) tekrar · \(logged.restSeconds) sn dinlenme")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button(action: onShowDetail) {
                        Label("Nasıl yapılır?", systemImage: "play.rectangle")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Hareketi kaldır", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3)
                }
                .fixedSize()
            }
            if let suggestion {
                Label(suggestion.message, systemImage: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack {
                Text("Set").frame(width: 34, alignment: .leading)
                Text("Kg").frame(maxWidth: .infinity)
                Text("Tekrar").frame(maxWidth: .infinity)
                Image(systemName: "checkmark").frame(width: 36)
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)

            ForEach(logged.sortedSets) { set in
                SetRow(set: set, index: (logged.sortedSets.firstIndex { $0.persistentModelID == set.persistentModelID } ?? 0) + 1) {
                    onSetCompleted()
                }
            }
            .onDelete { offsets in
                let sets = logged.sortedSets
                for index in offsets {
                    let set = sets[index]
                    logged.sets?.removeAll { $0.persistentModelID == set.persistentModelID }
                    set.modelContext?.delete(set)
                }
            }

            Button {
                Training.addSet(to: logged)
            } label: {
                Label("Set ekle", systemImage: "plus.circle")
                    .font(.callout)
            }
        }
    }
}

struct SetRow: View {
    @Bindable var set: SetEntry
    let index: Int
    let onComplete: () -> Void

    var body: some View {
        HStack {
            Button {
                set.isWarmup.toggle()
            } label: {
                Text(set.isWarmup ? "Ö" : "\(index)")
                    .font(.callout.bold())
                    .foregroundStyle(set.isWarmup ? Color.orange : Color.primary)
            }
            .buttonStyle(.plain)
            .frame(width: 34, alignment: .leading)
            .help("Isınma seti olarak işaretle")

            TextField("0", value: $set.weight, format: .number.precision(.fractionLength(0...2)))
                .decimalKeyboard()
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

            TextField("0", value: $set.reps, format: .number)
                .numberKeyboard()
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

            Button {
                set.isCompleted.toggle()
                set.completedAt = set.isCompleted ? .now : nil
                if set.isCompleted && !set.isWarmup { onComplete() }
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 36)
        }
        .listRowBackground(set.isCompleted ? Color.green.opacity(0.08) : nil)
    }
}

struct RestTimerBar: View {
    let end: Date
    let total: Int
    let onSkip: () -> Void
    let onAdd: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let remaining = max(0, end.timeIntervalSince(context.date))
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: total > 0 ? remaining / Double(total) : 0)
                        .stroke(remaining > 0 ? Color.accentColor : .green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading) {
                    Text(remaining > 0 ? "Dinlenme" : "Sıradaki sete geç!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(remaining > 0 ? String(format: "%d:%02d", Int(remaining) / 60, Int(remaining) % 60) : "0:00")
                        .font(.title3.monospacedDigit().bold())
                }
                Spacer()
                Button("+15 sn", action: onAdd).buttonStyle(.bordered)
                Button("Geç", action: onSkip).buttonStyle(.borderedProminent)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Geçmiş detay

struct SessionDetailView: View {
    let session: WorkoutSession

    var body: some View {
        List {
            Section {
                LabeledContent("Tarih", value: session.date.formatted(date: .long, time: .shortened))
                LabeledContent("Süre", value: session.duration.durationText)
                LabeledContent("Toplam hacim", value: "\(session.totalVolume.clean) kg")
                if !session.notes.isEmpty {
                    Text(session.notes)
                }
            }
            ForEach(session.sortedExercises) { logged in
                Section(logged.name) {
                    ForEach(Array(logged.sortedSets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text(set.isWarmup ? "Isınma" : "Set \(index + 1)")
                                .foregroundStyle(set.isWarmup ? Color.orange : Color.primary)
                            Spacer()
                            Text("\(set.weight.clean) kg × \(set.reps)")
                                .monospacedDigit()
                        }
                    }
                    if logged.bestOneRepMax > 0 {
                        LabeledContent("Tahmini 1RM", value: "\(logged.bestOneRepMax.clean) kg")
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle(session.title)
    }
}
