import Foundation
import NaturalLanguage

class TransactionParser {

    private let merchantCategorizer = MerchantCategorizer()

    func parse(text: String) -> Transaction {
        guard !text.isEmpty else {
            return Transaction(confidence: 0.0)
        }

        var transaction = Transaction()
        var confidenceScore: Double = 0.0
        var fieldsFound = 0

        // 1. Determine transaction type (credit/debit)
        transaction.type = extractTransactionType(from: text)
        if transaction.type != .unknown {
            fieldsFound += 1
        }

        // 2. Extract amount
        if let amount = extractAmount(from: text) {
            transaction.amount = amount
            fieldsFound += 1
        }

        // 3. Extract merchant using NL framework
        if let merchant = extractMerchant(from: text) {
            transaction.merchant = merchant
            fieldsFound += 1

            // 4. Categorize merchant
            transaction.category = merchantCategorizer.categorize(merchant: merchant)
        }

        // 5. Extract transaction ID
        if let txnID = extractTransactionID(from: text) {
            transaction.transactionID = txnID
            fieldsFound += 1
        }

        // 6. Extract date
        if let date = extractDate(from: text) {
            transaction.date = date
            fieldsFound += 1
        }

        // 7. Extract account number
        if let account = extractAccountNumber(from: text) {
            transaction.accountNumber = account
            fieldsFound += 1
        }

        // Calculate confidence based on fields found
        let totalFields = 6.0
        confidenceScore = Double(fieldsFound) / totalFields
        transaction.confidence = confidenceScore

        return transaction
    }

    // MARK: - Transaction Type Detection

    private func extractTransactionType(from text: String) -> TransactionType {
        let lowercased = text.lowercased()

        // Credit indicators
        let creditKeywords = ["credited", "credit", "received", "deposited", "deposit", "refund", "cashback"]
        for keyword in creditKeywords {
            if lowercased.contains(keyword) {
                return .credit
            }
        }

        // Debit indicators
        let debitKeywords = ["debited", "debit", "spent", "paid", "payment", "purchase", "withdrawn", "withdrawal"]
        for keyword in debitKeywords {
            if lowercased.contains(keyword) {
                return .debit
            }
        }

        return .unknown
    }

    // MARK: - Amount Extraction

    private func extractAmount(from text: String) -> String? {
        // Patterns for different currency formats
        let patterns = [
            #"(?:Rs\.?|INR|₹)\s*(\d+(?:,\d+)*(?:\.\d{2})?)"#,  // Indian Rupees
            #"\$\s*(\d+(?:,\d+)*(?:\.\d{2})?)"#,                // US Dollars
            #"USD\s*(\d+(?:,\d+)*(?:\.\d{2})?)"#,               // USD prefix
            #"(?:EUR|€)\s*(\d+(?:,\d+)*(?:\.\d{2})?)"#,         // Euros
            #"(?:GBP|£)\s*(\d+(?:,\d+)*(?:\.\d{2})?)"#,         // British Pounds
            #"(?:amount|amt)[\s:]+(?:Rs\.?|INR|₹)?\s*(\d+(?:,\d+)*(?:\.\d{2})?)"#  // Generic amount
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchedText = String(text[match])

                // Extract just the numeric part
                if let numMatch = matchedText.range(of: #"(\d+(?:,\d+)*(?:\.\d{2})?)"#, options: .regularExpression) {
                    let amount = String(matchedText[numMatch])

                    // Determine currency symbol
                    let currency = determineCurrency(from: matchedText)
                    return "\(currency)\(amount)"
                }
            }
        }

        return nil
    }

    private func determineCurrency(from text: String) -> String {
        if text.contains("$") || text.contains("USD") { return "$" }
        if text.contains("€") || text.contains("EUR") { return "€" }
        if text.contains("£") || text.contains("GBP") { return "£" }
        if text.contains("₹") || text.contains("Rs") || text.contains("INR") { return "₹" }
        return "₹" // Default to INR for Indian context
    }

    // MARK: - Merchant Extraction using Natural Language Framework

    private func extractMerchant(from text: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        var merchants: [String] = []

        // Extract organization names
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                            unit: .word,
                            scheme: .nameType,
                            options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if tag == .organizationName {
                let merchant = String(text[range])
                merchants.append(merchant)
            }
            return true
        }

        // If NL framework found merchants, return the first one
        if !merchants.isEmpty {
            return merchants.first
        }

        // Fallback: Look for common merchant patterns
        return extractMerchantFallback(from: text)
    }

    private func extractMerchantFallback(from text: String) -> String? {
        // Pattern: "at MERCHANT" or "to MERCHANT" or "from MERCHANT"
        let patterns = [
            #"(?:at|to|from)\s+([A-Z][A-Za-z0-9\s&'-]{2,30}?)(?:\s+on|\s+for|\s+via|\.|\n|$)"#,
            #"(?:merchant|vendor)[\s:]+([A-Z][A-Za-z0-9\s&'-]{2,30}?)(?:\s+on|\s+for|\.|\n|$)"#
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression),
               let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsText = text as NSString
                let nsRange = NSRange(match, in: text)

                if let matchResult = regex.firstMatch(in: text, range: nsRange),
                   matchResult.numberOfRanges > 1 {
                    let merchantRange = matchResult.range(at: 1)
                    if merchantRange.location != NSNotFound {
                        let merchant = nsText.substring(with: merchantRange)
                        return merchant.trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Transaction ID Extraction

    private func extractTransactionID(from text: String) -> String? {
        let patterns = [
            #"(?:txn|transaction|trans|ref|reference|utr)[\s#:No\.]*([A-Z0-9]{8,})"#,
            #"(?:ID|Id)[\s:#]*([A-Z0-9]{8,})"#,
            #"\b([A-Z]{2,}\d{6,})\b"#  // Pattern like ABC123456789
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression),
               let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsText = text as NSString
                let nsRange = NSRange(match, in: text)

                if let matchResult = regex.firstMatch(in: text, range: nsRange),
                   matchResult.numberOfRanges > 1 {
                    let idRange = matchResult.range(at: 1)
                    if idRange.location != NSNotFound {
                        return nsText.substring(with: idRange)
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Date Extraction

    private func extractDate(from text: String) -> String? {
        // Use Data Detector to find dates
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let nsText = text as NSString
        let matches = detector?.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        if let match = matches?.first, let date = match.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }

        // Fallback: Look for date patterns
        let patterns = [
            #"\b(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})\b"#,  // DD/MM/YYYY or MM/DD/YYYY
            #"\b(\d{2,4}[-/]\d{1,2}[-/]\d{1,2})\b"#,  // YYYY/MM/DD
            #"(?:on|date)[\s:]+(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})"#
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                return String(text[match])
            }
        }

        return nil
    }

    // MARK: - Account Number Extraction

    private func extractAccountNumber(from text: String) -> String? {
        let patterns = [
            #"(?:a\/c|account|acc|card)[\s#:No\.]*(?:ending|ending in|xxxx|xx)?[\s]*(\d{4,})"#,
            #"(?:xx|XX)(\d{4})\b"#  // Last 4 digits pattern
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression),
               let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsText = text as NSString
                let nsRange = NSRange(match, in: text)

                if let matchResult = regex.firstMatch(in: text, range: nsRange),
                   matchResult.numberOfRanges > 1 {
                    let accountRange = matchResult.range(at: 1)
                    if accountRange.location != NSNotFound {
                        let account = nsText.substring(with: accountRange)
                        return "****\(account)"
                    }
                }
            }
        }

        return nil
    }
}
