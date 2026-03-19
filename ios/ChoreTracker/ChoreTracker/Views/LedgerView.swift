import SwiftUI

struct LedgerView: View {
    @State private var selectedCurrency = "USD"
    @State private var ledger: LedgerResponse?
    @State private var showAddForm = false
    @State private var user = "Yuch"
    @State private var description = ""
    @State private var amount = ""
    @State private var transactionType = "add"
    @State private var errorMessage: String?

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
                        .onDelete { indexSet in
                            let toDelete = indexSet.compactMap { transactions[$0].id }
                            Task {
                                for id in toDelete {
                                    try? await api.deleteTransaction(currency: selectedCurrency, id: id)
                                }
                                await loadLedger()
                            }
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
