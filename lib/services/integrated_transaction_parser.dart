import '../models/transaction.dart';
import '../models/parsing_result.dart';
import 'llm_service.dart';
import 'transaction_parser.dart';

class IntegratedTransactionParser {
  final LLMService _llmService = LLMService();

  /// Parse SMS with LLM-first approach, fallback to regex
  Future<ParsingResult> parse(String smsText) async {
    final llmEnabled = await _llmService.isEnabled();

    // Try LLM parsing if enabled
    if (llmEnabled) {
      try {
        final llmResult = await _llmService.parseSMS(smsText);

        if (llmResult['success']) {
          // Convert LLM response to transaction
          final transaction = await _llmService.responseToTransaction(
            llmResult,
            smsText,
          );

          if (transaction != null) {
            // LLM parsing successful
            return ParsingResult.fromLLM(
              success: true,
              transaction: transaction,
              parseTime: llmResult['parseTime'],
              confidence: llmResult['data']['confidence'] ?? 0.8,
              modelUsed: llmResult['model'],
              rawResponse: llmResult['rawResponse'],
              data: llmResult['data'],
            );
          } else {
            // LLM returned data but conversion failed - fallback to regex
            return _fallbackToRegex(
              smsText,
              'LLM conversion failed',
            );
          }
        } else {
          // LLM parsing failed - fallback to regex
          return _fallbackToRegex(
            smsText,
            llmResult['error'] ?? 'LLM parsing failed',
          );
        }
      } catch (e) {
        // Exception during LLM parsing - fallback to regex
        return _fallbackToRegex(
          smsText,
          'LLM exception: $e',
        );
      }
    } else {
      // LLM not enabled - use regex directly
      return _useRegex(smsText);
    }
  }

  /// Fallback to regex parsing after LLM failure
  Future<ParsingResult> _fallbackToRegex(String smsText, String llmError) async {
    final startTime = DateTime.now();
    final transaction = await TransactionParser.parseAsync(smsText);
    final parseTime = DateTime.now().difference(startTime).inMilliseconds / 1000.0;

    // Update transaction with parser metadata
    final updatedTransaction = transaction.copyWith(
      parserType: 'Regex (LLM Failed)',
      parseTime: parseTime,
      parserConfidence: transaction.isParsed ? 0.7 : 0.3,
      parsingError: 'LLM: $llmError',
    );

    return ParsingResult.fromRegex(
      success: transaction.isParsed,
      transaction: updatedTransaction,
      parseTime: parseTime,
      confidence: updatedTransaction.parserConfidence,
      data: {
        'amount': transaction.amount,
        'merchant': transaction.merchant,
        'type': transaction.type.toString(),
        'llm_error': llmError,
      },
    );
  }

  /// Use regex parsing directly
  Future<ParsingResult> _useRegex(String smsText) async {
    final startTime = DateTime.now();
    final transaction = await TransactionParser.parseAsync(smsText);
    final parseTime = DateTime.now().difference(startTime).inMilliseconds / 1000.0;

    // Update transaction with parser metadata
    final updatedTransaction = transaction.copyWith(
      parserType: 'Regex',
      parseTime: parseTime,
      parserConfidence: transaction.isParsed ? 0.7 : 0.3,
    );

    return ParsingResult.fromRegex(
      success: transaction.isParsed,
      transaction: updatedTransaction,
      parseTime: parseTime,
      confidence: updatedTransaction.parserConfidence,
      data: {
        'amount': transaction.amount,
        'merchant': transaction.merchant,
        'type': transaction.type.toString(),
      },
    );
  }

  /// Quick synchronous parse for backward compatibility (uses regex only)
  static Transaction quickParse(String smsText) {
    return TransactionParser.parse(smsText);
  }
}
