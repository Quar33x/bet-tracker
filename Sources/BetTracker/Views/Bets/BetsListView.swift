import SwiftUI
import SwiftData

struct BetsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Bet.date, order: .reverse) private var bets: [Bet]

    @State private var filter: BetStatus?
    @State private var isAddingBet = false
    @State private var editingBet: Bet?

    private var visibleBets: [Bet] {
        guard let filter else { return bets }
        return bets.filter { $0.status == filter }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterChips
                betsList
            }
            .background(Theme.background)
            .navigationTitle("Ставки")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .navigationDestination(for: Tournament.self) { tournament in
                TournamentDetailView(tournament: tournament)
            }
            .overlay(alignment: .bottomTrailing) {
                addButton
            }
        }
        .sheet(isPresented: $isAddingBet) {
            BetFormView(bet: nil)
        }
        .sheet(item: $editingBet) { bet in
            BetFormView(bet: bet)
        }
    }

    private var subtitle: String {
        let winRate = StatsCalculator.winRate(bets)
        let profit = StatsCalculator.netProfit(bets)
        return "\(bets.count) ставок · винрейт \(PercentFormatter.string(winRate, digits: 0)) · профит \(MoneyFormatter.signed(profit))"
    }

    private var filterChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textDim)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(title: "Все", value: nil)
                    ForEach(BetStatus.allCases) { status in
                        chip(title: status.label, value: status)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
    }

    private func chip(title: String, value: BetStatus?) -> some View {
        let isActive = filter == value
        return Button {
            filter = value
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(isActive ? Theme.background : Theme.textDim)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isActive ? Theme.accent : Theme.surface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(isActive ? Theme.accent : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var betsList: some View {
        if visibleBets.isEmpty {
            ContentUnavailableView {
                Label("Пока ничего нет", systemImage: "tray")
            } description: {
                Text("Нажми «+», чтобы добавить ставку")
            }
            .frame(maxHeight: .infinity)
            .background(Theme.background)
        } else {
            List {
                ForEach(visibleBets) { bet in
                    row(for: bet)
                        .listRowInsets(EdgeInsets(top: 5, leading: 18, bottom: 5, trailing: 18))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            statusButton(.win, for: bet)
                            statusButton(.lose, for: bet)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                context.delete(bet)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                            statusButton(.pending, for: bet)
                        }
                        .contextMenu {
                            Button("Редактировать", systemImage: "pencil") { editingBet = bet }
                            ForEach(BetStatus.allCases) { status in
                                Button(status.label) { bet.status = status }
                            }
                        }
                }
            }
            .listStyle(.plain)
            .screenBackground()
        }
    }

    @ViewBuilder
    private func row(for bet: Bet) -> some View {
        if let tournament = bet.tournament {
            NavigationLink(value: tournament) {
                BetCardView(bet: bet)
            }
            .buttonStyle(.plain)
        } else {
            BetCardView(bet: bet)
        }
    }

    private func statusButton(_ status: BetStatus, for bet: Bet) -> some View {
        Button {
            bet.status = status
        } label: {
            Text(status.label)
        }
        .tint(status.color)
    }

    private var addButton: some View {
        Button {
            isAddingBet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Theme.background)
                .frame(width: 56, height: 56)
                .background(Theme.accent)
                .clipShape(Circle())
                .shadow(color: Theme.accent.opacity(0.35), radius: 12, y: 6)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
}
