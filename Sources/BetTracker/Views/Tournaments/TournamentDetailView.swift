import SwiftUI
import SwiftData

struct TournamentDetailView: View {
    let tournament: Tournament

    @Query private var bets: [Bet]
    @State private var tab: DetailTab = .upcoming

    enum DetailTab: String, CaseIterable, Identifiable {
        case upcoming, past, teams
        var id: String { rawValue }
        var label: String {
            switch self {
            case .upcoming: return "Предстоящие"
            case .past: return "Прошедшие"
            case .teams: return "Команды"
            }
        }
    }

    private var stats: StatsCalculator.TournamentStats {
        StatsCalculator.stats(for: tournament, in: bets)
    }

    private var upcomingMatches: [Match] {
        tournament.matches.filter { !$0.isFinished }.sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private var pastMatches: [Match] {
        tournament.matches.filter(\.isFinished).sorted { $0.scheduledAt > $1.scheduledAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                myStats

                Picker("Раздел", selection: $tab) {
                    ForEach(DetailTab.allCases) { t in
                        Text(t.label).tag(t)
                    }
                }
                .pickerStyle(.segmented)

                content
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle(tournament.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tournament.discipline.displayName)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(tournament.discipline.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tournament.discipline.accentColor.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(tournament.name)
                .font(.system(size: 24, weight: .bold))
                .padding(.top, 6)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var subtitle: String {
        let dates = [tournament.startDate, tournament.endDate]
            .compactMap { $0.map { DateFormatting.mediumRu.string(from: $0) } }
            .joined(separator: " — ")
        return [tournament.stage, dates.isEmpty ? nil : dates]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    @ViewBuilder
    private var myStats: some View {
        Text("Твоя статистика")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.textDim)

        if stats.hasBets {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCard(label: "Ставок", value: "\(stats.count)")
                StatCard(label: "Винрейт", value: PercentFormatter.string(stats.winRate, digits: 0))
                StatCard(
                    label: "Профит",
                    value: MoneyFormatter.signed(stats.netProfit),
                    valueColor: Theme.profitColor(stats.netProfit)
                )
                StatCard(
                    label: "ROI",
                    value: PercentFormatter.signed(NSDecimalNumber(decimal: stats.roi).doubleValue, digits: 0)
                )
            }
        } else {
            Text("Ставок на этом турнире пока нет")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .upcoming:
            matchList(upcomingMatches, emptyText: "Пока нет запланированных матчей.")
        case .past:
            matchList(pastMatches, emptyText: "Матчи ещё не проходили.")
        case .teams:
            teamsList
        }
    }

    @ViewBuilder
    private func matchList(_ matches: [Match], emptyText: String) -> some View {
        if matches.isEmpty {
            Text(emptyText)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textFaint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
        } else {
            VStack(spacing: 9) {
                ForEach(matches) { match in
                    MatchRow(match: match)
                }
            }
        }
    }

    @ViewBuilder
    private var teamsList: some View {
        let sorted = tournament.teams.sorted { ($0.wins - $0.losses) > ($1.wins - $1.losses) }
        let maxGames = max(sorted.map { $0.wins + $0.losses }.max() ?? 1, 1)

        VStack(spacing: 0) {
            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, team in
                HStack(spacing: 12) {
                    Text(team.name)
                        .font(.system(size: 14.5, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ProgressBar(fraction: Double(team.wins) / Double(maxGames))
                        .frame(width: 90)
                    Text("\(team.wins)-\(team.losses)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 44, alignment: .trailing)
                }
                .padding(.vertical, 11)

                if index < sorted.count - 1 {
                    Divider().overlay(Theme.border)
                }
            }
        }
        .card()
    }
}

struct MatchRow: View {
    let match: Match

    var body: some View {
        VStack(spacing: 7) {
            Text(match.format)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(Theme.textFaint)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(match.teamA.shortName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(teamAColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                scoreView

                Text(match.teamB.shortName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(teamBColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Text(whenText)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 15)
    }

    @ViewBuilder
    private var scoreView: some View {
        if match.isFinished, let a = match.scoreA, let b = match.scoreB {
            Text("\(a) : \(b)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
        } else {
            Text("vs")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textFaint)
        }
    }

    private var teamAColor: Color {
        guard match.isFinished, let a = match.scoreA, let b = match.scoreB else { return .primary }
        return a > b ? Theme.accent : .primary
    }

    private var teamBColor: Color {
        guard match.isFinished, let a = match.scoreA, let b = match.scoreB else { return .primary }
        return b > a ? Theme.accent : .primary
    }

    private var whenText: String {
        match.isFinished
            ? DateFormatting.mediumRu.string(from: match.scheduledAt)
            : DateFormatting.dayMonthTimeRu.string(from: match.scheduledAt)
    }
}
