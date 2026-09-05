import Foundation
import SwiftData

@Model
final class Tournament {
    var id: UUID
    var name: String
    var disciplineRaw: String
    var stage: String?
    var startDate: Date?
    var endDate: Date?
    var externalID: String?

    @Relationship(deleteRule: .cascade, inverse: \Team.tournament)
    var teams: [Team] = []

    @Relationship(deleteRule: .cascade, inverse: \Match.tournament)
    var matches: [Match] = []

    @Relationship(deleteRule: .nullify, inverse: \Bet.tournament)
    var bets: [Bet] = []

    var discipline: Discipline {
        get { Discipline(rawValue: disciplineRaw) ?? .other }
        set { disciplineRaw = newValue.rawValue }
    }

    init(
        name: String,
        discipline: Discipline,
        stage: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        externalID: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.disciplineRaw = discipline.rawValue
        self.stage = stage
        self.startDate = startDate
        self.endDate = endDate
        self.externalID = externalID
    }
}
