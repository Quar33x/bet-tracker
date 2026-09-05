import Foundation
import SwiftData

@Model
final class Match {
    var id: UUID
    var tournament: Tournament?
    var teamA: Team
    var teamB: Team
    var format: String
    var scheduledAt: Date
    var scoreA: Int?
    var scoreB: Int?
    var isFinished: Bool

    init(
        tournament: Tournament?,
        teamA: Team,
        teamB: Team,
        format: String,
        scheduledAt: Date,
        scoreA: Int? = nil,
        scoreB: Int? = nil,
        isFinished: Bool = false
    ) {
        self.id = UUID()
        self.tournament = tournament
        self.teamA = teamA
        self.teamB = teamB
        self.format = format
        self.scheduledAt = scheduledAt
        self.scoreA = scoreA
        self.scoreB = scoreB
        self.isFinished = isFinished
    }
}
