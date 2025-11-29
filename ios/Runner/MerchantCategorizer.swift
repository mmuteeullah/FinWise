import Foundation

class MerchantCategorizer {

    // Rule-based merchant categorization
    // In production, this could be replaced with a Core ML model

    private let categoryKeywords: [String: [String]] = [
        "Food & Dining": [
            "restaurant", "cafe", "coffee", "starbucks", "mcdonald", "burger", "pizza",
            "domino", "subway", "kfc", "food", "zomato", "swiggy", "ubereats",
            "dunkin", "taco", "wendy", "chipotle", "panera"
        ],
        "Groceries": [
            "walmart", "target", "costco", "whole foods", "safeway", "kroger",
            "grocery", "supermarket", "trader joe", "aldi", "publix",
            "big bazaar", "dmart", "reliance", "more", "store"
        ],
        "Transportation": [
            "uber", "lyft", "taxi", "cab", "gas", "fuel", "petrol", "shell",
            "bp", "chevron", "exxon", "ola", "rapido", "metro", "parking"
        ],
        "Entertainment": [
            "netflix", "spotify", "amazon prime", "hulu", "disney", "hbo",
            "movie", "cinema", "theater", "theatre", "youtube", "hotstar",
            "apple music", "gaming", "steam"
        ],
        "Shopping": [
            "amazon", "ebay", "flipkart", "myntra", "ajio", "shopping",
            "mall", "retail", "fashion", "clothing", "shoes", "nike", "adidas"
        ],
        "Utilities": [
            "electric", "electricity", "water", "gas company", "utility",
            "internet", "broadband", "wifi", "phone bill", "mobile",
            "at&t", "verizon", "t-mobile", "airtel", "jio", "vodafone"
        ],
        "Healthcare": [
            "pharmacy", "medical", "doctor", "hospital", "clinic", "cvs",
            "walgreens", "rite aid", "health", "dental", "apollo", "medplus"
        ],
        "Travel": [
            "airline", "flight", "hotel", "airbnb", "booking", "expedia",
            "travel", "makemytrip", "goibibo", "trip", "resort", "airport"
        ],
        "Education": [
            "school", "university", "college", "course", "udemy", "coursera",
            "education", "tuition", "learning", "academy", "institute"
        ],
        "Financial": [
            "bank", "insurance", "investment", "loan", "credit", "debit",
            "finance", "mutual fund", "trading", "zerodha", "groww"
        ],
        "Online Services": [
            "google", "apple", "microsoft", "adobe", "dropbox", "cloud",
            "subscription", "software", "app", "service"
        ]
    ]

    func categorize(merchant: String) -> String {
        let lowercased = merchant.lowercased()

        // Check each category's keywords
        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if lowercased.contains(keyword) {
                    return category
                }
            }
        }

        // Default category
        return "Other"
    }

    // Alternative: Fuzzy matching for better results
    func categorizeWithFuzzyMatch(merchant: String) -> String {
        let lowercased = merchant.lowercased()
        var bestMatch: (category: String, score: Double) = ("Other", 0.0)

        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                let similarity = calculateSimilarity(lowercased, keyword)
                if similarity > bestMatch.score {
                    bestMatch = (category, similarity)
                }
            }
        }

        // Only return category if confidence is above threshold
        return bestMatch.score > 0.7 ? bestMatch.category : "Other"
    }

    // Simple Levenshtein distance-based similarity
    private func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
        if s1.contains(s2) || s2.contains(s1) {
            return 1.0
        }

        let longer = s1.count > s2.count ? s1 : s2
        let shorter = s1.count > s2.count ? s2 : s1

        if longer.count == 0 {
            return 1.0
        }

        let editDistance = levenshteinDistance(shorter, longer)
        return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: s2Array.count + 1),
                            count: s1Array.count + 1)

        for i in 0...s1Array.count {
            matrix[i][0] = i
        }

        for j in 0...s2Array.count {
            matrix[0][j] = j
        }

        for i in 1...s1Array.count {
            for j in 1...s2Array.count {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }

        return matrix[s1Array.count][s2Array.count]
    }
}
