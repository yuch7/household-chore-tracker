import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://yuch.ddns.net:7990"
    @State private var showServerConfig = false

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

            Button {
                authService.startGoogleSignIn()
            } label: {
                HStack {
                    Image(systemName: "globe")
                    Text("Sign in with Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
            }
            .padding(.horizontal, 40)

            Button {
                showServerConfig.toggle()
            } label: {
                Text("Server: \(serverURL)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if showServerConfig {
                HStack {
                    TextField("Server URL", text: $serverURL)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    Button("Save") {
                        UserDefaults.standard.set(serverURL, forKey: "serverURL")
                        showServerConfig = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 40)
            }

            if let error = authService.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }
}
