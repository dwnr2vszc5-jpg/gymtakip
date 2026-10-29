import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        #if os(macOS)
        NavigationSplitView {
            List(AppTab.allCases, selection: Binding<AppTab?>(
                get: { appState.selectedTab },
                set: { if let tab = $0 { appState.selectedTab = tab } }
            )) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
            .navigationTitle("GymTakip")
        } detail: {
            NavigationStack {
                content(for: appState.selectedTab)
            }
            .id(appState.selectedTab)
        }
        #else
        TabView(selection: $appState.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    content(for: tab)
                }
                .tabItem { Label(tab.title, systemImage: tab.icon) }
                .tag(tab)
            }
        }
        #endif
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .dashboard: DashboardView()
        case .workout: WorkoutTabView()
        case .program: ProgramView()
        case .library: ExerciseLibraryView()
        case .progress: ProgressTabView()
        }
    }
}
