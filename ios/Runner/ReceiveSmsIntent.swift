import AppIntents
import Foundation

@available(iOS 16.0, *)
struct ReceiveSmsIntent: AppIntent {
    static var title: LocalizedStringResource = "Receive SMS"
    static var description = IntentDescription("Receives SMS message from Shortcuts")

    // Don't open app when running this intent - run in background
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Message", requestValueDialog: "What is the message?")
    var message: String

    static var parameterSummary: some ParameterSummary {
        Summary("Save SMS: \(\.$message)")
    }

    func perform() async throws -> some IntentResult {
        print("📱 ReceiveSmsIntent called")
        print("   Message: \(message)")

        // Save to shared storage (will auto-generate timestamp)
        SharedStorageManager.shared.saveMessage(text: message)

        return .result()
    }
}

// Make the intent available to Shortcuts
@available(iOS 16.0, *)
struct SmsFetcherAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ReceiveSmsIntent(),
            phrases: [
                "Receive SMS in \(.applicationName)"
            ],
            shortTitle: "Receive SMS",
            systemImageName: "message.fill"
        )
    }
}
