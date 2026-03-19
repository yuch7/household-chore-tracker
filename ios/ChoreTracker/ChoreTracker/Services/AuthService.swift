import Foundation
import AuthenticationServices
import SwiftUI

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userEmail: String = ""
    @Published var errorMessage: String?

    private var webAuthSession: ASWebAuthenticationSession?

    init() {
        if KeychainHelper.load(key: "api_token") != nil {
            isAuthenticated = true
            userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? ""
        }
    }

    var baseURL: String {
        UserDefaults.standard.string(forKey: "serverURL") ?? "http://yuch.ddns.net:7990"
    }

    func startGoogleSignIn() {
        guard let authURL = URL(string: "\(baseURL)/api/v1/auth/login") else {
            errorMessage = "Invalid server URL"
            return
        }

        webAuthSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "choretracker"
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        return
                    }
                    self?.errorMessage = error.localizedDescription
                    return
                }

                guard let url = callbackURL else {
                    self?.errorMessage = "No callback received"
                    return
                }

                self?.handleCallback(url: url)
            }
        }

        webAuthSession?.presentationContextProvider = WebAuthContextProvider.shared
        webAuthSession?.prefersEphemeralWebBrowserSession = false
        webAuthSession?.start()
    }

    func handleCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              let email = components.queryItems?.first(where: { $0.name == "email" })?.value
        else {
            errorMessage = "Invalid auth callback"
            return
        }

        KeychainHelper.save(key: "api_token", value: token)
        UserDefaults.standard.set(email, forKey: "userEmail")
        userEmail = email
        isAuthenticated = true
        errorMessage = nil
    }

    func signOut() {
        KeychainHelper.delete(key: "api_token")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        isAuthenticated = false
        userEmail = ""
    }
}

class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first
        else {
            return ASPresentationAnchor()
        }
        return window
    }
}
