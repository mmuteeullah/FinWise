import Foundation

struct SmsMessage: Codable {
    let text: String
    let sender: String
    let receivedAt: String
    let id: String
}

class SharedStorageManager {
    static let shared = SharedStorageManager()
    private let appGroupId = "group.com.example.smsFetcherFlutter"
    private let messagesKey = "sms_messages"

    private init() {}

    var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupId)
    }

    // Save a new message
    func saveMessage(text: String) {
        guard let defaults = sharedDefaults else {
            print("❌ Failed to access shared UserDefaults")
            return
        }

        var messages = getAllMessages()

        // Auto-generate timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let receivedAt = dateFormatter.string(from: Date())

        let newMessage = SmsMessage(
            text: text,
            sender: receivedAt, // Use timestamp as the "sender" field (displayed as title)
            receivedAt: receivedAt,
            id: UUID().uuidString
        )

        messages.insert(newMessage, at: 0) // Add to beginning

        // Keep only last 100 messages
        if messages.count > 100 {
            messages = Array(messages.prefix(100))
        }

        if let encoded = try? JSONEncoder().encode(messages) {
            defaults.set(encoded, forKey: messagesKey)
            defaults.synchronize()
            print("✅ Message saved to shared storage")
        } else {
            print("❌ Failed to encode messages")
        }
    }

    // Get all messages
    func getAllMessages() -> [SmsMessage] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: messagesKey),
              let messages = try? JSONDecoder().decode([SmsMessage].self, from: data) else {
            return []
        }
        return messages
    }

    // Clear all messages
    func clearMessages() {
        sharedDefaults?.removeObject(forKey: messagesKey)
        sharedDefaults?.synchronize()
    }
}
