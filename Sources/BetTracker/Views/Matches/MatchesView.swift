import SwiftUI

/// Матчи с бэкенда: расписание и результаты по трём дисциплинам.
///
/// Это отдельная от «Турниров» вкладка намеренно: турниры пользователь
/// ведёт руками, а здесь данные приезжают снаружи. Смешивать источники в
/// одном списке значило бы врать о происхождении цифр.
struct MatchesView: View {
    @Environment(BackendSettings.self) private var settings

    @State private var mode: Mode = .upcoming
    @State private var discipline: String? = nil
    @State private var matches: [RemoteMatch] = []
    @State private var isLoading = false
    @State private var error: String?

    enum Mode: String, CaseIterable {
        case upcoming, past

        var label: String { self == .upcoming ? "Предстоящие" : "Прошедшие" }
    }

    private let disciplines: [(String?, String)] = [
        (nil, "Все"), ("valorant", "VALORANT"), ("cs2", "CS2"), ("dota2", "DOTA 2"),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if !settings.isConfigured {
                    NotConfiguredView()
                } else {
                    content
                }
            }
            .navigationTitle("Матчи")
            .background(Theme.background)
        }
        .task(id: taskKey) { await load() }
    }

    private var taskKey: String {
        "\(mode.rawValue)-\(discipline ?? "all")-\(settings.baseURL)"
    }

    private var content: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(disciplines, id: \.1) { value, label in
                        FilterChip(label: label, isActive: discipline == value) {
                            discipline = value
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 8)

            if isLoading && matches.isEmpty {
                Spacer()
                ProgressView().tint(Theme.accent)
                Spacer()
            } else if let error {
                Spacer()
                ErrorNotice(message: error) { Task { await load() } }
                Spacer()
            } else if matches.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "Матчей нет",
                    systemImage: "calendar",
                    description: Text("Бэкенд пока не принёс матчей по этому фильтру.")
                )
                Spacer()
            } else {
                List {
                    ForEach(groupedMatches, id: \.0) { tournament, items in
                        Section {
                            ForEach(items) { match in
                                NavigationLink(value: match) {
                                    MatchRow(match: match)
                                }
                                .listRowBackground(Theme.surface)
                            }
                        } header: {
                            Text(tournament)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.textDim)
                        }
                    }

                    AttributionFooter()
                        .listRowBackground(Color.clear)
                }
                .listStyle(.insetGrouped)
                .screenBackground()
                .refreshable { await load() }
            }
        }
        .navigationDestination(for: RemoteMatch.self) { MatchDetailView(match: $0) }
    }

    private var groupedMatches: [(String, [RemoteMatch])] {
        let groups = Dictionary(grouping: matches) { $0.tournamentName ?? "Без турнира" }
        return groups.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    private func load() async {
        guard settings.isConfigured else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let client = BackendClient(settings: settings)
            matches = mode == .upcoming
                ? try await client.upcomingMatches(discipline: discipline)
                : try await client.pastMatches(discipline: discipline)
        } catch {
            self.error = error.localizedDescription
            matches = []
        }
    }
}

struct MatchRow: View {
    let match: RemoteMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(match.title)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if let score = match.scoreLine {
                    Text(score)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                }
            }

            HStack(spacing: 8) {
                Text(match.discipline.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.accent)

                if let date = match.scheduledDate {
                    Text(DateFormatting.dayMonthTimeRu.string(from: date))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textDim)
                }

                if let bestOf = match.bestOf {
                    Text("BO\(bestOf)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textFaint)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12.5, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isActive ? Theme.accent : Theme.surface)
                .foregroundStyle(isActive ? Color.black : Theme.textDim)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ErrorNotice: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(BetStatus.pending.color)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
            Button("Повторить", action: retry)
                .buttonStyle(.bordered)
                .tint(Theme.accent)
        }
        .padding(24)
    }
}

struct NotConfiguredView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Бэкенд не подключён", systemImage: "network.slash")
        } description: {
            Text("Укажи адрес воркера и токен в настройках — тогда сюда приедут матчи, предматчевый разбор и саммари.")
        }
    }
}

/// Атрибуция источников — требование условий использования PandaScore и
/// Liquipedia, а не украшение.
struct AttributionFooter: View {
    var body: some View {
        VStack(spacing: 2) {
            Text("Данные: Source: PandaScore")
            Text("Liquipedia, CC-BY-SA 3.0")
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.textFaint)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}
