import SwiftUI
import SwiftData

struct BetFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tournament.name) private var tournaments: [Tournament]

    /// nil — новая ставка, иначе редактирование существующей.
    let bet: Bet?

    @State private var date = Date()
    @State private var discipline: Discipline = .valorant
    @State private var title = ""
    @State private var tournament: Tournament?
    @State private var amountText = ""
    @State private var oddsText = ""
    @State private var status: BetStatus = .pending
    @State private var betType = ""
    @State private var note = ""

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var odds: Decimal? {
        Decimal(string: oddsText.replacingOccurrences(of: ",", with: "."))
    }

    private var isValid: Bool {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty,
              let amount, amount > 0,
              let odds, odds > 1
        else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Дисциплина", selection: $discipline) {
                        ForEach(Discipline.allCases) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                    TextField("Например: FUR -3,5 VIT map1", text: $title, axis: .vertical)
                    Picker("Турнир", selection: $tournament) {
                        Text("Без турнира").tag(Tournament?.none)
                        ForEach(tournaments) { t in
                            Text(t.name).tag(Tournament?.some(t))
                        }
                    }
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                }

                Section {
                    HStack {
                        Text("Сумма")
                        Spacer()
                        TextField("500", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Коэффициент")
                        Spacer()
                        TextField("2.05", text: $oddsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("Профит и ROI считаются сами по сумме и кэфу")
                }

                Section("Статус") {
                    Picker("Статус", selection: $status) {
                        ForEach(BetStatus.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Дополнительно") {
                    TextField("Тип ставки: -3.5, ИСХОД, Экспресс", text: $betType)
                    TextField("Заметка: усреднено 600@2.70 + 400@2.15", text: $note, axis: .vertical)
                }

                if isValid, let amount, let odds {
                    Section("Расчёт") {
                        LabeledContent("Потенциальный профит", value: MoneyFormatter.signed(amount * (odds - 1)))
                        LabeledContent("Возврат при выигрыше", value: MoneyFormatter.string(amount * odds))
                    }
                }
            }
            .navigationTitle(bet == nil ? "Новая ставка" : "Ставка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save).disabled(!isValid)
                }
            }
        }
        .onAppear(perform: loadExisting)
    }

    private func loadExisting() {
        guard let bet else { return }
        date = bet.date
        discipline = bet.discipline
        title = bet.title
        tournament = bet.tournament
        amountText = "\(bet.amount)"
        oddsText = "\(bet.odds)"
        status = bet.status
        betType = bet.betType ?? ""
        note = bet.note ?? ""
    }

    private func save() {
        guard let amount, let odds else { return }
        let trimmedType = betType.trimmingCharacters(in: .whitespaces)
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)

        if let bet {
            bet.date = date
            bet.discipline = discipline
            bet.title = title
            bet.amount = amount
            bet.odds = odds
            bet.status = status
            bet.tournament = tournament
            bet.betType = trimmedType.isEmpty ? nil : trimmedType
            bet.note = trimmedNote.isEmpty ? nil : trimmedNote
        } else {
            let newBet = Bet(
                date: date, discipline: discipline, title: title,
                amount: amount, odds: odds, status: status,
                betType: trimmedType.isEmpty ? nil : trimmedType,
                tournament: tournament,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            context.insert(newBet)
        }
        dismiss()
    }
}
