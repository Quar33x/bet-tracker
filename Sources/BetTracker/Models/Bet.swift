import Foundation
import SwiftData

@Model
final class Bet {
    var id: UUID
    var date: Date
    var disciplineRaw: String
    var title: String
    var amount: Decimal
    var odds: Decimal
    var statusRaw: String
    var betType: String?
    var tournament: Tournament?
    var note: String?

    var discipline: Discipline {
        get { Discipline(rawValue: disciplineRaw) ?? .other }
        set { disciplineRaw = newValue.rawValue }
    }

    var status: BetStatus {
        get { BetStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    init(
        date: Date,
        discipline: Discipline,
        title: String,
        amount: Decimal,
        odds: Decimal,
        status: BetStatus = .pending,
        betType: String? = nil,
        tournament: Tournament? = nil,
        note: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.disciplineRaw = discipline.rawValue
        self.title = title
        self.amount = amount
        self.odds = odds
        self.statusRaw = status.rawValue
        self.betType = betType
        self.tournament = tournament
        self.note = note
    }
}
