import Foundation

/// Матч, как его отдаёт бэкенд. Ключи в snake_case — так их отдаёт D1,
/// переименование делает `CodingKeys`, а не декодер целиком, чтобы
/// случайное поле в другом стиле не сломало разбор всего ответа.
struct RemoteMatch: Codable, Identifiable, Hashable {
    let id: Int
    let discipline: String
    let tournamentName: String?
    let teamA: String?
    let teamB: String?
    let bestOf: Int?
    let scheduledAt: Int?
    let status: String
    let scoreA: Int?
    let scoreB: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case discipline
        case tournamentName = "tournament_name"
        case teamA = "team_a"
        case teamB = "team_b"
        case bestOf = "best_of"
        case scheduledAt = "scheduled_at"
        case status
        case scoreA = "score_a"
        case scoreB = "score_b"
    }

    var scheduledDate: Date? {
        scheduledAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    var isFinished: Bool { status == "finished" }

    var title: String {
        "\(teamA ?? "?") — \(teamB ?? "?")"
    }

    var scoreLine: String? {
        guard let scoreA, let scoreB else { return nil }
        return "\(scoreA) : \(scoreB)"
    }
}

struct RemoteMatchList: Codable {
    let matches: [RemoteMatch]
}

/// Предматчевый разбор.
struct MatchPreview: Codable, Identifiable {
    let matchId: Int
    let cached: Bool
    let generatedAt: Int
    let model: String
    let costUsd: Double?
    let analysis: PreviewAnalysis
    let sources: [String]

    var id: Int { matchId }

    var generatedDate: Date { Date(timeIntervalSince1970: TimeInterval(generatedAt)) }
}

struct PreviewAnalysis: Codable {
    let verdict: String
    let confidence: String
    let factorsA: [String]
    let factorsB: [String]
    let handicapNote: String
    let unknowns: [String]
    let watch: [String]

    enum CodingKeys: String, CodingKey {
        case verdict
        case confidence
        case factorsA = "factors_a"
        case factorsB = "factors_b"
        case handicapNote = "handicap_note"
        case unknowns
        case watch
    }

    /// Насколько данных хватило модели — показывается пользователю честно,
    /// чтобы разбор на скудных данных не выглядел как уверенный вывод.
    var confidenceLabel: String {
        switch confidence.lowercased() {
        case "high": return "данных достаточно"
        case "medium": return "данных умеренно"
        case "low": return "данных мало"
        default: return confidence
        }
    }
}

/// Саммари завершённого матча.
struct MatchSummary: Codable, Identifiable {
    let matchId: Int
    let generatedAt: Int
    let summary: SummaryBody

    var id: Int { matchId }
}

struct SummaryBody: Codable {
    let headline: String
    let body: String
    let notable: [String]
}

struct SpendInfo: Codable {
    let spentTodayUsd: Double
}

struct BackendError: Codable {
    let error: String
}
