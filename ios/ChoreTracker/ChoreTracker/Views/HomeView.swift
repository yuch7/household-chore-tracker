import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var balance: Balance?
    @State private var tasks: [ChoreTask] = []
    @State private var recentChores: [ChoreLog] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var currentWeekStart = Date()
    @State private var showAddSheet = false
    @State private var eventToMove: CalendarEvent?

    private let api = APIClient.shared
    private let cal = Foundation.Calendar.current
    private let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    balanceCard
                    calendarSection
                    recentActivitySection

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding()
            }
            .navigationTitle("Home")
            .toolbar {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddSheet(tasks: tasks, onSave: { await loadData() })
            }
            .sheet(item: $eventToMove) { event in
                MoveEventSheet(event: event, onSave: { await loadData() })
            }
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

            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Week header
            HStack {
                Button {
                    currentWeekStart = cal.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) ?? currentWeekStart
                    Task { await loadCalendarEvents() }
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart())!
                Text("\(weekStart(), format: .dateTime.month(.abbreviated).day()) – \(weekEnd, format: .dateTime.month(.abbreviated).day())")
                    .font(.headline)

                Spacer()

                Button {
                    currentWeekStart = cal.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) ?? currentWeekStart
                    Task { await loadCalendarEvents() }
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            // Days in week
            ForEach(daysInWeek(), id: \.self) { day in
                let dateStr = dateFmt.string(from: day)
                let dayEvents = calendarEvents.filter { $0.displayDate == dateStr }
                let isToday = cal.isDateInToday(day)
                let dayOfWeek = day.formatted(.dateTime.weekday(.abbreviated))

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Text("\(cal.component(.day, from: day))")
                            .font(.system(size: 18, weight: isToday ? .bold : .medium, design: .rounded))
                            .foregroundColor(isToday ? .white : .primary)
                            .frame(width: 30, height: 30)
                            .background(isToday ? Color.blue : Color.clear)
                            .clipShape(Circle())

                        Text(dayOfWeek)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)
                    .padding(.bottom, dayEvents.isEmpty ? 6 : 2)

                    ForEach(dayEvents) { event in
                        Button {
                            eventToMove = event
                        } label: {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: event.displayColor))
                                    .frame(width: 4)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(event.title)
                                        .font(.caption)
                                        .lineLimit(1)
                                    if let time = event.startTime {
                                        Text(time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()

                                Image(systemName: "calendar.badge.clock")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(height: 28)
                        .padding(.horizontal)
                        .padding(.leading, 20)
                    }

                    Divider().padding(.leading)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }

    private func weekStart() -> Date {
        let daysSinceSunday = (cal.component(.weekday, from: currentWeekStart) + 5) % 7
        return cal.date(byAdding: .day, value: -daysSinceSunday, to: currentWeekStart) ?? currentWeekStart
    }

    private func daysInWeek() -> [Date] {
        let start = weekStart()
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func loadCalendarEvents() async {
        let start = weekStart()
        let end = cal.date(byAdding: .day, value: 6, to: start)!

        do {
            calendarEvents = try await api.getEvents(
                start: dateFmt.string(from: start),
                end: dateFmt.string(from: end)
            )
        } catch {
            // handled elsewhere
        }
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

        await loadCalendarEvents()

        do {
            balance = try await balanceReq
            tasks = try await tasksReq
            let history = try await historyReq
            recentChores = Array(history.items.prefix(5))
        } catch let error as APIError {
            if case .unauthorized = error {
                authService.signOut()
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}

enum AddFormType: String, CaseIterable {
    case chore = "Chore"
    case custom = "Custom"
    case event = "Event"
}

struct AddSheet: View {
    let tasks: [ChoreTask]
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss

    @State private var formType: AddFormType = .chore

    // Chore fields
    @State private var selectedUser = "Yuch"
    @State private var selectedTaskId: Int?

    // Custom chore fields
    @State private var customName = ""
    @State private var customAmount = ""

    // Event fields
    @State private var eventTitle = ""
    @State private var eventDate = Date()
    @State private var hasTime = false
    @State private var startTime = Date()
    @State private var duration = 60
    @State private var eventColor = "#28a745"

    private let api = APIClient.shared
    private let colors = ["#28a745", "#007bff", "#dc3545", "#ffc107", "#6f42c1", "#17a2b8"]

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $formType) {
                    ForEach(AddFormType.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)

                switch formType {
                case .chore:
                    choreForm
                case .custom:
                    customChoreForm
                case .event:
                    eventForm
                }
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    @ViewBuilder
    private var choreForm: some View {
        Picker("User", selection: $selectedUser) {
            Text("Yuch").tag("Yuch")
            Text("Maggie").tag("Maggie")
        }
        .pickerStyle(.segmented)

        Picker("Task", selection: $selectedTaskId) {
            Text("Select a task").tag(nil as Int?)
            ForEach(tasks) { task in
                Text("\(task.name) ($\(String(format: "%.2f", task.reward)))")
                    .tag(task.id as Int?)
            }
        }
    }

    @ViewBuilder
    private var customChoreForm: some View {
        Picker("User", selection: $selectedUser) {
            Text("Yuch").tag("Yuch")
            Text("Maggie").tag("Maggie")
        }
        .pickerStyle(.segmented)

        TextField("Chore name", text: $customName)
        TextField("Amount", text: $customAmount)
            .keyboardType(.decimalPad)
    }

    @ViewBuilder
    private var eventForm: some View {
        TextField("Event title", text: $eventTitle)
        DatePicker("Date", selection: $eventDate, displayedComponents: .date)
        Toggle("Has specific time", isOn: $hasTime)

        if hasTime {
            DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
            Stepper("Duration: \(duration) min", value: $duration, in: 15...480, step: 15)
        }

        Section("Color") {
            HStack {
                ForEach(colors, id: \.self) { c in
                    Circle()
                        .fill(Color(hex: c))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle().stroke(Color.primary, lineWidth: c == eventColor ? 3 : 0)
                        )
                        .onTapGesture { eventColor = c }
                }
            }
        }
    }

    private var canSave: Bool {
        switch formType {
        case .chore: return selectedTaskId != nil
        case .custom: return !customName.isEmpty && !customAmount.isEmpty
        case .event: return !eventTitle.isEmpty
        }
    }

    private func save() async {
        do {
            switch formType {
            case .chore:
                guard let taskId = selectedTaskId else { return }
                _ = try await api.logChore(taskId: taskId, user: selectedUser)
            case .custom:
                guard let amount = Double(customAmount) else { return }
                _ = try await api.logCustomChore(user: selectedUser, name: customName, amount: amount)
            case .event:
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                var timeStr: String?
                var dur: Int?
                if hasTime {
                    let tf = DateFormatter()
                    tf.dateFormat = "HH:mm"
                    timeStr = tf.string(from: startTime)
                    dur = duration
                }
                try await api.createEvent(
                    title: eventTitle, eventDate: df.string(from: eventDate),
                    color: eventColor, startTime: timeStr, durationMinutes: dur
                )
            }
            await onSave()
            dismiss()
        } catch {
            // Handle error
        }
    }
}

struct MoveEventSheet: View {
    let event: CalendarEvent
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss

    @State private var newDate = Date()
    @State private var errorMessage: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(event.title)
                        .font(.headline)
                }

                Section("Move to") {
                    DatePicker("New date", selection: $newDate, displayedComponents: .date)
                }

                Section {
                    Button(role: .destructive) {
                        Task { await delete() }
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete", systemImage: "trash")
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
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        Task { await move() }
                    }
                }
            }
        }
    }

    private func delete() async {
        do {
            if event.type == "chore" {
                try await api.deleteChore(id: event.dbId)
            } else {
                try await api.deleteEvent(id: event.dbId)
            }
            await onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func move() async {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: newDate)

        do {
            if event.type == "chore" {
                try await api.moveChore(id: event.dbId, date: dateStr)
            } else {
                try await api.moveEvent(id: event.dbId, date: dateStr)
            }
            await onSave()
            dismiss()
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
