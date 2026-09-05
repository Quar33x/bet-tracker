import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            BetsListView()
                .tabItem { Label("Ставки", systemImage: "list.bullet") }
            TournamentsListView()
                .tabItem { Label("Турниры", systemImage: "trophy") }
            DashboardView()
                .tabItem { Label("Дашборд", systemImage: "chart.bar") }
            BankView()
                .tabItem { Label("Банк", systemImage: "banknote") }
        }
        .tint(Theme.accent)
    }
}
