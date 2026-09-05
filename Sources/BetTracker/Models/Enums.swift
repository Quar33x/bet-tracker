import SwiftUI

enum Discipline: String, Codable, CaseIterable, Identifiable {
    case valorant, cs2, dota2, f1, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .valorant: return "VALORANT"
        case .cs2: return "CS2"
        case .dota2: return "DOTA 2"
        case .f1: return "F1"
        case .other: return "Другое"
        }
    }

    var accentColor: Color {
        switch self {
        case .valorant: return Color(red: 1.0, green: 0.42, blue: 0.46)
        case .cs2: return Color(red: 0.94, green: 0.73, blue: 0.30)
        case .dota2: return Color(red: 0.78, green: 0.49, blue: 0.96)
        case .f1: return .orange
        case .other: return .secondary
        }
    }
}

enum BetStatus: String, Codable, CaseIterable, Identifiable {
    case pending, win, lose

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending: return "PENDING"
        case .win: return "WIN"
        case .lose: return "LOSE"
        }
    }

    var color: Color {
        switch self {
        case .pending: return Color(red: 0.94, green: 0.73, blue: 0.30)
        case .win: return Color(red: 0.24, green: 0.84, blue: 0.60)
        case .lose: return Color(red: 1.0, green: 0.36, blue: 0.45)
        }
    }
}

enum TransactionKind: String, Codable, CaseIterable, Identifiable {
    case deposit, withdrawal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .deposit: return "Депозит"
        case .withdrawal: return "Вывод"
        }
    }
}
