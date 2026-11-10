import SwiftUI

struct AuthView: View {
    @EnvironmentObject var session: SessionStore
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("DMChat")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.purple, .pink, .orange],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
            if isSignUp { field("Username", text: $username) }
            field("Email", text: $email)
            SecureField("Password", text: $password)
                .padding(12).background(Color(.secondarySystemBackground)).cornerRadius(10)

            if let err = session.errorMessage {
                Text(err).font(.footnote).foregroundColor(.red).multilineTextAlignment(.center)
            }

            Button {
                Task {
                    if isSignUp { await session.signUp(email: email, password: password, username: username) }
                    else { await session.signIn(email: email, password: password) }
                }
            } label: {
                Group {
                    if session.busy { ProgressView().tint(.white) }
                    else { Text(isSignUp ? "Create account" : "Log in").bold() }
                }
                .frame(maxWidth: .infinity).padding(12)
                .background(Color.blue).foregroundColor(.white).cornerRadius(10)
            }
            .disabled(session.busy)

            Button(isSignUp ? "Already have an account? Log in" : "New here? Sign up") {
                isSignUp.toggle(); session.errorMessage = nil
            }.font(.footnote)
            Spacer()
        }
        .padding(28)
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .keyboardType(title == "Email" ? .emailAddress : .default)
            .padding(12).background(Color(.secondarySystemBackground)).cornerRadius(10)
    }
}
