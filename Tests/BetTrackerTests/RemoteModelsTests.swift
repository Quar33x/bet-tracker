import XCTest
@testable import BetTracker

/// Разбор ответов бэкенда. Ключи там в snake_case, и любая опечатка в
/// `CodingKeys` тихо превращается в пустой экран, поэтому проверяем на
/// образцах, совпадающих с тем, что реально отдаёт воркер.
final class RemoteModelsTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    func testDecodesUpcomingMatch() throws {
        let list = try decode(RemoteMatchList.self, """
        {"matches": [{
            "id": 12,
            "discipline": "cs2",
            "source": "pandascore",
            "external_id": "998877",
            "tournament_name": "BLAST Open - Porto 2026",
            "team_a": "FURIA",
            "team_b": "Vitality",
            "best_of": 3,
            "scheduled_at": 1788537600,
            "status": "scheduled",
            "score_a": null,
            "score_b": null
        }]}
        """)

        let match = try XCTUnwrap(list.matches.first)
        XCTAssertEqual(match.id, 12)
        XCTAssertEqual(match.teamA, "FURIA")
        XCTAssertEqual(match.tournamentName, "BLAST Open - Porto 2026")
        XCTAssertEqual(match.bestOf, 3)
        XCTAssertFalse(match.isFinished)
        XCTAssertNil(match.scoreLine)
        XCTAssertEqual(match.title, "FURIA — Vitality")
        XCTAssertEqual(match.scheduledDate, Date(timeIntervalSince1970: 1788537600))
    }

    func testDecodesFinishedMatchWithScore() throws {
        let list = try decode(RemoteMatchList.self, """
        {"matches": [{
            "id": 13, "discipline": "dota2", "source": "opendota", "external_id": "1",
            "tournament_name": null, "team_a": "Spirit", "team_b": "Tundra",
            "best_of": null, "scheduled_at": null, "status": "finished",
            "score_a": 2, "score_b": 1
        }]}
        """)

        let match = try XCTUnwrap(list.matches.first)
        XCTAssertTrue(match.isFinished)
        XCTAssertEqual(match.scoreLine, "2 : 1")
        XCTAssertNil(match.scheduledDate)
        XCTAssertNil(match.tournamentName)
    }

    func testDecodesPreview() throws {
        let preview = try decode(MatchPreview.self, """
        {
          "matchId": 12, "cached": false, "generatedAt": 1788537600,
          "model": "claude-opus-5", "costUsd": 0.184,
          "analysis": {
            "verdict": "Vitality заметно прочнее по раундам.",
            "confidence": "medium",
            "factors_a": ["56.7% выигранных раундов"],
            "factors_b": ["Форма 3-7 за последние матчи"],
            "handicap_note": "Запас по раундам говорит в пользу форы.",
            "unknowns": ["Нет данных по картам"],
            "watch": ["Составы перед матчем"]
          },
          "sources": ["Liquipedia (CC-BY-SA 3.0)"]
        }
        """)

        XCTAssertEqual(preview.matchId, 12)
        XCTAssertFalse(preview.cached)
        XCTAssertEqual(preview.analysis.factorsA.first, "56.7% выигранных раундов")
        XCTAssertEqual(preview.analysis.unknowns.count, 1)
        XCTAssertEqual(preview.sources.first, "Liquipedia (CC-BY-SA 3.0)")
    }

    func testConfidenceLabelIsHumanReadable() throws {
        func label(_ value: String) throws -> String {
            try decode(PreviewAnalysis.self, """
            {"verdict": "", "confidence": "\(value)", "factors_a": [], "factors_b": [],
             "handicap_note": "", "unknowns": [], "watch": []}
            """).confidenceLabel
        }

        XCTAssertEqual(try label("high"), "данных достаточно")
        XCTAssertEqual(try label("medium"), "данных умеренно")
        XCTAssertEqual(try label("low"), "данных мало")
        XCTAssertEqual(try label("странное"), "странное")
    }

    func testDecodesSummary() throws {
        let summary = try decode(MatchSummary.self, """
        {
          "matchId": 13, "generatedAt": 1788537600,
          "summary": {
            "headline": "Vitality обыграла FURIA 2:1.",
            "body": "Серия шла до третьей карты.",
            "notable": ["Первая карта ушла на овертайм"]
          }
        }
        """)

        XCTAssertEqual(summary.summary.headline, "Vitality обыграла FURIA 2:1.")
        XCTAssertEqual(summary.summary.notable.count, 1)
    }

    func testDecodesBackendError() throws {
        let error = try decode(BackendError.self, #"{"error": "саммари ещё не готово"}"#)
        XCTAssertEqual(error.error, "саммари ещё не готово")
    }
}

final class BackendSettingsTests: XCTestCase {

    func testNotConfiguredWithoutURLOrToken() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "backend.baseURL")
        defaults.removeObject(forKey: "backend.token")

        let settings = BackendSettings()
        XCTAssertFalse(settings.isConfigured)

        settings.baseURL = "https://example.workers.dev"
        XCTAssertFalse(settings.isConfigured, "без токена подключаться нельзя")

        settings.token = "secret"
        XCTAssertTrue(settings.isConfigured)

        settings.token = "   "
        XCTAssertFalse(settings.isConfigured, "пробелы — это не токен")
    }
}
