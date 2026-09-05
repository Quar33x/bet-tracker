import Foundation
import SwiftData

@Model
final class BankTransaction {
    var id: UUID
    var date: Date
    var kindRaw: String
    var amount: Decimal
    var note: String?

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .deposit }
        set { kindRaw = newValue.rawValue }
    }

    init(date: Date, kind: TransactionKind, amount: Decimal, note: String? = nil) {
        self.id = UUID()
        self.date = date
        self.kindRaw = kind.rawValue
        self.amount = amount
        self.note = note
    }
}
