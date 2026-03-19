import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "house.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Chore Tracker")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Maggie & Yuch")
                .font(.title3)
                .foregroundColor(.secondary)

            Spacer()

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email]
            } onCompletion: { result in
                // For now, use a development bypass since Google Sign-In
                // requires the GoogleSignIn SDK which needs CocoaPods/SPM setup.
                // In production, replace with Google Sign-In flow.
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 40)

            // Dev mode: manual token entry
            NavigationLink("Developer Login") {
                DevLoginView()
                    .environmentObject(authService)
            }
            .font(.caption)
            .foregroundColor(.secondary)

            if let error = authService.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .navigationTitle("")
    }
}

struct DevLoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:7990"
    @State private var token = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            Section("Server URL") {
                TextField("http://localhost:7990", text: $serverURL)
                    .autocapitalization(.none)
                    .keyboardType(.URL)
            }

            Section("API Token") {
                TextField("Paste token from server", text: $token)
                    .autocapitalization(.none)
            }

            Section {
                Button("Connect") {
                    UserDefaults.standard.set(serverURL, forKey: "serverURL")
                    KeychainHelper.save(key: "api_token", value: token)
                    authService.isAuthenticated = true
                    dismiss()
                }
                .disabled(token.isEmpty)
            }
        }
        .navigationTitle("Developer Login")
    }
}
