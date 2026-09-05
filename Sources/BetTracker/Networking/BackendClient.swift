import Foundation

/// Настройки подключения к своему воркеру.
///
/// Приложение ничего не знает ни о PandaScore, ни о Liquipedia, ни о
/// Claude — только адрес своего бэкенда и токен к нему. Ключи внешних
/// сервисов живут в секретах воркера и в бинарник не попадают.
@Observable
final class BackendSettings {
    var baseURL: String {
        didSet { UserDefaults.standard.set(baseURL, forKey: Keys.baseURL) }
    }

    var token: String {
        didSet { UserDefaults.standard.set(token, forKey: Keys.token) }
    }

    private enum Keys {
        static let baseURL = "backend.baseURL"
        static let token = "backend.token"
    }

    init() {
        baseURL = UserDefaults.standard.string(forKey: Keys.baseURL) ?? ""
        token = UserDefaults.standard.string(forKey: Keys.token) ?? ""
    }

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty
            && !token.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

enum BackendClientError: LocalizedError {
    case notConfigured
    case badURL
    case unauthorized
    case budgetExceeded(String)
    case refused(String)
    case notReady
    case server(Int, String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Бэкенд не настроен: укажи адрес и токен в настройках."
        case .badURL:
            return "Адрес бэкенда выглядит неправильно."
        case .unauthorized:
            return "Токен не подошёл."
        case .budgetExceeded(let message):
            return message
        case .refused(let message):
            return message
        case .notReady:
            return "Ещё не готово."
        case .server(let code, let message):
            return "Ошибка \(code): \(message)"
        }
    }
}

struct BackendClient {
    let settings: BackendSettings
    var session: URLSession = .shared

    private func request(path: String, query: [URLQueryItem] = []) throws -> URLRequest {
        guard settings.isConfigured else { throw BackendClientError.notConfigured }

        let trimmed = settings.baseURL.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: trimmed + path) else {
            throw BackendClientError.badURL
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw BackendClientError.badURL }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendClientError.server(0, "нет ответа")
        }

        if http.statusCode == 200 {
            return try JSONDecoder().decode(T.self, from: data)
        }

        let message = (try? JSONDecoder().decode(BackendError.self, from: data))?.error
            ?? "неизвестная ошибка"

        switch http.statusCode {
        case 401: throw BackendClientError.unauthorized
        case 404: throw BackendClientError.notReady
        case 422: throw BackendClientError.refused(message)
        case 429: throw BackendClientError.budgetExceeded(message)
        default: throw BackendClientError.server(http.statusCode, message)
        }
    }

    func upcomingMatches(discipline: String? = nil, limit: Int = 50) async throws -> [RemoteMatch] {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let discipline { query.append(URLQueryItem(name: "discipline", value: discipline)) }
        return try await send(request(path: "/matches/upcoming", query: query), as: RemoteMatchList.self).matches
    }

    func pastMatches(discipline: String? = nil, limit: Int = 50) async throws -> [RemoteMatch] {
        var query = [URLQueryItem(name: "limit", value: String(limit))]
        if let discipline { query.append(URLQueryItem(name: "discipline", value: discipline)) }
        return try await send(request(path: "/matches/past", query: query), as: RemoteMatchList.self).matches
    }

    /// Предматчевый разбор. `force` заставляет пересчитать даже при живом
    /// кэше — это платный вызов, поэтому по умолчанию выключен.
    func preview(matchId: Int, force: Bool = false) async throws -> MatchPreview {
        let query = force ? [URLQueryItem(name: "force", value: "1")] : []
        return try await send(request(path: "/matches/\(matchId)/preview", query: query), as: MatchPreview.self)
    }

    func summary(matchId: Int) async throws -> MatchSummary {
        try await send(request(path: "/matches/\(matchId)/summary"), as: MatchSummary.self)
    }

    func spentToday() async throws -> Double {
        try await send(request(path: "/spend"), as: SpendInfo.self).spentTodayUsd
    }
}
