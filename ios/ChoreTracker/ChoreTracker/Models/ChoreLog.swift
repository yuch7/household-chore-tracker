import Foundation

struct ChoreLog: Codable, Identifiable {
    let id: Int
    let userName: String
    let taskName: String
    let rewardAtTime: Double
    let dateCompleted: String

    enum CodingKeys: String, CodingKey {
        case id
        case userName = "user_name"
        case taskName = "task_name"
        case rewardAtTime = "reward_at_time"
        case dateCompleted = "date_completed"
    }
}

struct ChoreHistoryResponse: Codable {
    let items: [ChoreLog]
    let page: Int
    let pages: Int
    let total: Int
}
