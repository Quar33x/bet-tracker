import SwiftUI
import SwiftData

struct TournamentsListView: View {
    @Query(sort: \Tournament.name) private var tournaments: [Tournament]
    @Query private var bets: [Bet]

    private let groupOrder: [Discipline] = [.valorant, .cs2, .dota2, .f1, .other]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(groupOrder) { discipline in
                        let group = tournaments.filter { $0.discipline == discipline }
                        if !group.isEmpty {
                            Text(discipline.displayName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.textDim)
                                .padding(.top, 12)

                            ForEach(group) { tournament in
                                NavigationLink(value: tournament) {
                                    TournamentCard(
                                        tournament: tournament,
                                        stats: StatsCalculator.stats(for: tournament, in: bets)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
            }
            .background(Theme.background)
            .navigationTitle("Турниры")
            .toolbarBackground(Theme.background, for: .navigationBar)
            .navigationDestination(for: Tournament.self) { tournament in
                TournamentDetailView(tournament: tournament)
            }
        }
    }
}

struct TournamentCard: View {
    let tournament: Tournament
    let stats: StatsCalculator.TournamentStats

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tournament.discipline.displayName)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(tournament.discipline.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tournament.discipline.accentColor.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(tournament.name)
                .font(.system(size: 15.5, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.top, 8)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textDim)

            Divider().overlay(Theme.border).padding(.vertical, 10)

            HStack(alignment: .top) {
                if stats.hasBets {
                    labeled("Твои ставки", "\(stats.count) · винрейт \(PercentFormatter.string(stats.winRate, digits: 0))")
                    Spacer()
                    labeled("Профит", MoneyFormatter.signed(stats.netProfit), color: Theme.profitColor(stats.netProfit))
                } else {
                    Text("Ставок пока нет")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textFaint)
                    Spacer()
                    labeled("Матчей", "\(tournament.matches.count)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }

    private var subtitle: String {
        let dates = [tournament.startDate, tournament.endDate]
            .compactMap { $0.map { DateFormatting.mediumRu.string(from: $0) } }
            .joined(separator: " — ")
        return [tournament.stage, dates.isEmpty ? nil : dates]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func labeled(_ label: String, _ value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textFaint)
            Text(value)
                .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}
