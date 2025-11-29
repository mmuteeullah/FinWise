import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import 'exchange_rate_service.dart';
import 'remote_logger.dart';
import 'secure_storage_service.dart';
import 'category_service.dart';

enum LLMProvider { openRouter, nvidia }

class LLMService {
  // API endpoints
  static const String _openRouterUrl =
      'https://openrouter.ai/api/v1/chat/completions';
  static const String _nvidiaUrl =
      'https://integrate.api.nvidia.com/v1/chat/completions';

  // SharedPreferences keys
  static const String _selectedModelKey = 'llm_selected_model';
  static const String _enabledKey = 'llm_enabled';
  static const String _customModelsKey = 'llm_custom_models';
  static const String _apiCallCountKey = 'llm_api_call_count';
  static const String _lastErrorKey = 'llm_last_error';
  static const String _providerKey = 'llm_provider';
  static const String _visionParsingEnabledKey = 'llm_vision_parsing_enabled';
  static const String _visionModelKey = 'llm_vision_model';

  // Default models by provider
  static const Map<LLMProvider, List<String>> defaultModelsByProvider = {
    LLMProvider.openRouter: [
      'qwen/qwen3-coder:free',
      'google/gemma-3-27b-it:free',
    ],
    LLMProvider.nvidia: [
      'google/gemma-3-1b-it',
      'meta/llama-3.1-8b-instruct',
      'mistralai/mistral-7b-instruct-v0.3',
    ],
  };

  // Vision-capable models by provider
  static const Map<LLMProvider, List<String>> visionModelsByProvider = {
    LLMProvider.openRouter: [
      'google/gemini-2.0-flash-exp:free',
      'anthropic/claude-3-sonnet',
      'openai/gpt-4o',
    ],
    LLMProvider.nvidia: [
      'meta/llama-3.2-11b-vision-instruct',
      'meta/llama-3.2-90b-vision-instruct',
      'microsoft/phi-3.5-vision-instruct',
      'microsoft/phi-4-multimodal-instruct',
    ],
  };

  // Singleton pattern
  static final LLMService _instance = LLMService._internal();
  factory LLMService() => _instance;
  LLMService._internal();

  // Secure storage service
  final SecureStorageService _secureStorage = SecureStorageService();

  // Get current provider
  Future<LLMProvider> getProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final providerIndex = prefs.getInt(_providerKey) ?? 0;
    return LLMProvider.values[providerIndex];
  }

  // Save provider
  Future<bool> saveProvider(LLMProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setInt(_providerKey, provider.index);
  }

  // Get base URL for current provider
  Future<String> _getBaseUrl() async {
    final provider = await getProvider();
    return provider == LLMProvider.openRouter ? _openRouterUrl : _nvidiaUrl;
  }

  // Get default models for current provider
  Future<List<String>> getDefaultModels() async {
    final provider = await getProvider();
    return defaultModelsByProvider[provider] ?? [];
  }

  // Get vision models for current provider
  Future<List<String>> getVisionModels() async {
    final provider = await getProvider();
    return visionModelsByProvider[provider] ?? [];
  }

  // Check if a model is vision-capable
  bool isVisionModel(String modelName) {
    return visionModelsByProvider.values.any(
      (models) => models.contains(modelName),
    );
  }

  // Get all default models (for reference)
  static List<String> get allDefaultModels {
    return defaultModelsByProvider.values.expand((models) => models).toList();
  }

  // Get API key (from secure storage based on current provider)
  Future<String?> getApiKey() async {
    final provider = await getProvider();
    if (provider == LLMProvider.openRouter) {
      return await _secureStorage.getOpenRouterApiKey();
    } else {
      return await _secureStorage.getNvidiaApiKey();
    }
  }

  // Save API key (to secure storage based on current provider)
  Future<bool> saveApiKey(String apiKey) async {
    try {
      final provider = await getProvider();
      if (provider == LLMProvider.openRouter) {
        await _secureStorage.saveOpenRouterApiKey(apiKey);
      } else {
        await _secureStorage.saveNvidiaApiKey(apiKey);
      }
      return true;
    } catch (e) {
      print('Error saving API key: $e');
      return false;
    }
  }

  // Get selected model
  Future<String> getSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultModels = await getDefaultModels();
    return prefs.getString(_selectedModelKey) ??
        (defaultModels.isNotEmpty ? defaultModels[0] : '');
  }

  // Save selected model
  Future<bool> saveSelectedModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_selectedModelKey, model);
  }

  // Get LLM enabled status
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  // Set LLM enabled status
  Future<bool> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setBool(_enabledKey, enabled);
  }

  // Get custom models
  Future<List<String>> getCustomModels() async {
    final prefs = await SharedPreferences.getInstance();
    final customModelsJson = prefs.getString(_customModelsKey);
    if (customModelsJson == null) return [];
    return List<String>.from(jsonDecode(customModelsJson));
  }

  // Add custom model
  Future<bool> addCustomModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    final customModels = await getCustomModels();
    if (!customModels.contains(model)) {
      customModels.add(model);
      return await prefs.setString(_customModelsKey, jsonEncode(customModels));
    }
    return true;
  }

  // Remove custom model
  Future<bool> removeCustomModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    final customModels = await getCustomModels();
    customModels.remove(model);
    return await prefs.setString(_customModelsKey, jsonEncode(customModels));
  }

  // Get all available models for current provider
  Future<List<String>> getAllModels() async {
    final defaultModels = await getDefaultModels();
    final customModels = await getCustomModels();
    return [...defaultModels, ...customModels];
  }

  // Get API call count
  Future<int> getApiCallCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_apiCallCountKey) ?? 0;
  }

  // Increment API call count
  Future<void> _incrementApiCallCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = await getApiCallCount();
    await prefs.setInt(_apiCallCountKey, count + 1);
  }

  // Reset API call count
  Future<bool> resetApiCallCount() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setInt(_apiCallCountKey, 0);
  }

  // Save last error
  Future<void> _saveLastError(String error) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastErrorKey, error);
  }

  // Get last error
  Future<String?> getLastError() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastErrorKey);
  }

  // Get vision parsing enabled status
  Future<bool> isVisionParsingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_visionParsingEnabledKey) ?? false;
  }

  // Set vision parsing enabled status
  Future<bool> setVisionParsingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setBool(_visionParsingEnabledKey, enabled);
  }

  // Get selected vision model
  Future<String?> getSelectedVisionModel() async {
    final prefs = await SharedPreferences.getInstance();
    final savedModel = prefs.getString(_visionModelKey);

    // If no saved model, return first available vision model
    if (savedModel == null || savedModel.isEmpty) {
      final visionModels = await getVisionModels();
      return visionModels.isNotEmpty ? visionModels[0] : null;
    }

    return savedModel;
  }

  // Save selected vision model
  Future<bool> saveSelectedVisionModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_visionModelKey, model);
  }

  // Test connection with a simple prompt
  Future<Map<String, dynamic>> testConnection() async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return {'success': false, 'error': 'API key not configured'};
    }

    final model = await getSelectedModel();
    final baseUrl = await _getBaseUrl();

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': 'Say "Hello from FinWise" if you can read this.',
            },
          ],
        }),
      );

      await _incrementApiCallCount();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return {'success': true, 'response': content, 'model': model};
      } else {
        final error = 'API Error ${response.statusCode}: ${response.body}';
        await _saveLastError(error);
        return {'success': false, 'error': error};
      }
    } catch (e) {
      final error = 'Connection Error: $e';
      await _saveLastError(error);
      return {'success': false, 'error': error};
    }
  }

  // STEP 1: Extract clean transaction text from noisy email/SMS content
  /// Takes raw email/SMS content with noise (disclaimers, footers, etc.)
  /// Returns just the 1-2 sentences containing actual transaction information
  Future<Map<String, dynamic>> extractTransactionText(String rawContent) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      RemoteLogger.error('LLM API key not configured', tag: 'LLM_EXTRACT');
      return {'success': false, 'error': 'API key not configured'};
    }

    final model = await getSelectedModel();
    final baseUrl = await _getBaseUrl();
    final provider = await getProvider();
    final startTime = DateTime.now();

    RemoteLogger.divider('LLM EXTRACTION - STEP 1');
    RemoteLogger.info('Provider: ${provider.name}', tag: 'LLM_EXTRACT');
    RemoteLogger.info('Model: $model', tag: 'LLM_EXTRACT');
    RemoteLogger.info('Input length: ${rawContent.length} characters', tag: 'LLM_EXTRACT');

    try {
      final prompt = '''You are a transaction text extractor. Your job is to find and extract ONLY the transaction information from an email or SMS.

TASK: Extract the 1-2 sentences that contain the actual transaction details.

WHAT TO EXTRACT:
✓ Transaction amount (INR 15.00, Rs. 500, USD 25, etc.)
✓ Transaction date and time
✓ Card number or account reference (XX9006, A/C 1234, etc.)
✓ Merchant name or transaction details
✓ Transaction ID or reference number
✓ UPI information if present

WHAT TO IGNORE:
✗ Email greetings ("Dear Customer", "Hello", "Hi")
✗ Disclaimers and legal text
✗ Contact information
✗ Footer text
✗ "If you have questions..." type text
✗ Balance or limit information (only extract the transaction amount)
✗ Marketing content
✗ Email signatures

EXAMPLES:

Input:
"""
Subject: Transaction alert for your ICICI Bank Credit Card

Dear Customer,

Your ICICI Bank Credit Card XX9006 has been used for a transaction of INR 15.00 on Nov 16, 2025 at 10:07:13. Info: UPI-532029754318-PARAS SI.

The available credit limit on your card is Rs. 50,000.00.

In case of any issue, please contact us at...
"""

Output:
"""
Your ICICI Bank Credit Card XX9006 has been used for a transaction of INR 15.00 on Nov 16, 2025 at 10:07:13. Info: UPI-532029754318-PARAS SI.
"""

---

Input:
"""
Subject: You spent Rs 850 via UPI

Hello,

You paid Rs 850 via UPI to merchant@paytm. UPI Ref: 12345678901. Date: 15-Mar-25.

Thank you for using our service. For support...
"""

Output:
"""
You paid Rs 850 via UPI to merchant@paytm. UPI Ref: 12345678901. Date: 15-Mar-25.
"""

---

NOW EXTRACT FROM THIS CONTENT:

$rawContent

---

INSTRUCTIONS:
1. Find the sentence(s) with transaction information
2. Return ONLY those sentences - nothing else
3. Do not add explanations or formatting
4. Do not include subject line unless it contains transaction details
5. Keep the text exactly as written - don't paraphrase

Return just the extracted transaction text (no JSON, no markdown, just plain text):''';

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      await _incrementApiCallCount();
      final extractTime = DateTime.now().difference(startTime).inMilliseconds / 1000.0;

      RemoteLogger.info('Response status: ${response.statusCode}', tag: 'LLM_EXTRACT');
      RemoteLogger.info('Extract time: ${extractTime.toStringAsFixed(2)}s', tag: 'LLM_EXTRACT');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final extractedText = (data['choices'][0]['message']['content'] as String).trim();

        RemoteLogger.info('✅ Extracted text: "$extractedText"', tag: 'LLM_EXTRACT');

        return {
          'success': true,
          'extractedText': extractedText,
          'model': model,
          'extractTime': extractTime,
        };
      } else {
        final error = 'API Error ${response.statusCode}: ${response.body}';
        RemoteLogger.error('Extraction failed', error: error, tag: 'LLM_EXTRACT');
        await _saveLastError(error);
        return {'success': false, 'error': error};
      }
    } catch (e) {
      final error = 'LLM Extraction Error: $e';
      RemoteLogger.error('Exception during extraction', error: e, tag: 'LLM_EXTRACT');
      await _saveLastError(error);
      return {'success': false, 'error': error};
    }
  }

  // STEP 2: Parse SMS using LLM
  Future<Map<String, dynamic>> parseSMS(String smsText) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      RemoteLogger.error('LLM API key not configured', tag: 'LLM');
      return {'success': false, 'error': 'API key not configured'};
    }

    final model = await getSelectedModel();
    final baseUrl = await _getBaseUrl();
    final provider = await getProvider();
    final startTime = DateTime.now();

    // Fetch active categories dynamically
    final categoryService = CategoryService.instance;
    final categories = await categoryService.getActiveCategoryNames();
    final categoryList = categories.join(', ');

    RemoteLogger.divider('LLM PARSING REQUEST');
    RemoteLogger.info('Provider: ${provider.name}', tag: 'LLM');
    RemoteLogger.info('Model: $model', tag: 'LLM');
    RemoteLogger.info('Active categories: $categoryList', tag: 'LLM');
    RemoteLogger.info('Input text: "$smsText"', tag: 'LLM');
    RemoteLogger.info('Text length: ${smsText.length} characters', tag: 'LLM');

    try {
      final prompt =
          '''You are a bank transaction parser. Extract transaction details from the text and return ONLY valid JSON.

The input text is CLEAN and contains ONLY transaction information - no noise or disclaimers.

STEP 1: UNDERSTAND THE TRANSACTION TYPE (CRITICAL)
Ask yourself: "Is money leaving MY account or entering MY account?"

- DEBIT = Money LEAVING my account (I spent/paid/transferred money out)
  Examples of debit indicators:
  • "debited from your account"
  • "spent using your card"
  • "paid to merchant"
  • "withdrawn from account"
  • "transferred to [someone]"
  • "purchase at [merchant]"

- CREDIT = Money ENTERING my account (I received money)
  Examples of credit indicators:
  • "credited to your account"
  • "received from [someone]"
  • "refund credited"
  • "salary credited"
  • "cashback credited"

IMPORTANT: Ignore the DESTINATION of the money. Focus only on YOUR account's perspective.
- "debited from Card XX2008 and credited to Amazon" → DEBIT (money left your card)
- "debited from John's account and credited to your account" → CREDIT (money entered your account)

STEP 2: EXTRACT CARD/ACCOUNT DETAILS
Priority order (IMPORTANT - check in this order):
1. Look for explicit card/account patterns FIRST (highest priority):
   • "Card XX2008" → extract "2008"
   • "Credit Card XX9006" → extract "9006"
   • "Card ending 2008" → extract "2008"
   • "A/C XX1234" → extract "1234"
   • "Account **5678" → extract "5678"

2. If NO card found, check if it's a UPI-only transaction:
   • Contains "UPI", "UPI ID", "UPI Ref", "@paytm", "@ybl", "@oksbi", "@icici", "@axisbank", etc.
   • AND no card number in the text
   • Set account_last_digits to "XUPI"

3. If neither found → set account_last_digits to null

NOTE: If BOTH card number AND UPI are present (e.g., "Card XX9006...Info: UPI-xxx"),
use the CARD NUMBER, not "XUPI".

STEP 3: EXTRACT OTHER FIELDS
Follow the JSON schema below with extracted values.

SPECIAL HANDLING FOR EMAIL TRANSACTIONS:
• Merchant extraction from "Info: ..." field:
  - "Info: UPI-532029754318-PARAS SI" → merchant = "PARAS SI", transaction_id = "532029754318"
  - "Info: AMAZON.IN" → merchant = "AMAZON.IN"
  - "Info: SWIGGY BANGALORE" → merchant = "SWIGGY BANGALORE"
  - Extract ONLY the merchant name, NOT the UPI ID or transaction ID

• Date/Time formats:
  - "Nov 16, 2025 at 10:07:13" → "2025-11-16"
  - "16-Nov-2025 10:07:13" → "2025-11-16"
  - "16/11/2025 10:07 AM" → "2025-11-16"
  - Parse full date-time but return only YYYY-MM-DD

• Ignore these fields completely:
  - "Available Credit Limit"
  - "Total Credit Limit"
  - "Available Balance"
  - Any limit/balance information
  - Only extract the TRANSACTION AMOUNT (credited or debited)

---

RETURN THIS JSON FORMAT (no markdown, no explanation):
{
  "transaction_id": "Extract UPI ID, reference number, or transaction ID. For 'Info: UPI-532029754318-MERCHANT', extract '532029754318'. Look for 8+ digit numbers. Null if not found.",
  "amount": "EXACT numeric transaction amount from text (e.g., 2500.00). Remove commas and currency symbols.",
  "merchant": "Merchant/recipient name from 'Info:' field or transaction text. For 'Info: UPI-xxx-MERCHANT NAME', extract only 'MERCHANT NAME'. Clean up extra spaces.",
  "type": "MUST be 'debit' or 'credit'. Use STEP 1 logic above - focus on YOUR account perspective.",
  "category": "Classify as: $categoryList",
  "date": "Convert to YYYY-MM-DD format. Parse 'Nov 16, 2025 at 10:07:13', 'DD-MMM-YY', 'DD/MM/YYYY', etc. Use current date if not found.",
  "currency": "Extract currency code (INR, USD, EUR, AED, GBP). Default to INR if not specified.",
  "account_last_digits": "Use STEP 2 logic above. Last 4 digits of card/account (prioritize card over UPI), or 'XUPI' for UPI-only, or null if not found.",
  "confidence": "Your confidence level from 0.0 (low) to 1.0 (high)"
}

---

EXAMPLES TO LEARN FROM:

Example 1 (DEBIT - Money leaving account):
Text: "Rs 1,400.00 spent using ICICI Bank Card XX2008 on 25-Sep-25 at ZOMATO."
Reasoning: "spent" = money left my account → DEBIT
JSON:
{
  "transaction_id": null,
  "amount": 1400.00,
  "merchant": "ZOMATO",
  "type": "debit",
  "category": "Food & Dining",
  "date": "2025-09-25",
  "currency": "INR",
  "account_last_digits": "2008",
  "confidence": 0.95
}

Example 2 (DEBIT - Card transaction with confusing wording):
Text: "INR 2,500.00 debited from Card XX2008 and credited to Amazon on 21-Oct-25."
Reasoning: Money "debited from Card XX2008" = left MY card → DEBIT (ignore "credited to Amazon")
JSON:
{
  "transaction_id": null,
  "amount": 2500.00,
  "merchant": "Amazon",
  "type": "debit",
  "category": "Shopping",
  "date": "2025-10-21",
  "currency": "INR",
  "account_last_digits": "2008",
  "confidence": 0.95
}

Example 3 (CREDIT - Money entering account):
Text: "Rs 5,000.00 credited to your A/C XX1234 from Employer on 01-Jan-25. Salary payment."
Reasoning: Money "credited to your A/C" = entered MY account → CREDIT
JSON:
{
  "transaction_id": null,
  "amount": 5000.00,
  "merchant": "Employer",
  "type": "credit",
  "category": "Salary",
  "date": "2025-01-01",
  "currency": "INR",
  "account_last_digits": "1234",
  "confidence": 0.95
}

Example 4 (DEBIT - UPI transaction):
Text: "Rs 850 paid via UPI to merchant@paytm. UPI Ref: 12345678901. Date: 15-Mar-25."
Reasoning: "paid via UPI" = money left my account → DEBIT. UPI transaction → use "XUPI" marker.
JSON:
{
  "transaction_id": "12345678901",
  "amount": 850.00,
  "merchant": "merchant@paytm",
  "type": "debit",
  "category": "Other",
  "date": "2025-03-15",
  "currency": "INR",
  "account_last_digits": "XUPI",
  "confidence": 0.9
}

Example 5 (CREDIT - Refund):
Text: "Refund of Rs 1,200 credited to Card XX5678 on 10-Feb-25 from Flipkart."
Reasoning: "Refund credited to Card" = money returned to MY card → CREDIT
JSON:
{
  "transaction_id": null,
  "amount": 1200.00,
  "merchant": "Flipkart",
  "type": "credit",
  "category": "Shopping",
  "date": "2025-02-10",
  "currency": "INR",
  "account_last_digits": "5678",
  "confidence": 0.95
}

Example 6 (DEBIT - Email with Info field and UPI):
Text: "Your ICICI Bank Credit Card XX9006 has been used for a transaction of INR 15.00 on Nov 16, 2025 at 10:07:13. Info: UPI-532029754318-PARAS SI."
Reasoning:
- "has been used for" = money left my account → DEBIT
- Card XX9006 found → use "9006" (priority over UPI)
- Extract merchant from "Info: UPI-xxx-PARAS SI" → "PARAS SI"
- Extract UPI transaction ID "532029754318"
- Parse date "Nov 16, 2025 at 10:07:13" → "2025-11-16"
JSON:
{
  "transaction_id": "532029754318",
  "amount": 15.00,
  "merchant": "PARAS SI",
  "type": "debit",
  "category": "Other",
  "date": "2025-11-16",
  "currency": "INR",
  "account_last_digits": "9006",
  "confidence": 0.95
}

Example 7 (DEBIT - International transaction):
Text: "Your ICICI Bank Card XX5432 has been used for USD 125.50 on Nov 17, 2025 at AMAZON.COM"
Reasoning: "has been used for" = money left my account → DEBIT, USD currency
JSON:
{
  "transaction_id": null,
  "amount": 125.50,
  "merchant": "AMAZON.COM",
  "type": "debit",
  "category": "Shopping",
  "date": "2025-11-17",
  "currency": "USD",
  "account_last_digits": "5432",
  "confidence": 0.95
}

---

NOW PARSE THIS TRANSACTION:

"$smsText"

---

FINAL CHECKS BEFORE RETURNING JSON:
1. ✓ Does "type" match the money flow from MY account perspective?
2. ✓ Did I prioritize CARD NUMBER over UPI marker (if both present)?
3. ✓ Did I extract merchant from "Info:" field correctly (no UPI ID included)?
4. ✓ Did I extract UPI transaction ID separately (not in merchant)?
5. ✓ Is amount a plain number without commas?
6. ✓ Is date in YYYY-MM-DD format?

Return ONLY the JSON object - no markdown, no explanation:''';

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      await _incrementApiCallCount();
      final parseTime =
          DateTime.now().difference(startTime).inMilliseconds / 1000.0;

      RemoteLogger.info('Response status: ${response.statusCode}', tag: 'LLM');
      RemoteLogger.info(
        'Parse time: ${parseTime.toStringAsFixed(2)}s',
        tag: 'LLM',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;

        RemoteLogger.info('Raw LLM response: $content', tag: 'LLM');

        // Extract JSON from response (handle markdown code blocks if present)
        String jsonStr = content.trim();
        if (jsonStr.startsWith('```json')) {
          jsonStr = jsonStr.substring(7);
        } else if (jsonStr.startsWith('```')) {
          jsonStr = jsonStr.substring(3);
        }
        if (jsonStr.endsWith('```')) {
          jsonStr = jsonStr.substring(0, jsonStr.length - 3);
        }
        jsonStr = jsonStr.trim();

        RemoteLogger.debug('Extracted JSON: $jsonStr', tag: 'LLM');

        try {
          final parsedData = jsonDecode(jsonStr);
          RemoteLogger.info('✅ Successfully parsed JSON', tag: 'LLM');
          RemoteLogger.info('Parsed data: $parsedData', tag: 'LLM');

          return {
            'success': true,
            'data': parsedData,
            'model': model,
            'parseTime': parseTime,
            'rawResponse': content,
          };
        } catch (e) {
          final error = 'JSON Parse Error: $e. Raw response: $content';
          RemoteLogger.error('JSON parsing failed', error: e, tag: 'LLM');
          RemoteLogger.error('Failed to parse: $content', tag: 'LLM');
          await _saveLastError(error);
          return {'success': false, 'error': error, 'rawResponse': content};
        }
      } else {
        final error = 'API Error ${response.statusCode}: ${response.body}';
        RemoteLogger.error('API request failed', error: error, tag: 'LLM');
        await _saveLastError(error);
        return {'success': false, 'error': error};
      }
    } catch (e) {
      final error = 'LLM Parsing Error: $e';
      RemoteLogger.error('Exception during LLM parsing', error: e, tag: 'LLM');
      await _saveLastError(error);
      return {'success': false, 'error': error};
    }
  }

  // Parse PDF page image using vision model
  /// Sends a base64-encoded PDF page image to a vision model for transaction extraction
  /// Returns a list of transactions found in the image
  Future<Map<String, dynamic>> parsePDFPageImage(
    String base64Image, {
    String? visionModel,
    int pageNumber = 1,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      RemoteLogger.error('LLM API key not configured', tag: 'LLM_VISION');
      return {'success': false, 'error': 'API key not configured'};
    }

    // Use provided vision model or get first available vision model
    String model = visionModel ?? '';
    if (model.isEmpty) {
      final visionModels = await getVisionModels();
      if (visionModels.isEmpty) {
        return {
          'success': false,
          'error': 'No vision models available for current provider',
        };
      }
      model = visionModels[0]; // Use first available vision model
    }

    final baseUrl = await _getBaseUrl();
    final provider = await getProvider();
    final startTime = DateTime.now();

    // Fetch active categories dynamically
    final categoryService = CategoryService.instance;
    final categories = await categoryService.getActiveCategoryNames();
    final categoryList = categories.join(', ');

    RemoteLogger.divider('VISION LLM PDF PARSING');
    RemoteLogger.info('Provider: ${provider.name}', tag: 'LLM_VISION');
    RemoteLogger.info('Model: $model', tag: 'LLM_VISION');
    RemoteLogger.info('Active categories: $categoryList', tag: 'LLM_VISION');
    RemoteLogger.info('Page number: $pageNumber', tag: 'LLM_VISION');
    RemoteLogger.info(
      'Image size: ${(base64Image.length * 0.75 / 1024).toStringAsFixed(2)} KB',
      tag: 'LLM_VISION',
    );

    try {
      final prompt =
          '''You are analyzing a bank statement image. Your task is to extract ALL transactions from the MAIN transaction table EXACTLY as they appear in the image.

CRITICAL INSTRUCTIONS:
1. ONLY extract from the TRANSACTION TABLE (usually on first page with columns: Date, SerNo., Transaction Details, Amount)
2. DO NOT extract from example tables, calculation tables, or illustrations
3. Read the EXACT text from the image - DO NOT make up or guess merchant names
4. Copy merchant names EXACTLY as shown (e.g., "IND*AMAZON.IN - GROCER" not just "AMAZON")
5. When the image is given to you make sure you extract what make sense.

The transaction table has these columns:
- Date column: actual dates like 06/04/2025, 08/04/2025
- Serial No. column: 8+ digit numbers like 11042380485, 11061188165
- Transaction Details column: EXACT merchant text (e.g., "AMAZON INDIA CYBS SI MUMBAI IN", "IND*AMAZON GIFT CARD")
- Amount column: transaction amounts (may end with "CR" for credits)

IMPORTANT: Read merchant names character-by-character from the image. Do not substitute or simplify them.

Return a JSON object in this EXACT format:
{
  "transactions": [
    {
      "transaction_id": "transaction ID or reference number (string, 8+ digits)",
      "date": "transaction date in YYYY-MM-DD format",
      "merchant": "EXACT merchant text from Transaction Details column - copy it verbatim",
      "amount": "numeric amount WITHOUT commas (e.g., 1500.50 not 1,500.50)",
      "type": "debit or credit",
      "category": "one of: $categoryList",
      "account_last_digits": "last 4 digits of card/account if visible (optional)",
      "confidence": 0.0 to 1.0
    }
  ]
}

IMPORTANT RULES:
1. Look at the TABLE STRUCTURE - typical columns are: Date | SerNo. | Transaction Details | Reward Points | Intl.# | Amount
2. Extract transaction_id from SerNo column (8+ digit numbers like 11042380485)
3. Extract amount from the RIGHTMOST "Amount (in₹)" column - NOT from "Reward Points" column!
6. If amount has "CR" suffix, set type to "credit", otherwise "debit"
7. Amount must be a plain number WITHOUT commas (e.g., 1500.50 not 1,500.50)
8. Return an empty transactions array if this page has no actual transactions
9. Set confidence based on how clearly you can read the values


EXAMPLE OUTPUT FORMAT:

Your JSON output should be:
{
  "transaction_id": "11088659300",
  "date": "2025-04-13",
  "merchant": "IND*AMAZON.IN - GROCER HTTP://WWW.AM IN",
  "amount": 698.00,
  "type": "debit",
  "category": "Groceries",
  "account_last_digits": "0001",
  "confidence": 0.9
}

Notice how:
- Date 13/04/2025 becomes "2025-04-13" (YYYY-MM-DD format, NOT "2025-13-04")
- Amount 698.00 is a number without commas
- Merchant name is copied exactly as it appears
- All field types match the schema (strings in quotes, numbers without quotes)
- Balance is NOT included (we don't need it)

CRITICAL: Your response MUST be ONLY valid JSON format - no markdown, no explanation text, no formatting.
Start your response with { and end with }. Do not wrap in ```json or any other formatting.''';

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/png;base64,$base64Image'},
                },
              ],
            },
          ],
          'max_tokens': 4000, // Allow more tokens for multiple transactions
        }),
      );

      await _incrementApiCallCount();
      final parseTime =
          DateTime.now().difference(startTime).inMilliseconds / 1000.0;

      RemoteLogger.info(
        'Response status: ${response.statusCode}',
        tag: 'LLM_VISION',
      );
      RemoteLogger.info(
        'Parse time: ${parseTime.toStringAsFixed(2)}s',
        tag: 'LLM_VISION',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;

        RemoteLogger.info(
          'Raw vision LLM response: $content',
          tag: 'LLM_VISION',
        );

        // Extract JSON from response - handle multiple formats
        String jsonStr = content.trim();

        // Method 1: Remove markdown code blocks
        if (jsonStr.startsWith('```json')) {
          jsonStr = jsonStr.substring(7);
        } else if (jsonStr.startsWith('```')) {
          jsonStr = jsonStr.substring(3);
        }
        if (jsonStr.endsWith('```')) {
          jsonStr = jsonStr.substring(0, jsonStr.length - 3);
        }
        jsonStr = jsonStr.trim();

        // Method 2: If JSON still has extra text, try to find the JSON object
        if (!jsonStr.startsWith('{')) {
          // Look for the JSON object with transactions array - search for the largest valid JSON
          final openBrace = jsonStr.indexOf('{ "transactions":');
          if (openBrace >= 0) {
            // Find the matching closing brace for the transactions object
            int braceCount = 0;
            int endPos = openBrace;
            for (int i = openBrace; i < jsonStr.length; i++) {
              if (jsonStr[i] == '{') braceCount++;
              if (jsonStr[i] == '}') {
                braceCount--;
                if (braceCount == 0) {
                  endPos = i + 1;
                  break;
                }
              }
            }
            jsonStr = jsonStr.substring(openBrace, endPos);
            RemoteLogger.debug(
              'Extracted transactions object from text',
              tag: 'LLM_VISION',
            );
          } else {
            // Fallback: Try to find any JSON-like structure
            final anyOpenBrace = jsonStr.indexOf('{');
            if (anyOpenBrace >= 0) {
              // Find the matching closing brace
              int braceCount = 0;
              int endPos = anyOpenBrace;
              for (int i = anyOpenBrace; i < jsonStr.length; i++) {
                if (jsonStr[i] == '{') braceCount++;
                if (jsonStr[i] == '}') {
                  braceCount--;
                  if (braceCount == 0) {
                    endPos = i + 1;
                    break;
                  }
                }
              }
              jsonStr = jsonStr.substring(anyOpenBrace, endPos);
            }
          }
        }
        jsonStr = jsonStr.trim();

        // Method 3: Remove commas from numeric values (e.g., "26,000" -> "26000")
        // This regex finds patterns like "amount": 26,000 and removes the commas
        jsonStr = jsonStr.replaceAllMapped(
          RegExp(r'("amount":\s*)(\d{1,3}(?:,\d{3})+)'),
          (match) => '${match.group(1)}${match.group(2)!.replaceAll(',', '')}',
        );

        RemoteLogger.debug('Extracted JSON: $jsonStr', tag: 'LLM_VISION');

        try {
          final parsedData = jsonDecode(jsonStr);
          RemoteLogger.info('✅ Successfully parsed JSON', tag: 'LLM_VISION');

          // Handle different response formats
          List transactions = [];

          if (parsedData is Map && parsedData.containsKey('transactions')) {
            // Format 1: {"transactions": [...]}
            transactions = parsedData['transactions'] as List;
          } else if (parsedData is List) {
            // Format 2: [{...}, {...}] - LLM returned bare array
            transactions = parsedData;
            RemoteLogger.info(
              'LLM returned bare array, wrapping it',
              tag: 'LLM_VISION',
            );
          } else if (parsedData is Map &&
              !parsedData.containsKey('transactions')) {
            // Format 3: Single transaction object without wrapper
            transactions = [parsedData];
            RemoteLogger.info(
              'LLM returned single object, wrapping it',
              tag: 'LLM_VISION',
            );
          }

          RemoteLogger.info(
            'Found ${transactions.length} transactions in page $pageNumber',
            tag: 'LLM_VISION',
          );

          return {
            'success': true,
            'transactions': transactions,
            'model': model,
            'parseTime': parseTime,
            'pageNumber': pageNumber,
          };
        } catch (e) {
          final error = 'JSON Parse Error: $e. Raw response: $content';
          RemoteLogger.error(
            'JSON parsing failed',
            error: e,
            tag: 'LLM_VISION',
          );
          await _saveLastError(error);
          return {'success': false, 'error': error, 'rawResponse': content};
        }
      } else {
        final error = 'API Error ${response.statusCode}: ${response.body}';
        RemoteLogger.error(
          'Vision API request failed',
          error: error,
          tag: 'LLM_VISION',
        );
        await _saveLastError(error);
        return {'success': false, 'error': error};
      }
    } catch (e) {
      final error = 'Vision LLM Parsing Error: $e';
      RemoteLogger.error(
        'Exception during vision LLM parsing',
        error: e,
        tag: 'LLM_VISION',
      );
      await _saveLastError(error);
      return {'success': false, 'error': error};
    }
  }

  // Convert LLM response to Transaction object
  Future<Transaction?> responseToTransaction(
    Map<String, dynamic> llmResponse,
    String rawMessage,
  ) async {
    if (!llmResponse['success']) {
      RemoteLogger.warn(
        'LLM response was not successful, cannot convert to transaction',
        tag: 'LLM',
      );
      return null;
    }

    final data = llmResponse['data'];
    final parseTime = llmResponse['parseTime'] ?? 0.0;
    final model = llmResponse['model'] ?? 'unknown';

    RemoteLogger.divider('LLM TO TRANSACTION CONVERSION');
    RemoteLogger.info('Converting LLM data to Transaction object', tag: 'LLM');
    RemoteLogger.debug('Raw data: $data', tag: 'LLM');

    try {
      // Parse transaction type
      TransactionType type = TransactionType.unknown;
      if (data['type'] != null) {
        final typeStr = data['type'].toString().toLowerCase();
        if (typeStr == 'debit') {
          type = TransactionType.debit;
        } else if (typeStr == 'credit') {
          type = TransactionType.credit;
        }
      }

      // Parse date
      DateTime timestamp = DateTime.now();
      if (data['date'] != null) {
        try {
          timestamp = DateTime.parse(data['date']);
        } catch (e) {
          // Use current time if date parsing fails
          timestamp = DateTime.now();
        }
      }

      // Handle currency conversion
      final String currency = (data['currency']?.toString() ?? 'INR')
          .toUpperCase();

      // Parse amount - handle both numeric and string responses
      double? originalAmount;
      if (data['amount'] != null) {
        if (data['amount'] is num) {
          originalAmount = data['amount'].toDouble();
        } else {
          originalAmount = double.tryParse(data['amount'].toString());
        }
      }

      double? convertedAmount = originalAmount;
      String? originalCurrency;
      double? originalAmountStored;

      // If currency is not INR, convert it
      if (currency != 'INR' && originalAmount != null) {
        final exchangeRateService = ExchangeRateService.instance;
        convertedAmount = await exchangeRateService.convertToINR(
          originalAmount,
          currency,
        );
        originalCurrency = currency;
        originalAmountStored = originalAmount;
        print('💱 Converted $originalAmount $currency → ₹$convertedAmount INR');
      }

      // Parse balance - handle both numeric and string responses
      double? balance;
      if (data['balance'] != null) {
        if (data['balance'] is num) {
          balance = data['balance'].toDouble();
        } else {
          balance = double.tryParse(data['balance'].toString());
        }
      }

      // Parse confidence - handle both numeric and string responses
      double confidence = 0.5;
      if (data['confidence'] != null) {
        if (data['confidence'] is num) {
          confidence = data['confidence'].toDouble();
        } else {
          confidence = double.tryParse(data['confidence'].toString()) ?? 0.5;
        }
      }

      RemoteLogger.info('✅ Conversion successful!', tag: 'LLM');
      RemoteLogger.info('  Merchant: ${data['merchant']}', tag: 'LLM');
      RemoteLogger.info(
        '  Amount: ₹${convertedAmount?.toStringAsFixed(2)}',
        tag: 'LLM',
      );
      RemoteLogger.info(
        '  Type: ${type.toString().split('.').last}',
        tag: 'LLM',
      );
      RemoteLogger.info('  Date: $timestamp', tag: 'LLM');
      RemoteLogger.info(
        '  Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
        tag: 'LLM',
      );
      if (originalCurrency != null) {
        RemoteLogger.info(
          '  Original: $originalAmountStored $originalCurrency',
          tag: 'LLM',
        );
      }

      return Transaction(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        rawMessage: rawMessage,
        amount: convertedAmount,
        type: type,
        merchant: data['merchant']?.toString() ?? 'Unknown',
        category: data['category']?.toString() ?? 'Uncategorized',
        accountLastDigits: data['account_last_digits']?.toString(),
        balance: balance,
        timestamp: timestamp,
        isParsed: true,
        transactionId: data['transaction_id']?.toString(),
        parserConfidence: confidence,
        parserType: 'LLM:$model',
        parseTime: parseTime,
        originalCurrency: originalCurrency,
        originalAmount: originalAmountStored,
      );
    } catch (e) {
      RemoteLogger.error(
        '❌ Transaction conversion failed',
        error: e,
        tag: 'LLM',
      );
      _saveLastError('Transaction conversion error: $e');
      return null;
    }
  }

  // Get parsing stats
  Future<Map<String, dynamic>> getStats() async {
    final apiCallCount = await getApiCallCount();
    final lastError = await getLastError();
    final isEnabled = await this.isEnabled();
    final selectedModel = await getSelectedModel();
    final provider = await getProvider();

    return {
      'apiCallCount': apiCallCount,
      'lastError': lastError,
      'isEnabled': isEnabled,
      'selectedModel': selectedModel,
      'provider': provider.name,
    };
  }

  // Get provider display name
  static String getProviderDisplayName(LLMProvider provider) {
    switch (provider) {
      case LLMProvider.openRouter:
        return 'OpenRouter';
      case LLMProvider.nvidia:
        return 'NVIDIA';
    }
  }
}
