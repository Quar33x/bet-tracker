import SwiftUI

/// Экран матча: предматчевый разбор для предстоящих, саммари для сыгранных.
struct MatchDetailView: View {
    let match: RemoteMatch

    @Environment(BackendSettings.self) private var settings

    @State private var preview: MatchPreview?
    @State private var summary: MatchSummary?
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if match.isFinished {
                    summarySection
                } else {
                    previewSection
                }

                AttributionFooter()
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle(match.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadExisting() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(match.tournamentName ?? "Без турнира")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.accent)

            Text(match.title)
                .font(.system(size: 22, weight: .bold))

            HStack(spacing: 10) {
                if let date = match.scheduledDate {
                    Text(DateFormatting.dayMonthTimeRu.string(from: date))
                }
                if let bestOf = match.bestOf { Text("BO\(bestOf)") }
                if let score = match.scoreLine { Text(score).foregroundStyle(Theme.accent) }
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Предматчевый разбор

    @ViewBuilder
    private var previewSection: some View {
        if let preview {
            PreviewCard(preview: preview)

            Button {
                Task { await generate(force: true) }
            } label: {
                Label("Пересчитать разбор", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .disabled(isWorking)

            Text("Пересчёт — это платный запрос к модели. Пока факты о командах не изменились, разбор берётся из кэша бесплатно.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textFaint)
        } else if isWorking {
            VStack(spacing: 10) {
                ProgressView().tint(Theme.accent)
                Text("Модель разбирает матч — это занимает до минуты.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Разбор ещё не запрашивался.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textDim)

                Button {
                    Task { await generate(force: false) }
                } label: {
                    Label("Разобрать матч", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
            .card()
        }

        if let error {
            ErrorNotice(message: error) { Task { await generate(force: false) } }
        }
    }

    // MARK: - Саммари

    @ViewBuilder
    private var summarySection: some View {
        if let summary {
            SummaryCard(summary: summary)
        } else if isWorking {
            ProgressView().tint(Theme.accent).frame(maxWidth: .infinity).padding(.vertical, 20)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Саммари ещё не готово")
                    .font(.system(size: 14, weight: .semibold))
                Text("Тексты по сыгранным матчам собираются пакетом раз в 20 минут — так они стоят вдвое дешевле. Загляни позже.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    // MARK: - Загрузка

    private func loadExisting() async {
        guard settings.isConfigured else { return }
        isWorking = true
        defer { isWorking = false }

        let client = BackendClient(settings: settings)
        if match.isFinished {
            summary = try? await client.summary(matchId: match.id)
        } else {
            // Тихо забираем кэш: платный вызов делается только по кнопке.
            preview = try? await client.preview(matchId: match.id)
        }
    }

    private func generate(force: Bool) async {
        isWorking = true
        error = nil
        defer { isWorking = false }

        do {
            preview = try await BackendClient(settings: settings).preview(matchId: match.id, force: force)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct PreviewCard: View {
    let preview: MatchPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Разбор")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Text(preview.analysis.confidenceLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(confidenceColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(confidenceColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(preview.analysis.verdict)
                .font(.system(size: 15))

            Section2(title: "За первую команду", items: preview.analysis.factorsA)
            Section2(title: "За вторую команду", items: preview.analysis.factorsB)

            VStack(alignment: .leading, spacing: 4) {
                Text("Про форы")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textDim)
                Text(preview.analysis.handicapNote)
                    .font(.system(size: 13))
            }

            if !preview.analysis.unknowns.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Чего модель не знает", systemImage: "questionmark.circle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(BetStatus.pending.color)
                    ForEach(preview.analysis.unknowns, id: \.self) { item in
                        Text("• \(item)")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textDim)
                    }
                }
                .padding(10)
                .background(BetStatus.pending.color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Section2(title: "На что посмотреть перед матчем", items: preview.analysis.watch)

            Divider().overlay(Theme.border)

            HStack {
                Text(preview.cached ? "Из кэша" : "Свежий расчёт")
                Spacer()
                if let cost = preview.costUsd, cost > 0 {
                    Text(String(format: "$%.3f", cost))
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.textFaint)
        }
        .card()
    }

    private var confidenceColor: Color {
        switch preview.analysis.confidence.lowercased() {
        case "high": return BetStatus.win.color
        case "low": return BetStatus.lose.color
        default: return BetStatus.pending.color
        }
    }
}

struct SummaryCard: View {
    let summary: MatchSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary.summary.headline)
                .font(.system(size: 16, weight: .semibold))

            Text(summary.summary.body)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textDim)

            if !summary.summary.notable.isEmpty {
                Divider().overlay(Theme.border)
                ForEach(summary.summary.notable, id: \.self) { item in
                    Text("• \(item)")
                        .font(.system(size: 13))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct Section2: View {
    let title: String
    let items: [String]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.textDim)
                ForEach(items, id: \.self) { item in
                    Text("• \(item)")
                        .font(.system(size: 13))
                }
            }
        }
    }
}
