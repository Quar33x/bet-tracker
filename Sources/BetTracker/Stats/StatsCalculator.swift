import Foundation

/// Все расчёты ставок и банка. Ничего здесь не хранится в базе — только
/// вычисляемые функции над выборками `Bet` / `BankTransaction`, чтобы при
/// редактировании ставки цифры не расходились с фактическими данными.
enum StatsCalculator {

    /// Эвристика из исходной таблицы, а не проверенная формула.
    static let minComfortOddsMultiplier: Decimal = Decimal(string: "0.92")!

    // MARK: - Per-bet

    static func profit(for bet: Bet) -> Decimal {
        switch bet.status {
        case .win: return bet.amount * (bet.odds - 1)
        case .lose: return -bet.amount
        case .pending: return 0
        }
    }

    static func roi(for bet: Bet) -> Decimal {
        guard bet.amount != 0 else { return 0 }
        return profit(for: bet) / bet.amount
    }

    // MARK: - Aggregates over bets

    static func settled(_ bets: [Bet]) -> [Bet] {
        bets.filter { $0.status != .pending }
    }

    static func wins(_ bets: [Bet]) -> [Bet] {
        bets.filter { $0.status == .win }
    }

    static func turnover(_ bets: [Bet]) -> Decimal {
        bets.reduce(0) { $0 + $1.amount }
    }

    static func netProfit(_ bets: [Bet]) -> Decimal {
        bets.reduce(0) { $0 + profit(for: $1) }
    }

    static func winRate(_ bets: [Bet]) -> Double {
        let settledBets = settled(bets)
        guard !settledBets.isEmpty else { return 0 }
        return Double(wins(settledBets).count) / Double(settledBets.count)
    }

    static func overallROI(_ bets: [Bet]) -> Decimal {
        let t = turnover(bets)
        guard t != 0 else { return 0 }
        return netProfit(bets) / t
    }

    static func averageOdds(_ bets: [Bet]) -> Decimal {
        guard !bets.isEmpty else { return 0 }
        return bets.reduce(0) { $0 + $1.odds } / Decimal(bets.count)
    }

    static func averageAmount(_ bets: [Bet]) -> Decimal {
        guard !bets.isEmpty else { return 0 }
        return bets.reduce(0) { $0 + $1.amount } / Decimal(bets.count)
    }

    static func optimalOdds(_ bets: [Bet]) -> Decimal {
        let winning = wins(bets)
        guard !winning.isEmpty else { return 0 }
        return winning.reduce(0) { $0 + $1.odds } / Decimal(winning.count)
    }

    static func minComfortOdds(_ bets: [Bet]) -> Decimal {
        optimalOdds(bets) * minComfortOddsMultiplier
    }

    // MARK: - Bank

    static func totalDeposits(_ transactions: [BankTransaction]) -> Decimal {
        transactions.filter { $0.kind == .deposit }.reduce(0) { $0 + $1.amount }
    }

    static func totalWithdrawals(_ transactions: [BankTransaction]) -> Decimal {
        transactions.filter { $0.kind == .withdrawal }.reduce(0) { $0 + $1.amount }
    }

    static func balance(bets: [Bet], transactions: [BankTransaction]) -> Decimal {
        totalDeposits(transactions) - totalWithdrawals(transactions) + netProfit(bets)
    }

    struct RecommendedStake: Identifiable {
        let percent: Int
        let amount: Decimal

        var id: Int { percent }
    }

    static func recommendedStakes(balance: Decimal) -> [RecommendedStake] {
        [1, 2, 3, 5].map { percent in
            RecommendedStake(percent: percent, amount: balance * Decimal(percent) / 100)
        }
    }

    // MARK: - By discipline

    struct DisciplineBreakdown: Identifiable {
        let discipline: Discipline
        let count: Int
        let winCount: Int
        let settledCount: Int
        let profit: Decimal

        var id: String { discipline.rawValue }

        var winRate: Double {
            guard settledCount > 0 else { return 0 }
            return Double(winCount) / Double(settledCount)
        }
    }

    static func byDiscipline(_ bets: [Bet]) -> [DisciplineBreakdown] {
        let grouped = Dictionary(grouping: bets, by: \.discipline)
        return grouped.map { discipline, bets in
            let settledBets = settled(bets)
            return DisciplineBreakdown(
                discipline: discipline,
                count: bets.count,
                winCount: wins(settledBets).count,
                settledCount: settledBets.count,
                profit: netProfit(bets)
            )
        }.sorted { $0.count > $1.count }
    }

    // MARK: - By tournament

    struct TournamentStats {
        let count: Int
        let netProfit: Decimal
        let winRate: Double
        let roi: Decimal

        var hasBets: Bool { count > 0 }

        static let empty = TournamentStats(count: 0, netProfit: 0, winRate: 0, roi: 0)
    }

    static func stats(for tournament: Tournament, in bets: [Bet]) -> TournamentStats {
        let list = bets.filter { $0.tournament?.id == tournament.id }
        guard !list.isEmpty else { return .empty }
        return TournamentStats(
            count: list.count,
            netProfit: netProfit(list),
            winRate: winRate(list),
            roi: overallROI(list)
        )
    }
}
