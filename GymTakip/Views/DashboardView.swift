import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @Query(filter: #Predicate<WorkoutPlan> { $0.isActive }, sort: \WorkoutPlan.createdAt, order: .reverse) private var activePlans: [WorkoutPlan]
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @State private var showSettings = false

    private var profile: UserProfile? { profiles.first }
    private var activePlan: WorkoutPlan? { activePlans.first }
    private var activeSession: WorkoutSession? { sessions.first { !$0.isFinished } }
    private var goal: Goal { activePlan?.goal ?? profile?.goal ?? .hypertrophy }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                nextWorkoutCard
                statsGrid
                muscleBalanceCard
                bodyCard
                recentCard
            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Özet")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSettings = true
                } label: {
                    Label("Profil ve ayarlar", systemImage: "person.crop.circle")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
                #if os(macOS)
                .frame(minWidth: 520, minHeight: 600)
                #endif
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.title2.bold())
            Text("Hedef: \(goal.title)")
                .foregroundStyle(.secondary)
        }
    }

    private var greeting: String {
        let name = profile?.name.trimmingCharacters(in: .whitespaces) ?? ""
        let hour = Calendar.current.component(.hour, from: .now)
        let base = hour < 12 ? "Günaydın" : (hour < 18 ? "İyi günler" : "İyi akşamlar")
        return name.isEmpty ? base : "\(base), \(name)"
    }

    // MARK: - Sıradaki antrenman

    @ViewBuilder
    private var nextWorkoutCard: some View {
        if let activeSession {
            Card("Devam eden antrenman", systemImage: "timer") {
                Text("\(activeSession.title) · \(activeSession.completedSetCount) set tamamlandı")
                    .foregroundStyle(.secondary)
                Button("Antrenmana dön") { appState.selectedTab = .workout }
                    .buttonStyle(.borderedProminent)
            }
        } else if let plan = activePlan, let day = Training.nextDay(in: plan, history: sessions) {
            Card("Sıradaki antrenman", systemImage: "calendar") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.name).font(.title3.bold())
                    Text(day.focus).foregroundStyle(.secondary)
                    Text(day.sortedExercises.map(\.name).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Button {
                    _ = Training.startSession(from: day, in: context, history: sessions)
                    appState.selectedTab = .workout
                } label: {
                    Label("Başla", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            Card("Programın yok", systemImage: "sparkles") {
                Text("Hedefini, seviyeni ve haftada kaç gün çalışabileceğini seç, sana uygun programı hazırlayayım.")
                    .foregroundStyle(.secondary)
                Button("Program oluştur") { appState.selectedTab = .program }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - İstatistikler

    private var statsGrid: some View {
        let thisWeek = Stats.sessions(sessions, since: Stats.startOfWeek)
        let target = profile?.weeklyWorkoutTarget ?? activePlan?.daysPerWeek ?? 3
        let volume = thisWeek.reduce(0) { $0 + $1.totalVolume }
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            StatTile(title: "Bu hafta antrenman", value: "\(thisWeek.count) / \(target)", systemImage: "checkmark.circle.fill", tint: .green)
            StatTile(title: "Bu hafta hacim (kg)", value: volume.formatted(.number.precision(.fractionLength(0))), systemImage: "scalemass.fill", tint: .orange)
            StatTile(title: "Seri (hafta)", value: "\(Stats.weekStreak(sessions))", systemImage: "flame.fill", tint: .red)
            StatTile(title: "Toplam antrenman", value: "\(sessions.filter(\.isFinished).count)", systemImage: "trophy.fill", tint: .yellow)
        }
    }

    // MARK: - Kas dengesi

    private var muscleBalanceCard: some View {
        let sets = Stats.weeklySets(sessions)
        let range = goal.weeklySetRange
        let lagging = MuscleGroup.tracked.filter { (sets[$0] ?? 0) < Double(range.lowerBound) / 2 }
        return Card("Son 7 gün · kas başına set", systemImage: "figure.arms.open") {
            Text("Hedefin için önerilen: kas başına haftada \(range.lowerBound)-\(range.upperBound) set")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(MuscleGroup.tracked) { group in
                MuscleBar(title: group.title, value: sets[group] ?? 0, range: range)
            }
            if !sessions.isEmpty, !lagging.isEmpty {
                Label("Az çalışılanlar: \(lagging.map(\.title).joined(separator: ", "))", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Vücut

    @ViewBuilder
    private var bodyCard: some View {
        let weights = measurements.compactMap { m in m.weight.map { (m.date, $0) } }
        Card("Vücut", systemImage: "figure") {
            if let latest = weights.first {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(latest.1.clean) kg").font(.title.bold())
                    if weights.count > 1 {
                        let diff = latest.1 - weights[weights.count - 1].1
                        Text("\(diff >= 0 ? "+" : "")\(diff.clean) kg (ilk ölçümden beri)")
                            .foregroundStyle(.secondary)
                    }
                }
                if let target = profile?.targetWeight, target > 0 {
                    Text("Hedef kilo: \(target.clean) kg · kalan \(abs(latest.1 - target).clean) kg")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if let height = profile?.heightCm, height > 0 {
                    let bmi = latest.1 / pow(height / 100, 2)
                    Text("Vücut kitle indeksi: \(bmi.clean)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Henüz ölçüm yok. Kilonu ve ölçülerini Gelişim sekmesinden ekleyebilirsin.")
                    .foregroundStyle(.secondary)
            }
            Button("Ölçüm ekle") { appState.selectedTab = .progress }
        }
    }

    // MARK: - Son antrenmanlar

    @ViewBuilder
    private var recentCard: some View {
        let recent = sessions.filter(\.isFinished).prefix(4)
        if !recent.isEmpty {
            Card("Son antrenmanlar", systemImage: "clock.arrow.circlepath") {
                ForEach(Array(recent)) { session in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(session.title).font(.subheadline.bold())
                            Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(session.completedSetCount) set · \(session.totalVolume.formatted(.number.precision(.fractionLength(0)))) kg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct MuscleBar: View {
    let title: String
    let value: Double
    let range: ClosedRange<Int>

    private var color: Color {
        if value >= Double(range.lowerBound) { return .green }
        if value >= Double(range.lowerBound) / 2 { return .orange }
        return .red.opacity(0.7)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.callout)
                .frame(width: 130, alignment: .leading)
            GeometryReader { geo in
                let fraction = min(1, value / Double(range.upperBound))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule().fill(color).frame(width: max(4, geo.size.width * fraction))
                }
            }
            .frame(height: 10)
            Text(value.clean)
                .font(.caption.monospacedDigit())
                .frame(width: 32, alignment: .trailing)
        }
    }
}
