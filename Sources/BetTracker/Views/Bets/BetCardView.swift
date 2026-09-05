import SwiftUI

struct BetCardView: View {
    let bet: Bet

    private var profit: Decimal { StatsCalculator.profit(for: bet) }
    private var roi: Double { NSDecimalNumber(decimal: StatsCalculator.roi(for: bet)).doubleValue }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    Text(bet.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(DateFormatting.shortRu.string(from: bet.date))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textDim)
                }
                Spacer(minLength: 0)
                StatusPill(status: bet.status)
                if bet.tournament != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textFaint)
                }
            }

            Divider().overlay(Theme.border)

            HStack {
                metric(label: "Сумма", value: MoneyFormatter.string(bet.amount))
                Spacer()
                metric(label: "Кэф", value: oddsText)
                Spacer()
                HStack(spacing: 4) {
                    Text(MoneyFormatter.signed(profit))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Theme.profitColor(profit))
                    Text("(\(PercentFormatter.signed(roi, digits: 0)))")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }

    private var headline: String {
        if let tournament = bet.tournament {
            return "\(bet.discipline.displayName) · \(tournament.name)"
        }
        return bet.discipline.displayName
    }

    private var oddsText: String {
        String(format: "%.2f", NSDecimalNumber(decimal: bet.odds).doubleValue)
    }

    private func metric(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
            Text(value)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }
}
