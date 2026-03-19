import Foundation

struct Balance: Codable {
    let balance: Double
    let maggieTotal: Double
    let yuchTotal: Double

    enum CodingKeys: String, CodingKey {
        case balance
        case maggieTotal = "maggie_total"
        case yuchTotal = "yuch_total"
    }
}
