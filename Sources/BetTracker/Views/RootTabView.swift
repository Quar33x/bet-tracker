import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            BetsListView()
                .tabItem { Label("Ставки", systemImage: "list.bullet") }
            MatchesView()
                .tabItem { Label("Матчи", systemImage: "sparkles") }
            TournamentsListView()
                .tabItem { Label("Турниры", systemImage: "trophy") }
            DashboardView()
                .tabItem { Label("Дашборд", systemImage: "chart.bar") }
            BankView()
                .tabItem { Label("Банк", systemImage: "banknote") }
            SettingsView()
                .tabItem { Label("Ещё", systemImage: "gearshape") }
        }
        .tint(Theme.accent)
    }
}
