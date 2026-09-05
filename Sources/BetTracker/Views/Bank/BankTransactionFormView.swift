import SwiftUI
import SwiftData

struct BankTransactionFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var kind: TransactionKind = .deposit
    @State private var date = Date()
    @State private var amountText = ""
    @State private var note = ""

    private var amount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var isValid: Bool {
        guard let amount else { return false }
        return amount > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Тип", selection: $kind) {
                    ForEach(TransactionKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Сумма")
                    Spacer()
                    TextField("1500", text: $amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }

                DatePicker("Дата", selection: $date, displayedComponents: .date)
                TextField("Комментарий", text: $note)
            }
            .navigationTitle("Движение по банку")
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
    }

    private func save() {
        guard let amount else { return }
        let trimmed = note.trimmingCharacters(in: .whitespaces)
        context.insert(
            BankTransaction(date: date, kind: kind, amount: amount, note: trimmed.isEmpty ? nil : trimmed)
        )
        dismiss()
    }
}
