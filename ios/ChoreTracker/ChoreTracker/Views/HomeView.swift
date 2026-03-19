import SwiftUI

struct HomeView: View {
    @State private var balance: Balance?
    @State private var tasks: [ChoreTask] = []
    @State private var recentChores: [ChoreLog] = []
    @State private var selectedUser = "Yuch"
    @State private var selectedTaskId: Int?
    @State private var showCustom = false
    @State private var customName = ""
    @State private var customAmount = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = APIClient.shared
    private let users = ["Yuch", "Maggie"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Balance Card
                    balanceCard

                    // Log a Chore
                    logChoreSection

                    // Custom Chore
                    customChoreSection

                    // Recent Activity
                    recentActivitySection
                }
                .padding()
            }
            .navigationTitle("Home")
            .refreshable { await loadData() }
            .task { await loadData() }
        }
    }

    private var balanceCard: some View {
        VStack(spacing: 8) {
            Text("Balance")
                .font(.headline)
                .foregroundColor(.secondary)

            if let balance = balance {
                Text(String(format: "$%.2f", balance.balance))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(balance.balance >= 0 ? .green : .red)

                HStack(spacing: 20) {
                    Label(String(format: "$%.2f", balance.yuchTotal), systemImage: "person.fill")
                        .foregroundColor(Color(hex: "#007bff"))
                    Label(String(format: "$%.2f", balance.maggieTotal), systemImage: "person.fill")
                        .foregroundColor(Color(hex: "#dc3545"))
                }
                .font(.subheadline)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }

    private var logChoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log a Chore")
                .font(.headline)

            Picker("User", selection: $selectedUser) {
                ForEach(users, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)

            if !tasks.isEmpty {
                Picker("Task", selection: $selectedTaskId) {
                    Text("Select a task").tag(nil as Int?)
                    ForEach(tasks) { task in
                        Text("\(task.name) ($\(String(format: "%.2f", task.reward)))")
                            .tag(task.id as Int?)
                    }
                }

                Button {
                    Task { await logChore() }
                } label: {
                    Label("Log Chore", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(selectedUser == "Yuch" ? Color(hex: "#007bff") : Color(hex: "#dc3545"))
                .disabled(selectedTaskId == nil)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }

    private var customChoreSection: some View {
        DisclosureGroup("Add Custom Chore", isExpanded: $showCustom) {
            VStack(spacing: 12) {
                TextField("Chore name", text: $customName)
                    .textFieldStyle(.roundedBorder)
                TextField("Amount", text: $customAmount)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)

                Button {
                    Task { await logCustom() }
                } label: {
                    Label("Add Custom", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(customName.isEmpty || customAmount.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    HistoryView()
                }
                .font(.subheadline)
            }

            if recentChores.isEmpty {
                Text("No recent chores")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(recentChores) { chore in
                    HStack {
                        Circle()
                            .fill(chore.userName == "Yuch" ? Color(hex: "#007bff") : Color(hex: "#dc3545"))
                            .frame(width: 8, height: 8)
                        Text(chore.taskName)
                            .lineLimit(1)
                        Spacer()
                        Text(String(format: "$%.2f", chore.rewardAtTime))
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        async let balanceReq = api.getBalance()
        async let tasksReq = api.getTasks()
        async let historyReq = api.getHistory(page: 1)

        do {
            balance = try await balanceReq
            tasks = try await tasksReq
            let history = try await historyReq
            recentChores = Array(history.items.prefix(5))
            if let first = tasks.first, selectedTaskId == nil {
                selectedTaskId = first.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func logChore() async {
        guard let taskId = selectedTaskId else { return }
        do {
            _ = try await api.logChore(taskId: taskId, user: selectedUser)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func logCustom() async {
        guard let amount = Double(customAmount) else { return }
        do {
            _ = try await api.logCustomChore(user: selectedUser, name: customName, amount: amount)
            customName = ""
            customAmount = ""
            showCustom = false
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
