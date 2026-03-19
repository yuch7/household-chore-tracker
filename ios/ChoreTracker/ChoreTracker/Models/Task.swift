import Foundation

struct ChoreTask: Codable, Identifiable {
    let id: Int
    let name: String
    let reward: Double
    let limitCount: Int
    let interval: String

    enum CodingKeys: String, CodingKey {
        case id, name, reward, interval
        case limitCount = "limit_count"
    }
}
