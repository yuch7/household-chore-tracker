import SwiftUI

struct CalendarView: View {
    @State private var selectedDate = Date()
    @State private var events: [CalendarEvent] = []
    @State private var showAddEvent = false
    @State private var currentMonth = Date()

    private let api = APIClient.shared
    private let calendar = Foundation.Calendar.current
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month navigation
                monthHeader

                // Weekday headers
                weekdayHeader

                // Calendar grid
                calendarGrid

                Divider()

                // Events for selected date
                eventsList
            }
            .navigationTitle("Calendar")
            .toolbar {
                Button {
                    showAddEvent = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showAddEvent) {
                AddEventSheet(onSave: { await loadEvents() })
            }
            .task { await loadEvents() }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                Task { await loadEvents() }
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(currentMonth, format: .dateTime.month(.wide).year())
                .font(.title2.bold())

            Spacer()

            Button {
                currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                Task { await loadEvents() }
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .padding()
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }

    private var calendarGrid: some View {
        let days = daysInMonth()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days, id: \.self) { day in
                if let day = day {
                    let dateStr = dateFormatter.string(from: day)
                    let dayEvents = events.filter { $0.displayDate == dateStr }
                    let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)

                    Button {
                        selectedDate = day
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(calendar.component(.day, from: day))")
                                .font(.body)
                                .foregroundColor(isSelected ? .white : .primary)

                            HStack(spacing: 2) {
                                ForEach(Array(dayEvents.prefix(3).enumerated()), id: \.offset) { _, event in
                                    Circle()
                                        .fill(Color(hex: event.displayColor))
                                        .frame(width: 5, height: 5)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.blue : Color.clear)
                        )
                    }
                } else {
                    Text("")
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
        }
        .padding(.horizontal)
    }

    private var eventsList: some View {
        let dateStr = dateFormatter.string(from: selectedDate)
        let dayEvents = events.filter { $0.displayDate == dateStr }

        return List {
            if dayEvents.isEmpty {
                Text("No events")
                    .foregroundColor(.secondary)
            } else {
                ForEach(dayEvents) { event in
                    HStack {
                        Circle()
                            .fill(Color(hex: event.displayColor))
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading) {
                            Text(event.title)
                                .font(.body)
                            if let time = event.startTime {
                                Text(time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    let toDelete = indexSet.map { dayEvents[$0] }
                    Task {
                        for event in toDelete {
                            if event.type == "event" {
                                try? await api.deleteEvent(id: event.dbId)
                            }
                        }
                        await loadEvents()
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func daysInMonth() -> [Date?] {
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingBlanks = weekday - 1

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: firstDay))
        }
        return days
    }

    private func loadEvents() async {
        let comps = calendar.dateComponents([.year, .month], from: currentMonth)
        let firstDay = calendar.date(from: comps)!
        let lastDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay)!

        let start = dateFormatter.string(from: firstDay)
        let end = dateFormatter.string(from: lastDay)

        do {
            events = try await api.getEvents(start: start, end: end)
        } catch {
            // Silently handle for now
        }
    }
}

struct AddEventSheet: View {
    let onSave: () async -> Void
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var eventDate = Date()
    @State private var hasTime = false
    @State private var startTime = Date()
    @State private var duration = 60
    @State private var color = "#28a745"

    private let api = APIClient.shared
    private let colors = ["#28a745", "#007bff", "#dc3545", "#ffc107", "#6f42c1", "#17a2b8"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Event title", text: $title)

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
                                    Circle().stroke(Color.primary, lineWidth: c == color ? 3 : 0)
                                )
                                .onTapGesture { color = c }
                        }
                    }
                }
            }
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveEvent() }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveEvent() async {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: eventDate)

        var timeStr: String?
        var dur: Int?
        if hasTime {
            let tf = DateFormatter()
            tf.dateFormat = "HH:mm"
            timeStr = tf.string(from: startTime)
            dur = duration
        }

        do {
            try await api.createEvent(title: title, eventDate: dateStr, color: color, startTime: timeStr, durationMinutes: dur)
            await onSave()
            dismiss()
        } catch {
            // Handle error
        }
    }
}
