import Foundation

enum MoneyFormatter {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "ru_RU")
        f.currencySymbol = "₽"
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        return f
    }()

    static func string(_ amount: Decimal) -> String {
        formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) ₽"
    }

    static func signed(_ amount: Decimal) -> String {
        amount > 0 ? "+\(string(amount))" : string(amount)
    }
}

enum PercentFormatter {
    static func string(_ value: Double, digits: Int = 1) -> String {
        String(format: "%.\(digits)f%%", value * 100)
    }

    static func signed(_ value: Double, digits: Int = 1) -> String {
        value > 0 ? "+\(string(value, digits: digits))" : string(value, digits: digits)
    }
}

enum DateFormatting {
    static let shortRu: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "dd.MM"
        return f
    }()

    static let mediumRu: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    static let dayMonthTimeRu: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()
}
