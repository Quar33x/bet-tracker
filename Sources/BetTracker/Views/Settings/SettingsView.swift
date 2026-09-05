import SwiftUI
import SwiftData

/// Подключение к своему бэкенду, расходы на модель и управление данными.
struct SettingsView: View {
    @Environment(BackendSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @Query private var bets: [Bet]
    @Query private var transactions: [BankTransaction]

    @State private var checkResult: String?
    @State private var isChecking = false
    @State private var spentToday: Double?
    @State private var showingWipeConfirmation = false
    @State private var wipeResult: String?

    var body: some View {
        @Bindable var settings = settings

        return NavigationStack {
            Form {
                Section {
                    TextField("https://bet-tracker-api.workers.dev", text: $settings.baseURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    SecureField("Токен приложения", text: $settings.token)
                } header: {
                    Text("Бэкенд")
                } footer: {
                    Text("Адрес воркера и токен, который задан в его секретах как APP_TOKEN. Ключи PandaScore и Claude живут на бэкенде и в приложение не попадают.")
                }

                Section {
                    Button {
                        Task { await check() }
                    } label: {
                        HStack {
                            Text("Проверить связь")
                            Spacer()
                            if isChecking { ProgressView() }
                        }
                    }
                    .disabled(!settings.isConfigured || isChecking)

                    if let checkResult {
                        Text(checkResult)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textDim)
                    }
                }

                Section {
                    HStack {
                        Text("Потрачено за сутки")
                        Spacer()
                        Text(spentToday.map { String(format: "$%.2f", $0) } ?? "—")
                            .font(.system(size: 15, design: .monospaced))
                            .foregroundStyle(Theme.accent)
                    }
                } header: {
                    Text("Расходы на модель")
                } footer: {
                    Text("Предматчевый разбор считается на Opus 5 по запросу, саммари — пакетом на Sonnet 5 вдвое дешевле. На бэкенде стоит дневной потолок: при его достижении запросы к модели прекращаются.")
                }

                Section {
                    HStack {
                        Text("Ставок в базе")
                        Spacer()
                        Text("\(bets.count)")
                            .foregroundStyle(Theme.textDim)
                    }

                    Button(role: .destructive) {
                        showingWipeConfirmation = true
                    } label: {
                        Text("Удалить все ставки и историю банка")
                    }

                    if let wipeResult {
                        Text(wipeResult)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textDim)
                    }
                } header: {
                    Text("Данные")
                } footer: {
                    Text("Приложение стартует с демонстрационными данными из старой таблицы: 20 ставок за 4-5 сентября. Перед тем как вести реальный учёт, их стоит удалить — иначе они попадут в винрейт, ROI и баланс. Турниры и матчи, заведённые вручную, останутся.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Source: PandaScore")
                        Text("Liquipedia — CC-BY-SA 3.0")
                        Text("Dota 2 — OpenDota")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDim)
                } header: {
                    Text("Источники данных")
                } footer: {
                    Text("Указание источников — требование их условий использования.")
                }
            }
            .navigationTitle("Настройки")
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .confirmationDialog(
                "Удалить \(bets.count) ставок и \(transactions.count) операций по банку?",
                isPresented: $showingWipeConfirmation,
                titleVisibility: .visible
            ) {
                Button("Удалить", role: .destructive) { wipeBettingData() }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Действие необратимо.")
            }
        }
        .task { await refreshSpend() }
    }

    /// Удаляет только ставки и движения по банку: турниры, команды и матчи
    /// заведены отдельно и к статистике не относятся.
    private func wipeBettingData() {
        let removedBets = bets.count
        let removedTransactions = transactions.count

        for bet in bets { context.delete(bet) }
        for transaction in transactions { context.delete(transaction) }

        do {
            try context.save()
            wipeResult = "Удалено: ставок \(removedBets), операций \(removedTransactions)."
        } catch {
            wipeResult = "Не удалось удалить: \(error.localizedDescription)"
        }
    }

    private func check() async {
        isChecking = true
        checkResult = nil
        defer { isChecking = false }

        do {
            let spend = try await BackendClient(settings: settings).spentToday()
            spentToday = spend
            checkResult = "Связь есть, токен принят."
        } catch {
            checkResult = error.localizedDescription
        }
    }

    private func refreshSpend() async {
        guard settings.isConfigured else { return }
        spentToday = try? await BackendClient(settings: settings).spentToday()
    }
}
