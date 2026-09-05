import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var bets: [Bet]
    @Query private var transactions: [BankTransaction]

    private var balance: Decimal { StatsCalculator.balance(bets: bets, transactions: transactions) }
    private var netProfit: Decimal { StatsCalculator.netProfit(bets) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    balanceHero
                    statsGrid
                    effectiveOdds
                    disciplineBreakdown
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Дашборд")
            .toolbarBackground(Theme.background, for: .navigationBar)
        }
    }

    private var balanceHero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Текущий баланс")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textDim)
            Text(MoneyFormatter.string(balance))
                .font(.system(size: 38, weight: .bold, design: .monospaced))

            HStack(spacing: 22) {
                heroMetric("Профит", MoneyFormatter.signed(netProfit), color: Theme.profitColor(netProfit))
                heroMetric("Депозит", MoneyFormatter.string(StatsCalculator.totalDeposits(transactions)))
                heroMetric("Выводы", MoneyFormatter.string(StatsCalculator.totalWithdrawals(transactions)))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 0.086, green: 0.188, blue: 0.173), Theme.surface],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(red: 0.118, green: 0.290, blue: 0.259), lineWidth: 1)
        )
        .padding(.top, 8)
    }

    private func heroMetric(_ label: String, _ value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textDim)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatCard(label: "Винрейт", value: PercentFormatter.string(StatsCalculator.winRate(bets)))
            StatCard(
                label: "ROI (общий)",
                value: PercentFormatter.signed(NSDecimalNumber(decimal: StatsCalculator.overallROI(bets)).doubleValue)
            )
            StatCard(label: "Ставок / завершено", value: "\(StatsCalculator.settled(bets).count) / \(bets.count)")
            StatCard(label: "Оборот", value: MoneyFormatter.string(StatsCalculator.turnover(bets)))
            StatCard(label: "Средний кэф", value: decimalText(StatsCalculator.averageOdds(bets)))
            StatCard(label: "Средняя сумма", value: MoneyFormatter.string(StatsCalculator.averageAmount(bets)))
        }
    }

    private var effectiveOdds: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Эффективные коэффициенты")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Theme.textDim)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Оптимальный кэф")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textFaint)
                    Text(decimalText(StatsCalculator.optimalOdds(bets)))
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Мин. комфортный")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textFaint)
                    Text(decimalText(StatsCalculator.minComfortOdds(bets)))
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                }
            }

            Text("Ниже минимального комфортного кэфа заходить менее выгодно — цельтесь в зону оптимального и выше.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var disciplineBreakdown: some View {
        let breakdown = StatsCalculator.byDiscipline(bets)
        let maxCount = max(breakdown.map(\.count).max() ?? 1, 1)

        Text("По дисциплинам")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.textDim)

        VStack(spacing: 0) {
            ForEach(Array(breakdown.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.discipline.displayName)
                            .font(.system(size: 14, weight: .semibold))
                        Text("\(item.count) ставок · винрейт \(PercentFormatter.string(item.winRate, digits: 0))")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textDim)
                        ProgressBar(fraction: Double(item.count) / Double(maxCount))
                    }
                    Text(MoneyFormatter.signed(item.profit))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.profitColor(item.profit))
                }
                .padding(.vertical, 11)

                if index < breakdown.count - 1 {
                    Divider().overlay(Theme.border)
                }
            }
        }
        .card()
    }

    private func decimalText(_ value: Decimal) -> String {
        String(format: "%.2f", NSDecimalNumber(decimal: value).doubleValue)
    }
}
