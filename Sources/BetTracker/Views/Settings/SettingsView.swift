import SwiftUI

/// Подключение к своему бэкенду и расходы на модель.
struct SettingsView: View {
    @Environment(BackendSettings.self) private var settings

    @State private var checkResult: String?
    @State private var isChecking = false
    @State private var spentToday: Double?

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
        }
        .task { await refreshSpend() }
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
