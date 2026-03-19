import Foundation

struct Transaction: Codable, Identifiable {
    let id: Int
    let user: String?
    let description: String?
    let amount: Double
    let timestamp: String
}

struct LedgerResponse: Codable {
    let currency: String
    let total: Double
    let transactions: [Transaction]
}
