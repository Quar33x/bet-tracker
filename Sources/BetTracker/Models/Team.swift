import Foundation
import SwiftData

@Model
final class Team {
    var id: UUID
    var name: String
    var shortName: String
    var externalID: String?
    var tournament: Tournament?

    /// Групповой W-L по турниру. Не выводится из `matches`, потому что в
    /// стадии 1 матчи заполняются вручную и список матчей неполный —
    /// счёт серии в группе таблице турнира трекается отдельно, как
    /// внешний факт, а не производная величина.
    var wins: Int
    var losses: Int

    init(
        name: String,
        shortName: String,
        wins: Int = 0,
        losses: Int = 0,
        externalID: String? = nil,
        tournament: Tournament? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.shortName = shortName
        self.wins = wins
        self.losses = losses
        self.externalID = externalID
        self.tournament = tournament
    }
}
