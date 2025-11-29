import 'transaction.dart';

enum ParsingMethod {
  llm,
  regex,
  manual,
  unknown,
}

class ParsingResult {
  final bool success;
  final ParsingMethod method;
  final Transaction? transaction;
  final String? error;
  final double? parseTime;
  final double confidence;
  final String? modelUsed;
  final String? rawLLMResponse;
  final Map<String, dynamic>? llmData;
  final Map<String, dynamic>? regexData;

  ParsingResult({
    required this.success,
    required this.method,
    this.transaction,
    this.error,
    this.parseTime,
    this.confidence = 0.0,
    this.modelUsed,
    this.rawLLMResponse,
    this.llmData,
    this.regexData,
  });

  // Create from LLM response
  factory ParsingResult.fromLLM({
    required bool success,
    Transaction? transaction,
    String? error,
    double? parseTime,
    double confidence = 0.0,
    String? modelUsed,
    String? rawResponse,
    Map<String, dynamic>? data,
  }) {
    return ParsingResult(
      success: success,
      method: ParsingMethod.llm,
      transaction: transaction,
      error: error,
      parseTime: parseTime,
      confidence: confidence,
      modelUsed: modelUsed,
      rawLLMResponse: rawResponse,
      llmData: data,
    );
  }

  // Create from Regex parsing
  factory ParsingResult.fromRegex({
    required bool success,
    Transaction? transaction,
    String? error,
    double? parseTime,
    double confidence = 0.0,
    Map<String, dynamic>? data,
  }) {
    return ParsingResult(
      success: success,
      method: ParsingMethod.regex,
      transaction: transaction,
      error: error,
      parseTime: parseTime,
      confidence: confidence,
      regexData: data,
    );
  }

  // Create for manual entry
  factory ParsingResult.manual(Transaction transaction) {
    return ParsingResult(
      success: true,
      method: ParsingMethod.manual,
      transaction: transaction,
      confidence: 1.0,
    );
  }

  // Create error result
  factory ParsingResult.error(String error, ParsingMethod method) {
    return ParsingResult(
      success: false,
      method: method,
      error: error,
      confidence: 0.0,
    );
  }

  String get methodName {
    switch (method) {
      case ParsingMethod.llm:
        return modelUsed != null ? 'LLM ($modelUsed)' : 'LLM';
      case ParsingMethod.regex:
        return 'Regex';
      case ParsingMethod.manual:
        return 'Manual';
      case ParsingMethod.unknown:
        return 'Unknown';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'method': method.toString(),
      'error': error,
      'parseTime': parseTime,
      'confidence': confidence,
      'modelUsed': modelUsed,
      'rawLLMResponse': rawLLMResponse,
      'llmData': llmData,
      'regexData': regexData,
    };
  }

  @override
  String toString() {
    return 'ParsingResult(success: $success, method: $methodName, confidence: $confidence, error: $error)';
  }
}
