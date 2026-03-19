import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int, String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .unauthorized: return "Not authenticated"
        case .serverError(let code, let msg): return "Server error \(code): \(msg)"
        case .decodingError(let err): return "Decoding error: \(err.localizedDescription)"
        case .networkError(let err): return err.localizedDescription
        }
    }
}

@MainActor
class APIClient: ObservableObject {
    static let shared = APIClient()

    private var baseURL: String {
        UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:7990"
    }

    private var token: String? {
        KeychainHelper.load(key: "api_token")
    }

    private func makeRequest(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError(0, "Invalid response")
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        if httpResponse.statusCode >= 400 {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, message)
        }

        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Auth

    func authenticateWithGoogle(idToken: String) async throws -> String {
        let data = try await makeRequest("/api/auth/google", method: "POST", body: ["id_token": idToken])
        let result = try decode([String: String].self, from: data)
        guard let token = result["token"] else {
            throw APIError.serverError(0, "No token in response")
        }
        return token
    }

    // MARK: - Balance

    func getBalance() async throws -> Balance {
        let data = try await makeRequest("/api/balance")
        return try decode(Balance.self, from: data)
    }

    // MARK: - Tasks

    func getTasks() async throws -> [ChoreTask] {
        let data = try await makeRequest("/api/tasks")
        return try decode([ChoreTask].self, from: data)
    }

    func createTask(name: String, reward: Double, limitCount: Int, interval: String) async throws -> ChoreTask {
        let data = try await makeRequest("/api/tasks", method: "POST", body: [
            "name": name, "reward": reward,
            "limit_count": limitCount, "interval": interval
        ])
        return try decode(ChoreTask.self, from: data)
    }

    func deleteTask(id: Int) async throws {
        _ = try await makeRequest("/api/tasks/\(id)", method: "DELETE")
    }

    // MARK: - Chores

    func logChore(taskId: Int, user: String, date: String? = nil) async throws -> ChoreLog {
        var body: [String: Any] = ["task_id": taskId, "user": user]
        if let date = date { body["date"] = date }
        let data = try await makeRequest("/api/chores", method: "POST", body: body)
        return try decode(ChoreLog.self, from: data)
    }

    func logCustomChore(user: String, name: String, amount: Double) async throws -> ChoreLog {
        let data = try await makeRequest("/api/chores/custom", method: "POST", body: [
            "user": user, "name": name, "amount": amount
        ])
        return try decode(ChoreLog.self, from: data)
    }

    func getHistory(page: Int = 1) async throws -> ChoreHistoryResponse {
        let data = try await makeRequest("/api/history?page=\(page)")
        return try decode(ChoreHistoryResponse.self, from: data)
    }

    // MARK: - Calendar Events

    func getEvents(start: String? = nil, end: String? = nil) async throws -> [CalendarEvent] {
        var path = "/api/events"
        if let start = start, let end = end {
            path += "?start=\(start)&end=\(end)"
        }
        let data = try await makeRequest(path)
        return try decode([CalendarEvent].self, from: data)
    }

    func createEvent(title: String, eventDate: String, color: String, startTime: String? = nil, durationMinutes: Int? = nil) async throws {
        var body: [String: Any] = ["title": title, "event_date": eventDate, "color": color]
        if let startTime = startTime { body["start_time"] = startTime }
        if let durationMinutes = durationMinutes { body["duration_minutes"] = durationMinutes }
        _ = try await makeRequest("/api/events", method: "POST", body: body)
    }

    func deleteEvent(id: Int) async throws {
        _ = try await makeRequest("/api/events/\(id)", method: "DELETE")
    }

    // MARK: - Ledger

    func getLedger(currency: String) async throws -> LedgerResponse {
        let data = try await makeRequest("/api/ledger/\(currency)")
        return try decode(LedgerResponse.self, from: data)
    }

    func addTransaction(currency: String, user: String, description: String, amount: Double, type: String) async throws {
        _ = try await makeRequest("/api/ledger/\(currency)", method: "POST", body: [
            "user": user, "description": description,
            "amount": amount, "type": type
        ])
    }

    func deleteTransaction(currency: String, id: Int) async throws {
        _ = try await makeRequest("/api/ledger/\(currency)/\(id)", method: "DELETE")
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
