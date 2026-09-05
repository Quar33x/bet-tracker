import SwiftUI

enum Theme {
    static let background = Color(red: 0.039, green: 0.051, blue: 0.071)
    static let surface = Color(red: 0.071, green: 0.086, blue: 0.114)
    static let surface2 = Color(red: 0.102, green: 0.125, blue: 0.161)
    static let border = Color(red: 0.141, green: 0.173, blue: 0.220)
    static let accent = Color(red: 0.306, green: 0.847, blue: 0.769)
    static let textDim = Color(red: 0.533, green: 0.573, blue: 0.639)
    static let textFaint = Color(red: 0.361, green: 0.396, blue: 0.467)

    static func profitColor(_ value: Decimal) -> Color {
        if value > 0 { return BetStatus.win.color }
        if value < 0 { return BetStatus.lose.color }
        return textDim
    }
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 14) -> some View {
        modifier(CardBackground(padding: padding))
    }

    func screenBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.background)
    }
}

struct StatusPill: View {
    let status: BetStatus

    var body: some View {
        Text(status.label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct StatCard: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Theme.textDim)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surface2)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: 5)
    }
}
