import Foundation

enum TransactionType: String {
    case credit = "Credit (Income)"
    case debit = "Debit (Expense)"
    case unknown = "Unknown"
}

struct Transaction {
    var type: TransactionType
    var amount: String?
    var merchant: String?
    var category: String?
    var transactionID: String?
    var date: String?
    var accountNumber: String?
    var confidence: Double

    init(
        type: TransactionType = .unknown,
        amount: String? = nil,
        merchant: String? = nil,
        category: String? = nil,
        transactionID: String? = nil,
        date: String? = nil,
        accountNumber: String? = nil,
        confidence: Double = 0.0
    ) {
        self.type = type
        self.amount = amount
        self.merchant = merchant
        self.category = category
        self.transactionID = transactionID
        self.date = date
        self.accountNumber = accountNumber
        self.confidence = confidence
    }
}
