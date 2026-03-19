import SwiftUI

struct LedgerView: View {
    @State private var selectedCurrency = "CAD"
    @State private var ledger: LedgerResponse?
    @State private var showAddForm = false
    @State private var user = "Yuch"
    @State private var description = ""
    @State private var amount = ""
    @State private var transactionType = "add"
    @State private var errorMessage: String?
    @State private var transactionToEdit: Transaction?

    private let api = APIClient.shared
    private let currencies = ["USD", "CAD"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Currency picker
                Picker("Currency", selection: $selectedCurrency) {
                    ForEach(currencies, id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: selectedCurrency) { _, _ in
                    Task { await loadLedger() }
                }

                // Balance
                if let ledger = ledger {
                    Text(String(format: "$%.2f %@", ledger.total, ledger.currency))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(selectedCurrency == "USD" ? Color(hex: "#008080") : Color(hex: "#808000"))
                        .padding(.bottom)
                }

                // Add transaction form
                if showAddForm {
                    addTransactionForm
                }

                // Transaction list
                List {
                    if let transactions = ledger?.transactions {
                        ForEach(transactions) { tx in
                            Button {
                                transactionToEdit = tx
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(tx.description ?? "No description")
                                            .font(.body)
                                        Text(tx.user ?? "")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(String(format: "%@$%.2f", tx.amount >= 0 ? "+" : "", tx.amount))
                                        .font(.body.monospacedDigit())
                                        .foregroundColor(tx.amount >= 0 ? .green : .red)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Ledger")
            .toolbar {
                Button {
                    withAnimation { showAddForm.toggle() }
                } label: {
                    Image(systemName: showAddForm ? "minus.circle" : "plus.circle")
                }
            }
            .sheet(item: $transactionToEdit) { tx in
                EditTransactionSheet(transaction: tx, currency: selectedCurrency, onSave: { await loadLedger() })
            }
            .refreshable { await loadLedger() }
            .task { await loadLedger() }
        }
    }

    private var addTransactionForm: some View {
        VStack(spacing: 10) {
            Picker("User", selection: $user) {
                Text("Yuch").tag("Yuch")
                Text("Maggie").tag("Maggie")
            }
            .pickerStyle(.segmented)

            TextField("Description", text: $description)
                .textFieldStyle(.roundedBorder)

            HStack {
                TextField("Amount", text: $amount)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)

                Picker("Type", selection: $transactionType) {
                    Text("Add").tag("add")
                    Text("Subtract").tag("subtract")
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            Button {
                Task { await addTransaction() }
            } label: {
                Label("Add Transaction", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(description.isEmpty || amount.isEmpty)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func loadLedger() async {
        do {
            ledger = try await api.getLedger(currency: selectedCurrency)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addTransaction() async {
        guard let amountVal = Double(amount) else { return }
        do {
            try await api.addTransaction(
                currency: selectedCurrency, user: user,
                description: description, amount: amountVal,
                type: transactionType
            )
            description = ""
            amount = ""
            showAddForm = false
            await loadLedger()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct EditTransactionSheet: View {
    let transaction: Transaction
    let currency: String
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss

    @State private var errorMessage: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Description")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(transaction.description ?? "No description")
                    }
                    HStack {
                        Text("User")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(transaction.user ?? "")
                    }
                    HStack {
                        Text("Amount")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "$%.2f", transaction.amount))
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await delete() }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Transaction", systemImage: "trash")
                            Spacer()
                        }
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func delete() async {
        do {
            try await api.deleteTransaction(currency: currency, id: transaction.id)
            await onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
