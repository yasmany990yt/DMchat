import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("darkMode") private var darkMode = false
    @AppStorage("readReceipts") private var readReceipts = true
    @AppStorage("typingIndicator") private var typingIndicator = true
    @State private var newPassword = ""
    @State private var note = ""
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("Username", value: "@" + (session.user?.username ?? ""))
                    SecureField("New password (6+ characters)", text: $newPassword)
                    Button("Change password") {
                        Task { note = await session.changePassword(newPassword); newPassword = "" }
                    }.disabled(newPassword.count < 6)
                }
                Section("Appearance") { Toggle("Dark mode", isOn: $darkMode) }
                Section("Privacy") {
                    Toggle("Send read receipts", isOn: $readReceipts)
                    Toggle("Show when I'm typing", isOn: $typingIndicator)
                }
                if !note.isEmpty { Section { Text(note).font(.footnote) } }
                Section {
                    Button("Log out") { dismiss(); session.signOut() }
                    Button("Delete account", role: .destructive) { confirmDelete = true }
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .alert("Delete your account?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) { Task { note = await session.deleteAccount() } }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This can't be undone.") }
        }
    }
}
