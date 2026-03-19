import Foundation

struct CalendarEvent: Codable, Identifiable {
    let id: String
    let title: String
    let type: String
    let dbId: Int

    // Chore-specific
    let start: String?
    let backgroundColor: String?

    // Event-specific
    let eventDate: String?
    let color: String?
    let startTime: String?
    let durationMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, type, dbId, start, backgroundColor, color
        case eventDate = "event_date"
        case startTime = "start_time"
        case durationMinutes = "duration_minutes"
    }

    var displayDate: String {
        start ?? eventDate ?? ""
    }

    var displayColor: String {
        backgroundColor ?? color ?? "#28a745"
    }
}
