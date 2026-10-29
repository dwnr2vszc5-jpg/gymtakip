import SwiftUI
import SwiftData
import Charts

enum BodyMetric: String, CaseIterable, Identifiable {
    case weight, bodyFat, chest, shoulders, waist, hips, arm, forearm, thigh, calf, neck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: "Kilo"
        case .bodyFat: "Yağ oranı"
        case .chest: "Göğüs"
        case .shoulders: "Omuz"
        case .waist: "Bel"
        case .hips: "Kalça"
        case .arm: "Kol (pazu)"
        case .forearm: "Ön kol"
        case .thigh: "Bacak (uyluk)"
        case .calf: "Baldır"
        case .neck: "Boyun"
        }
    }

    var unit: String {
        switch self {
        case .weight: "kg"
        case .bodyFat: "%"
        default: "cm"
        }
    }

    var keyPath: ReferenceWritableKeyPath<BodyMeasurement, Double?> {
        switch self {
        case .weight: \.weight
        case .bodyFat: \.bodyFat
        case .chest: \.chest
        case .shoulders: \.shoulders
        case .waist: \.waist
        case .hips: \.hips
        case .arm: \.arm
        case .forearm: \.forearm
        case .thigh: \.thigh
        case .calf: \.calf
        case .neck: \.neck
        }
    }
}

struct ProgressTabView: View {
    enum Pane: String, CaseIterable, Identifiable {
        case body, strength, volume
        var id: String { rawValue }
        var title: String {
            switch self {
            case .body: "Vücut"
            case .strength: "Güç"
            case .volume: "Hacim"
            }
        }
    }

    @State private var pane: Pane = .body

    var body: some View {
        VStack(spacing: 0) {
            Picker("Bölüm", selection: $pane) {
                ForEach(Pane.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding()

            switch pane {
            case .body: BodyProgressView()
            case .strength: StrengthProgressView()
            case .volume: VolumeProgressView()
            }
        }
        .navigationTitle("Gelişim")
    }
}

struct BodyProgressView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]
    @State private var metric: BodyMetric = .weight
    @State private var editing: BodyMeasurement?

    var body: some View {
        let points = measurements.compactMap { m in m[keyPath: metric.keyPath].map { (date: m.date, value: $0) } }.reversed()
        List {
            Section {
                Picker("Ölçü", selection: $metric) {
                    ForEach(BodyMetric.allCases) { Text($0.title).tag($0) }
                }
                if points.count >= 2 {
                    Chart(Array(points), id: \.date) { point in
                        LineMark(x: .value("Tarih", point.date), y: .value(metric.title, point.value))
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("Tarih", point.date), y: .value(metric.title, point.value))
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartYAxisLabel(metric.unit)
                    .frame(height: 200)
                    if let first = points.first, let last = points.last {
                        let diff = last.value - first.value
                        Text("Değişim: \(diff >= 0 ? "+" : "")\(diff.clean) \(metric.unit) (\(first.date.formatted(date: .abbreviated, time: .omitted)) → bugün)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Grafik için bu ölçüden en az iki kayıt gerekli.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Ölçümler") {
                Button {
                    let new = BodyMeasurement()
                    context.insert(new)
                    editing = new
                } label: {
                    Label("Yeni ölçüm ekle", systemImage: "plus.circle.fill")
                }
                ForEach(measurements) { m in
                    Button {
                        editing = m
                    } label: {
                        HStack {
                            Text(m.date.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(summary(m))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(measurements[index]) }
                }
            }
        }
        .sheet(item: $editing, onDismiss: removeEmptyMeasurements) { m in
            NavigationStack { MeasurementEditor(measurement: m) }
            #if os(macOS)
            .frame(minWidth: 460, minHeight: 600)
            #endif
        }
    }

    /// Hiç değer girilmeden kapatılan yeni ölçümleri sil.
    private func removeEmptyMeasurements() {
        for m in measurements where m.notes.isEmpty && BodyMetric.allCases.allSatisfy({ m[keyPath: $0.keyPath] == nil }) {
            context.delete(m)
        }
    }

    private func summary(_ m: BodyMeasurement) -> String {
        BodyMetric.allCases.compactMap { metric in
            m[keyPath: metric.keyPath].map { "\(metric.title) \($0.clean)\(metric.unit)" }
        }
        .prefix(3)
        .joined(separator: " · ")
    }
}

struct MeasurementEditor: View {
    @Bindable var measurement: BodyMeasurement
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            DatePicker("Tarih", selection: $measurement.date, displayedComponents: .date)
            Section("Ölçüler") {
                ForEach(BodyMetric.allCases) { metric in
                    HStack {
                        Text(metric.title)
                        Spacer()
                        TextField("-", value: Binding(
                            get: { measurement[keyPath: metric.keyPath] },
                            set: { measurement[keyPath: metric.keyPath] = $0 }
                        ), format: .number.precision(.fractionLength(0...1)))
                        .decimalKeyboard()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90)
                        Text(metric.unit)
                            .foregroundStyle(.secondary)
                            .frame(width: 26, alignment: .leading)
                    }
                }
            }
            Section("İpucu") {
                Text("Ölçüleri haftada bir, sabah aç karnına ve aynı noktalardan al. Kol ölçüsünü kası kasılı haldeyken en kalın yerinden ölç.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Not") {
                TextField("Not", text: $measurement.notes, axis: .vertical)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Ölçüm")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Bitti") { dismiss() }
            }
        }
    }
}

struct StrengthProgressView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @State private var selectedID: String?

    var body: some View {
        let trained = Stats.trainedExercises(sessions)
        List {
            if trained.isEmpty {
                Text("Antrenman kaydettikçe her hareket için güç gelişimin (tahmini 1 tekrar maksimumu) burada görünecek.")
                    .foregroundStyle(.secondary)
            } else {
                let current = selectedID ?? trained.first?.id
                Section {
                    Picker("Hareket", selection: Binding(get: { current ?? "" }, set: { selectedID = $0 })) {
                        ForEach(trained, id: \.id) { item in
                            Text("\(item.name) (\(item.count))").tag(item.id)
                        }
                    }
                    if let current {
                        let points = Stats.strengthHistory(for: current, history: sessions)
                        if points.count >= 2 {
                            StrengthChart(points: points)
                        }
                        if let first = points.first, let last = points.last {
                            LabeledContent("İlk tahmini 1RM", value: "\(first.oneRepMax.clean) kg")
                            LabeledContent("Son tahmini 1RM", value: "\(last.oneRepMax.clean) kg")
                            if first.oneRepMax > 0 {
                                let percent = (last.oneRepMax - first.oneRepMax) / first.oneRepMax * 100
                                LabeledContent("Gelişim", value: "\(percent >= 0 ? "+" : "")\(percent.clean)%")
                            }
                        }
                    }
                }
                Section("Kişisel rekorlar") {
                    ForEach(trained.prefix(15), id: \.id) { item in
                        let best = Stats.strengthHistory(for: item.id, history: sessions).map(\.bestWeight).max() ?? 0
                        LabeledContent(item.name, value: "\(best.clean) kg")
                    }
                }
            }
        }
    }
}

struct VolumeProgressView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    var body: some View {
        let weeks = Stats.weeklyVolume(sessions)
        let sets = Stats.weeklySets(sessions)
        let range = (profiles.first?.goal ?? .hypertrophy).weeklySetRange
        List {
            Section("Haftalık toplam hacim (kg × tekrar)") {
                Chart(weeks) { week in
                    BarMark(x: .value("Hafta", week.weekStart, unit: .weekOfYear), y: .value("Hacim", week.volume))
                        .foregroundStyle(Color.accentColor.gradient)
                }
                .frame(height: 200)
            }
            Section("Haftalık antrenman sayısı") {
                Chart(weeks) { week in
                    BarMark(x: .value("Hafta", week.weekStart, unit: .weekOfYear), y: .value("Antrenman", week.sessions))
                        .foregroundStyle(Color.green.gradient)
                }
                .frame(height: 140)
            }
            Section("Son 7 gün · kas başına set") {
                ForEach(MuscleGroup.tracked) { group in
                    MuscleBar(title: group.title, value: sets[group] ?? 0, range: range)
                }
            }
        }
    }
}
