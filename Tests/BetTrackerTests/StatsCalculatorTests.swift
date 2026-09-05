import XCTest
@testable import BetTracker

final class StatsCalculatorTests: XCTestCase {

    private func makeBet(
        _ amount: String,
        _ odds: String,
        _ status: BetStatus,
        discipline: Discipline = .valorant,
        tournament: Tournament? = nil
    ) -> Bet {
        Bet(
            date: Date(),
            discipline: discipline,
            title: "test",
            amount: Decimal(string: amount)!,
            odds: Decimal(string: odds)!,
            status: status,
            tournament: tournament
        )
    }

    // MARK: - Per-bet

    func testProfitForWin() {
        let bet = makeBet("500", "2.25", .win)
        XCTAssertEqual(StatsCalculator.profit(for: bet), Decimal(string: "625")!)
    }

    func testProfitForLose() {
        let bet = makeBet("750", "2.25", .lose)
        XCTAssertEqual(StatsCalculator.profit(for: bet), Decimal(-750))
    }

    func testProfitForPendingIsZero() {
        let bet = makeBet("590", "1.90", .pending)
        XCTAssertEqual(StatsCalculator.profit(for: bet), 0)
    }

    func testROIForWinIsOddsMinusOne() {
        let bet = makeBet("450", "1.70", .win)
        XCTAssertEqual(StatsCalculator.roi(for: bet), Decimal(string: "0.7")!)
    }

    func testROIForLoseIsMinusOne() {
        let bet = makeBet("450", "1.70", .lose)
        XCTAssertEqual(StatsCalculator.roi(for: bet), Decimal(-1))
    }

    func testROIWithZeroAmountIsZero() {
        let bet = makeBet("0", "2.00", .win)
        XCTAssertEqual(StatsCalculator.roi(for: bet), 0)
    }

    // MARK: - Aggregates

    func testTurnoverSumsAllBetsIncludingPending() {
        let bets = [makeBet("500", "2.00", .win), makeBet("300", "1.50", .lose), makeBet("200", "3.00", .pending)]
        XCTAssertEqual(StatsCalculator.turnover(bets), Decimal(1000))
    }

    func testNetProfitAcrossMixedStatuses() {
        let bets = [makeBet("500", "2.00", .win), makeBet("300", "1.50", .lose), makeBet("200", "3.00", .pending)]
        XCTAssertEqual(StatsCalculator.netProfit(bets), Decimal(200))
    }

    func testSettledExcludesPending() {
        let bets = [makeBet("500", "2.00", .win), makeBet("300", "1.50", .lose), makeBet("200", "3.00", .pending)]
        XCTAssertEqual(StatsCalculator.settled(bets).count, 2)
    }

    func testWinRateIgnoresPendingBets() {
        let bets = [
            makeBet("100", "2.00", .win),
            makeBet("100", "2.00", .win),
            makeBet("100", "2.00", .lose),
            makeBet("100", "2.00", .pending),
        ]
        XCTAssertEqual(StatsCalculator.winRate(bets), 2.0 / 3.0, accuracy: 0.0001)
    }

    func testWinRateWithNoSettledBetsIsZero() {
        XCTAssertEqual(StatsCalculator.winRate([makeBet("100", "2.00", .pending)]), 0)
    }

    func testOverallROIUsesFullTurnover() {
        let bets = [makeBet("500", "2.00", .win), makeBet("500", "2.00", .lose)]
        XCTAssertEqual(StatsCalculator.overallROI(bets), 0)
    }

    func testOverallROIWithEmptyListIsZero() {
        XCTAssertEqual(StatsCalculator.overallROI([]), 0)
    }

    func testAverageOddsAndAmount() {
        let bets = [makeBet("400", "2.00", .win), makeBet("600", "3.00", .lose)]
        XCTAssertEqual(StatsCalculator.averageOdds(bets), Decimal(string: "2.5")!)
        XCTAssertEqual(StatsCalculator.averageAmount(bets), Decimal(500))
    }

    // MARK: - Effective odds

    func testOptimalOddsUsesOnlyWinningBets() {
        let bets = [
            makeBet("100", "2.00", .win),
            makeBet("100", "4.00", .win),
            makeBet("100", "10.00", .lose),
            makeBet("100", "10.00", .pending),
        ]
        XCTAssertEqual(StatsCalculator.optimalOdds(bets), Decimal(3))
    }

    func testMinComfortOddsIsOptimalTimesMultiplier() {
        let bets = [makeBet("100", "2.00", .win), makeBet("100", "4.00", .win)]
        XCTAssertEqual(StatsCalculator.minComfortOdds(bets), Decimal(3) * StatsCalculator.minComfortOddsMultiplier)
    }

    func testOptimalOddsWithoutWinsIsZero() {
        XCTAssertEqual(StatsCalculator.optimalOdds([makeBet("100", "2.00", .lose)]), 0)
    }

    // MARK: - Bank

    func testBalanceCombinesTransactionsAndProfit() {
        let bets = [makeBet("500", "3.00", .win), makeBet("200", "2.00", .lose)]
        let transactions = [
            BankTransaction(date: Date(), kind: .deposit, amount: 1500),
            BankTransaction(date: Date(), kind: .withdrawal, amount: 500),
        ]
        // 1500 − 500 + (1000 − 200)
        XCTAssertEqual(StatsCalculator.balance(bets: bets, transactions: transactions), Decimal(1800))
    }

    func testRecommendedStakesArePercentagesOfBalance() {
        let stakes = StatsCalculator.recommendedStakes(balance: Decimal(10000))
        XCTAssertEqual(stakes.map(\.percent), [1, 2, 3, 5])
        XCTAssertEqual(stakes.map(\.amount), [100, 200, 300, 500].map { Decimal($0) })
    }

    // MARK: - Breakdowns

    func testByDisciplineAggregatesAndSortsByCount() {
        let bets = [
            makeBet("100", "2.00", .win, discipline: .valorant),
            makeBet("100", "2.00", .lose, discipline: .valorant),
            makeBet("100", "3.00", .pending, discipline: .valorant),
            makeBet("100", "2.00", .win, discipline: .cs2),
        ]
        let breakdown = StatsCalculator.byDiscipline(bets)

        XCTAssertEqual(breakdown.first?.discipline, .valorant)
        XCTAssertEqual(breakdown.first?.count, 3)
        XCTAssertEqual(breakdown.first?.settledCount, 2)
        XCTAssertEqual(breakdown.first?.winCount, 1)
        XCTAssertEqual(breakdown.first?.winRate, 0.5)
        XCTAssertEqual(breakdown.first?.profit, 0)
        XCTAssertEqual(breakdown.last?.discipline, .cs2)
    }

    func testTournamentStatsCountOnlyItsOwnBets() {
        let tournament = Tournament(name: "VCT PACIFIC", discipline: .valorant)
        let other = Tournament(name: "VCT AMERICAS", discipline: .valorant)
        let bets = [
            makeBet("500", "2.00", .win, tournament: tournament),
            makeBet("500", "2.00", .lose, tournament: tournament),
            makeBet("500", "5.00", .win, tournament: other),
            makeBet("500", "5.00", .win),
        ]

        let stats = StatsCalculator.stats(for: tournament, in: bets)
        XCTAssertEqual(stats.count, 2)
        XCTAssertEqual(stats.netProfit, 0)
        XCTAssertEqual(stats.winRate, 0.5)
        XCTAssertEqual(stats.roi, 0)
        XCTAssertTrue(stats.hasBets)
    }

    func testTournamentStatsWithoutBetsIsEmpty() {
        let tournament = Tournament(name: "PGL WALLACHIA SEASON 5", discipline: .dota2)
        let stats = StatsCalculator.stats(for: tournament, in: [makeBet("500", "2.00", .win)])
        XCTAssertFalse(stats.hasBets)
        XCTAssertEqual(stats.count, 0)
    }
}
