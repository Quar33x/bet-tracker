import Foundation
import SwiftData

/// Стартовые данные из `BET_STATS_05_09.xlsx` (перенесены через
/// `bet_tracker_mockup.html`) — 20 ставок за 4-5 сентября 2026, банк со
/// стартовым депозитом и одним выводом, четыре турнира тир-1 сцены.
enum SeedData {

    @MainActor
    static func populateIfNeeded(context: ModelContext) {
        let existingCount = (try? context.fetchCount(FetchDescriptor<Bet>())) ?? 0
        guard existingCount == 0 else { return }

        // MARK: Tournaments + teams

        let vctPacific = Tournament(
            name: "VCT PACIFIC", discipline: .valorant, stage: "Group Stage",
            startDate: date(20, 8), endDate: date(20, 9)
        )
        let ge = Team(name: "GE", shortName: "GE", wins: 2, losses: 0, tournament: vctPacific)
        let t1 = Team(name: "T1", shortName: "T1", wins: 1, losses: 1, tournament: vctPacific)
        let varrel = Team(name: "VARREL", shortName: "VARREL", wins: 0, losses: 1, tournament: vctPacific)
        let ns = Team(name: "NS", shortName: "NS", wins: 0, losses: 1, tournament: vctPacific)
        let drx = Team(name: "DRX", shortName: "DRX", tournament: vctPacific)
        let prx = Team(name: "PRX", shortName: "PRX", tournament: vctPacific)
        let pacificTeams = [ge, t1, varrel, ns, drx, prx]
        let pacificMatches = [
            Match(tournament: vctPacific, teamA: ge, teamB: drx, format: "BO3", scheduledAt: dt(6, 18, 0)),
            Match(tournament: vctPacific, teamA: t1, teamB: prx, format: "BO3", scheduledAt: dt(7, 15, 0)),
            Match(tournament: vctPacific, teamA: ns, teamB: ge, format: "BO3", scheduledAt: dt(4, 0, 0), scoreA: 0, scoreB: 2, isFinished: true),
            Match(tournament: vctPacific, teamA: t1, teamB: varrel, format: "BO3", scheduledAt: dt(4, 0, 0), scoreA: 2, scoreB: 0, isFinished: true),
            Match(tournament: vctPacific, teamA: ge, teamB: t1, format: "BO5", scheduledAt: dt(4, 0, 0), scoreA: 3, scoreB: 2, isFinished: true),
        ]

        let vctAmericas = Tournament(
            name: "VCT AMERICAS", discipline: .valorant, stage: "Group Stage",
            startDate: date(20, 8), endDate: date(20, 9)
        )
        let loud = Team(name: "LOUD", shortName: "LOUD", wins: 2, losses: 0, tournament: vctAmericas)
        let team100t = Team(name: "100T", shortName: "100T", wins: 2, losses: 0, tournament: vctAmericas)
        let g2val = Team(name: "G2", shortName: "G2", wins: 0, losses: 2, tournament: vctAmericas)
        let nrg = Team(name: "NRG", shortName: "NRG", wins: 0, losses: 2, tournament: vctAmericas)
        let mibr = Team(name: "MIBR", shortName: "MIBR", tournament: vctAmericas)
        let kru = Team(name: "KRÜ", shortName: "KRÜ", tournament: vctAmericas)
        let americasTeams = [loud, team100t, g2val, nrg, mibr, kru]
        let americasMatches = [
            Match(tournament: vctAmericas, teamA: loud, teamB: team100t, format: "BO3", scheduledAt: dt(8, 20, 0)),
            Match(tournament: vctAmericas, teamA: nrg, teamB: g2val, format: "BO3", scheduledAt: dt(9, 17, 0)),
            Match(tournament: vctAmericas, teamA: team100t, teamB: nrg, format: "BO3", scheduledAt: dt(4, 0, 0), scoreA: 2, scoreB: 0, isFinished: true),
            Match(tournament: vctAmericas, teamA: loud, teamB: g2val, format: "BO3", scheduledAt: dt(4, 0, 0), scoreA: 2, scoreB: 0, isFinished: true),
        ]

        let blastPorto = Tournament(
            name: "BLAST OPEN PORTO 2026", discipline: .cs2, stage: "Playoffs",
            startDate: date(1, 9), endDate: date(12, 9)
        )
        let flc = Team(name: "FLC", shortName: "FLC", wins: 1, losses: 0, tournament: blastPorto)
        let vit = Team(name: "VIT", shortName: "VIT", wins: 1, losses: 0, tournament: blastPorto)
        let g2cs = Team(name: "G2", shortName: "G2", wins: 0, losses: 1, tournament: blastPorto)
        let fur = Team(name: "FUR", shortName: "FUR", wins: 0, losses: 1, tournament: blastPorto)
        let navi = Team(name: "NAVI", shortName: "NAVI", tournament: blastPorto)
        let mouz = Team(name: "MOUZ", shortName: "MOUZ", tournament: blastPorto)
        let portoTeams = [flc, vit, g2cs, fur, navi, mouz]
        let portoMatches = [
            Match(tournament: blastPorto, teamA: g2cs, teamB: vit, format: "BO3", scheduledAt: dt(7, 16, 0)),
            Match(tournament: blastPorto, teamA: flc, teamB: fur, format: "BO3", scheduledAt: dt(9, 19, 0)),
            Match(tournament: blastPorto, teamA: flc, teamB: g2cs, format: "BO3", scheduledAt: dt(4, 0, 0), scoreA: 2, scoreB: 0, isFinished: true),
            Match(tournament: blastPorto, teamA: fur, teamB: vit, format: "BO3", scheduledAt: dt(4, 0, 0), scoreA: 1, scoreB: 2, isFinished: true),
        ]

        let pglWallachia = Tournament(
            name: "PGL WALLACHIA SEASON 5", discipline: .dota2, stage: "Group Stage",
            startDate: date(3, 9), endDate: date(15, 9)
        )
        let spirit = Team(name: "Team Spirit", shortName: "Spirit", tournament: pglWallachia)
        let gaimin = Team(name: "Gaimin Gladiators", shortName: "Gaimin", tournament: pglWallachia)
        let tundra = Team(name: "Tundra Esports", shortName: "Tundra", tournament: pglWallachia)
        let liquid = Team(name: "Team Liquid", shortName: "Liquid", tournament: pglWallachia)
        let xtreme = Team(name: "Xtreme Gaming", shortName: "Xtreme", tournament: pglWallachia)
        let betboom = Team(name: "BetBoom", shortName: "BetBoom", tournament: pglWallachia)
        let wallachiaTeams = [spirit, gaimin, tundra, liquid, xtreme, betboom]
        let wallachiaMatches = [
            Match(tournament: pglWallachia, teamA: spirit, teamB: tundra, format: "BO2", scheduledAt: dt(6, 14, 0)),
            Match(tournament: pglWallachia, teamA: gaimin, teamB: liquid, format: "BO2", scheduledAt: dt(7, 14, 0)),
        ]

        for tournament in [vctPacific, vctAmericas, blastPorto, pglWallachia] {
            context.insert(tournament)
        }
        for team in pacificTeams + americasTeams + portoTeams + wallachiaTeams {
            context.insert(team)
        }
        for match in pacificMatches + americasMatches + portoMatches + wallachiaMatches {
            context.insert(match)
        }

        // MARK: Bets

        func bet(
            _ discipline: Discipline, _ title: String, _ day: Int, _ amount: String, _ odds: String,
            _ status: BetStatus, _ tournament: Tournament? = nil
        ) -> Bet {
            Bet(
                date: date(day, 9), discipline: discipline, title: title,
                amount: Decimal(string: amount)!, odds: Decimal(string: odds)!,
                status: status, tournament: tournament
            )
        }

        let bets: [Bet] = [
            bet(.valorant, "NS -3,5 GE map1", 4, "450", "1.70", .win, vctPacific),
            bet(.valorant, "T1 -3,5 VARREL map1", 4, "500", "2.25", .win, vctPacific),
            bet(.valorant, "T1 -3,5 VARREL map2", 4, "640", "1.92", .win, vctPacific),
            bet(.cs2, "FLC -3,5 G2 map1", 4, "650", "2.60", .win, blastPorto),
            bet(.f1, "LECLERC TOP1 PRACTICE 2 ITALY GP", 4, "750", "2.25", .lose),
            bet(.cs2, "FLC -3,5 G2 map2", 4, "600", "2.05", .win, blastPorto),
            bet(.cs2, "FUR -3,5 VIT map1", 4, "530", "3.80", .win, blastPorto),
            bet(.valorant, "100T -3,5 NRG map1", 4, "629", "3.10", .win, vctAmericas),
            bet(.valorant, "100T -3,5 NRG map2 (долив)", 4, "1000", "2.48", .win, vctAmericas),
            bet(.cs2, "FUR -3,5 VIT map2", 4, "700", "3.10", .lose, blastPorto),
            bet(.other, "FUR>VIT + LOUD>G2 (экспресс CS2+VALORANT)", 4, "600", "5.52", .lose),
            bet(.cs2, "FUR -3,5 VIT map3", 4, "500", "3.60", .lose, blastPorto),
            bet(.cs2, "FUR -3,5 VIT map3", 4, "850", "3.80", .lose, blastPorto),
            bet(.valorant, "LOUD -3,5 G2 map1 (долив)", 4, "1344", "3.40", .win, vctAmericas),
            bet(.valorant, "LOUD 2:0 G2 (фора -1,5 по картам)", 4, "750", "5.00", .win, vctAmericas),
            bet(.valorant, "LOUD -3,5 G2 map2 (долив)", 4, "1900", "3.21", .win, vctAmericas),
            bet(.f1, "LECLERC 1-2 Gran-prix Italy", 4, "590", "1.90", .pending),
            bet(.valorant, "GE -3,5 map4", 5, "850", "4.00", .lose, vctPacific),
            bet(.valorant, "GE wins T1 bo5", 5, "1419", "2.30", .win, vctPacific),
            bet(.valorant, "GE wins T1 map4 (долив)", 5, "1650", "2.31", .win, vctPacific),
        ]
        for b in bets { context.insert(b) }

        // MARK: Bank

        let deposit = BankTransaction(date: date(4, 9), kind: .deposit, amount: 1500, note: "Стартовый депозит")
        let withdrawal = BankTransaction(date: date(5, 9), kind: .withdrawal, amount: 10000, note: "Вывод средств")
        context.insert(deposit)
        context.insert(withdrawal)
    }

    private static func date(_ day: Int, _ month: Int, _ year: Int = 2026) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        return Calendar.current.date(from: c) ?? Date()
    }

    private static func dt(_ day: Int, _ hour: Int, _ minute: Int, month: Int = 9, year: Int = 2026) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c) ?? Date()
    }
}
