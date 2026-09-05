import SwiftUI
import SwiftData

struct BankView: View {
    @Environment(\.modelContext) private var context
    @Query private var bets: [Bet]
    @Query(sort: \BankTransaction.date, order: .reverse) private var transactions: [BankTransaction]

    @State private var isAddingTransaction = false

    private var balance: Decimal { StatsCalculator.balance(bets: bets, transactions: transactions) }

    private let stakeHints: [Int: String] = [
        1: "Тест / сомнительная линия",
        2: "Обычная ставка (рекомендуется)",
        3: "Уверенная ставка",
        5: "Максимум (только при очень высоком edge)",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    balanceHero
                    history
                    stakes
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .navigationTitle("Банк")
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingTransaction = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingTransaction) {
            BankTransactionFormView()
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("Депозиты")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textDim)
                    Text(MoneyFormatter.string(StatsCalculator.totalDeposits(transactions)))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Сумма выводов")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textDim)
                    Text(MoneyFormatter.string(StatsCalculator.totalWithdrawals(transactions)))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Theme.surface2, Theme.surface],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .padding(.top, 8)
    }

    @ViewBuilder
    private var history: some View {
        Text("История")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.textDim)

        if transactions.isEmpty {
            Text("Пока нет движений по банку")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
        } else {
            VStack(spacing: 0) {
                ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(transaction.kind.label)
                                .font(.system(size: 14, weight: .semibold))
                            Text(dateNote(transaction))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textDim)
                        }
                        Spacer()
                        Text(signedAmount(transaction))
                            .font(.system(size: 14.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(transaction.kind == .deposit ? BetStatus.win.color : BetStatus.lose.color)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("Удалить", systemImage: "trash", role: .destructive) {
                            context.delete(transaction)
                        }
                    }

                    if index < transactions.count - 1 {
                        Divider().overlay(Theme.border)
                    }
                }
            }
            .card()
        }
    }

    @ViewBuilder
    private var stakes: some View {
        Text("Рекомендуемые ставки от баланса")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.textDim)

        let recommended = StatsCalculator.recommendedStakes(balance: balance)
        VStack(spacing: 0) {
            ForEach(Array(recommended.enumerated()), id: \.element.id) { index, stake in
                HStack(spacing: 12) {
                    Text("\(stake.percent)%")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 46, alignment: .leading)
                    Text(stakeHints[stake.percent] ?? "")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(MoneyFormatter.string(stake.amount))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .padding(.vertical, 12)

                if index < recommended.count - 1 {
                    Divider().overlay(Theme.border)
                }
            }
        }
        .card()
    }

    private func dateNote(_ transaction: BankTransaction) -> String {
        let date = DateFormatting.mediumRu.string(from: transaction.date)
        guard let note = transaction.note, !note.isEmpty else { return date }
        return "\(date) · \(note)"
    }

    private func signedAmount(_ transaction: BankTransaction) -> String {
        let sign = transaction.kind == .deposit ? "+" : "−"
        return sign + MoneyFormatter.string(transaction.amount)
    }
}
