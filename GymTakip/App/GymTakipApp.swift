import SwiftUI
import SwiftData

@main
struct GymTakipApp: App {
    let container: ModelContainer
    @State private var appState = AppState()

    init() {
        let schema = Schema(AppSchema.models)
        // .automatic: Xcode'da iCloud (CloudKit) yetkisi eklendiyse veriler iCloud ile Mac ve iPhone arasında
        // senkronlanır; eklenmediyse uygulama yerel veritabanıyla çalışır.
        let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        if let container = try? ModelContainer(for: schema, configurations: [cloud]) {
            self.container = container
        } else {
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            do {
                container = try ModelContainer(for: schema, configurations: [local])
            } catch {
                fatalError("Veritabanı açılamadı: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1180, height: 780)
        #endif
    }
}

@Observable
final class AppState {
    var selectedTab: AppTab = .dashboard
}

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case dashboard, workout, program, library, progress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Özet"
        case .workout: "Antrenman"
        case .program: "Program"
        case .library: "Hareketler"
        case .progress: "Gelişim"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: "house.fill"
        case .workout: "figure.strengthtraining.traditional"
        case .program: "list.bullet.clipboard"
        case .library: "books.vertical.fill"
        case .progress: "chart.line.uptrend.xyaxis"
        }
    }
}
