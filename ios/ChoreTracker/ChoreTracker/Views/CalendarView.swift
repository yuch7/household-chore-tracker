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
                monthHeader

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(daysInMonth(), id: \.self) { day in
                            if let day = day {
                                dayRow(for: day)
                            }
                        }
                    }
                }
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
            .refreshable { await loadEvents() }
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

    private func dayRow(for day: Date) -> some View {
        let dateStr = dateFormatter.string(from: day)
        let dayEvents = events.filter { $0.displayDate == dateStr }
        let isToday = calendar.isDateInToday(day)
        let dayOfWeek = day.formatted(.dateTime.weekday(.abbreviated))

        return VStack(alignment: .leading, spacing: 0) {
            // Day header
            HStack(spacing: 8) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 20, weight: isToday ? .bold : .medium, design: .rounded))
                    .foregroundColor(isToday ? .white : .primary)
                    .frame(width: 34, height: 34)
                    .background(isToday ? Color.blue : Color.clear)
                    .clipShape(Circle())

                Text(dayOfWeek)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, dayEvents.isEmpty ? 8 : 4)

            // Events for this day
            ForEach(dayEvents) { event in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: event.displayColor))
                        .frame(width: 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        if let time = event.startTime {
                            Text(time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .frame(height: 32)
                .padding(.horizontal)
                .padding(.leading, 24)
            }

            Divider()
                .padding(.leading)
        }
    }

    private func daysInMonth() -> [Date?] {
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!

        var days: [Date?] = []
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
