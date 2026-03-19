import Foundation
import AuthenticationServices

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userEmail: String = ""
    @Published var errorMessage: String?

    private let api = APIClient.shared

    init() {
        if KeychainHelper.load(key: "api_token") != nil {
            isAuthenticated = true
            userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? ""
        }
    }

    func signIn(idToken: String) async {
        do {
            let token = try await api.authenticateWithGoogle(idToken: idToken)
            KeychainHelper.save(key: "api_token", value: token)
            isAuthenticated = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        KeychainHelper.delete(key: "api_token")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        isAuthenticated = false
        userEmail = ""
    }
}
