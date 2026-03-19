import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://yuch.ddns.net:7990"
    @State private var tasks: [ChoreTask] = []
    @State private var showAddTask = false
    @State private var newTaskName = ""
    @State private var newTaskReward = ""
    @State private var newTaskLimit = 1
    @State private var newTaskInterval = "weekly"

    private let api = APIClient.shared
    private let intervals = ["daily", "weekly", "monthly"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Server URL", text: $serverURL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .onSubmit {
                            UserDefaults.standard.set(serverURL, forKey: "serverURL")
                        }
                }

                Section("Manage Tasks") {
                    ForEach(tasks) { task in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(task.name)
                                    .font(.body)
                                Text("$\(String(format: "%.2f", task.reward)) • \(task.interval) • limit \(task.limitCount)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }

                    Button {
                        showAddTask.toggle()
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }
                }

                if showAddTask {
                    Section("New Task") {
                        TextField("Task name", text: $newTaskName)
                        TextField("Reward amount", text: $newTaskReward)
                            .keyboardType(.decimalPad)
                        Stepper("Limit: \(newTaskLimit)", value: $newTaskLimit, in: 1...20)
                        Picker("Interval", selection: $newTaskInterval) {
                            ForEach(intervals, id: \.self) { Text($0) }
                        }

                        Button("Create Task") {
                            Task { await createTask() }
                        }
                        .disabled(newTaskName.isEmpty || newTaskReward.isEmpty)
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        authService.signOut()
                    }
                }
            }
            .navigationTitle("Settings")
            .task { await loadTasks() }
        }
    }

    private func loadTasks() async {
        do {
            tasks = try await api.getTasks()
        } catch {
            // Handle error
        }
    }

    private func createTask() async {
        guard let reward = Double(newTaskReward) else { return }
        do {
            _ = try await api.createTask(
                name: newTaskName, reward: reward,
                limitCount: newTaskLimit, interval: newTaskInterval
            )
            newTaskName = ""
            newTaskReward = ""
            newTaskLimit = 1
            showAddTask = false
            await loadTasks()
        } catch {
            // Handle error
        }
    }
}
