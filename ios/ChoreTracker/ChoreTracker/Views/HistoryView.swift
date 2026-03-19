import SwiftUI

struct HistoryView: View {
    @State private var chores: [ChoreLog] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false

    private let api = APIClient.shared

    var body: some View {
        List {
            ForEach(chores) { chore in
                HStack {
                    Circle()
                        .fill(chore.userName == "Yuch" ? Color(hex: "#007bff") : Color(hex: "#dc3545"))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading) {
                        Text(chore.taskName)
                            .font(.body)
                        Text("\(chore.userName) • \(chore.dateCompleted)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    let prefix = chore.userName == "Yuch" ? "-" : "+"
                    Text("\(prefix)$\(String(format: "%.2f", chore.rewardAtTime))")
                        .font(.body.monospacedDigit())
                        .foregroundColor(chore.userName == "Yuch" ? Color(hex: "#007bff") : Color(hex: "#dc3545"))
                }
            }

            if currentPage < totalPages {
                Button("Load More") {
                    Task { await loadMore() }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("History")
        .refreshable { await loadData(reset: true) }
        .task { await loadData(reset: true) }
    }

    private func loadData(reset: Bool) async {
        if reset { currentPage = 1 }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await api.getHistory(page: currentPage)
            if reset {
                chores = response.items
            } else {
                chores.append(contentsOf: response.items)
            }
            totalPages = response.pages
        } catch {
            // Handle error
        }
    }

    private func loadMore() async {
        currentPage += 1
        await loadData(reset: false)
    }
}
