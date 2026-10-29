import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]

    @State private var exportDocument: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var message: String?

    var body: some View {
        Form {
            if let profile = profiles.first {
                ProfileSection(profile: profile)
            } else {
                Section {
                    ProgressView()
                }
                .onAppear { context.insert(UserProfile()) }
            }

            Section("Senkronizasyon") {
                let signedIn = FileManager.default.ubiquityIdentityToken != nil
                Label(signedIn ? "Bu cihazda iCloud oturumu açık" : "Bu cihazda iCloud oturumu kapalı",
                      systemImage: signedIn ? "icloud.fill" : "icloud.slash")
                    .foregroundStyle(signedIn ? Color.green : Color.orange)
                Text("Uygulama Xcode'da iCloud (CloudKit) özelliğiyle derlendiyse antrenmanların, programların ve ölçümlerin aynı Apple hesabıyla giriş yapılmış Mac ve iPhone arasında otomatik senkronlanır. iCloud kullanılamıyorsa aşağıdaki yedekleme ile verileri AirDrop veya Dosyalar üzerinden taşıyabilirsin.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Yedekleme") {
                Button {
                    do {
                        let data = try BackupData.encoder.encode(BackupData(sessions: sessions, measurements: measurements))
                        exportDocument = BackupDocument(data: data)
                        showExporter = true
                    } catch {
                        message = "Yedek oluşturulamadı: \(error.localizedDescription)"
                    }
                } label: {
                    Label("Yedeği dışa aktar (JSON)", systemImage: "square.and.arrow.up")
                }
                Button {
                    showImporter = true
                } label: {
                    Label("Yedeği içe aktar", systemImage: "square.and.arrow.down")
                }
                if let message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Hakkında") {
                Text("Hareket veritabanı: Free Exercise DB (yuhonas/free-exercise-db, kamu malı). Görseller internetten yüklenir. Fikir: openGym.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Profil ve ayarlar")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Bitti") { dismiss() }
            }
        }
        .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .json,
                      defaultFilename: "GymTakip-yedek-\(Date.now.formatted(.iso8601.year().month().day()))") { result in
            if case .failure(let error) = result {
                message = "Dışa aktarılamadı: \(error.localizedDescription)"
            } else {
                message = "Yedek kaydedildi."
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            importBackup(result)
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let backup = try BackupData.decoder.decode(BackupData.self, from: data)
            let (addedSessions, addedMeasurements) = backup.restore(into: context, existingSessions: sessions, existingMeasurements: measurements)
            message = "\(addedSessions) antrenman ve \(addedMeasurements) ölçüm içe aktarıldı."
        } catch {
            message = "İçe aktarılamadı: \(error.localizedDescription)"
        }
    }
}

struct ProfileSection: View {
    @Bindable var profile: UserProfile

    var body: some View {
        Section("Profil") {
            TextField("Adın", text: $profile.name)
            Picker("Ana hedef", selection: Binding(get: { profile.goal }, set: { profile.goal = $0 })) {
                ForEach(Goal.allCases) { Text($0.title).tag($0) }
            }
            HStack {
                Text("Boy")
                Spacer()
                TextField("cm", value: $profile.heightCm, format: .number.precision(.fractionLength(0)))
                    .decimalKeyboard()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
                Text("cm").foregroundStyle(.secondary)
            }
            HStack {
                Text("Hedef kilo")
                Spacer()
                TextField("kg", value: $profile.targetWeight, format: .number.precision(.fractionLength(0...1)))
                    .decimalKeyboard()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
                Text("kg").foregroundStyle(.secondary)
            }
            Stepper("Haftalık hedef: \(profile.weeklyWorkoutTarget) antrenman", value: $profile.weeklyWorkoutTarget, in: 1...7)
        }
    }
}
