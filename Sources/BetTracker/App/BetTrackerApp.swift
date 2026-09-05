import SwiftUI
import SwiftData

@main
struct BetTrackerApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Bet.self, Tournament.self, Team.self, Match.self, BankTransaction.self
            )
        } catch {
            fatalError("Не удалось создать ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.dark)
                .task {
                    SeedData.populateIfNeeded(context: container.mainContext)
                }
        }
        .modelContainer(container)
    }
}
