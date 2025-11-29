import '../models/email_message.dart';
import '../models/parsing_result.dart';
import 'llm_service.dart';
import 'email_service.dart';
import 'database_helper.dart';

class EmailParser {
  final LLMService _llmService = LLMService();
  final EmailService _emailService = EmailService();
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Parse email content and extract transaction
  Future<ParsingResult?> parseEmail(EmailMessage email) async {
    print('📧 Starting email parsing for: ${email.subject}');

    final llmEnabled = await _llmService.isEnabled();
    print('📧 LLM enabled: $llmEnabled');

    if (!llmEnabled) {
      print('❌ LLM is not enabled - please configure API key');
      return null;
    }

    try {
      // Prepare email content for parsing
      final emailContent = _prepareEmailContent(email);
      print('📧 Email content prepared (${emailContent.length} chars)');
      print('📧 Content preview: ${emailContent.substring(0, emailContent.length > 200 ? 200 : emailContent.length)}...');

      // STEP 1: Extract clean transaction text from noisy email
      print('📧 STEP 1: Extracting transaction text from email...');
      final extractResult = await _llmService.extractTransactionText(emailContent);
      print('📧 Extraction result success: ${extractResult['success']}');

      if (!extractResult['success']) {
        print('❌ Failed to extract transaction text: ${extractResult['error'] ?? 'Unknown error'}');
        return null;
      }

      final cleanTransactionText = extractResult['extractedText'] as String;
      print('📧 ✅ Extracted clean text: "$cleanTransactionText"');

      // STEP 2: Parse the clean transaction text to JSON
      print('📧 STEP 2: Parsing clean text to JSON...');
      final llmResult = await _llmService.parseSMS(cleanTransactionText);
      print('📧 Parsing result success: ${llmResult['success']}');

      if (llmResult['success']) {
        print('✅ LLM parsing successful, converting to transaction...');

        // Convert LLM response to transaction
        final transaction = await _llmService.responseToTransaction(
          llmResult,
          cleanTransactionText,
        );

        if (transaction != null) {
          print('✅ Transaction created: ${transaction.id}');

          // Update transaction with email-specific parser type
          // Store the clean extracted text, not the full noisy email
          final emailTransaction = transaction.copyWith(
            rawMessage: cleanTransactionText,
            parserType: 'Email-2Step-LLM',
          );

          // Save transaction to database
          print('💾 Saving transaction to database...');
          await _db.insertTransaction(emailTransaction);
          print('✅ Transaction saved to database');

          // Mark email as processed
          await _emailService.markEmailAsProcessed(
            email.id,
            transactionId: emailTransaction.id,
          );

          // LLM parsing successful
          // Calculate total parse time (Step 1 + Step 2)
          final extractTime = extractResult['extractTime'] ?? 0.0;
          final parseTime = llmResult['parseTime'] ?? 0.0;
          final totalTime = extractTime + parseTime;

          print('⏱️ Total parse time: ${totalTime.toStringAsFixed(2)}s (Extract: ${extractTime.toStringAsFixed(2)}s + Parse: ${parseTime.toStringAsFixed(2)}s)');

          final data = llmResult['data'] as Map<String, dynamic>?;
          return ParsingResult.fromLLM(
            success: true,
            transaction: emailTransaction,
            parseTime: totalTime,
            confidence: data?['confidence'] ?? 0.8,
            modelUsed: llmResult['model'],
            rawResponse: llmResult['rawResponse'],
            data: data,
          );
        } else {
          print('❌ Failed to convert LLM response to transaction');
        }
      } else {
        print('❌ LLM parsing failed: ${llmResult['error'] ?? 'Unknown error'}');
      }

      return null;
    } catch (e, stackTrace) {
      print('❌ Error parsing email: $e');
      print('❌ Stack trace: $stackTrace');
      return null;
    }
  }

  /// Prepare email content for LLM parsing
  /// Focus on first 2-3 lines where transaction info is typically located
  String _prepareEmailContent(EmailMessage email) {
    final buffer = StringBuffer();

    // Add subject (may contain useful context like "Transaction alert")
    buffer.writeln('Subject: ${email.subject}');
    buffer.writeln();

    // Get body content (prefer text, fallback to snippet)
    String bodyText = '';
    if (email.textBody != null && email.textBody!.isNotEmpty) {
      bodyText = email.textBody!;
    } else if (email.htmlBody != null && email.htmlBody!.isNotEmpty) {
      // Strip HTML tags for better LLM parsing
      bodyText = _stripHtmlTags(email.htmlBody!);
    } else if (email.snippet != null) {
      bodyText = email.snippet!;
    }

    // Extract only first 2-3 meaningful lines (ignore boilerplate/disclaimers)
    final importantContent = _extractImportantContent(bodyText);
    buffer.writeln(importantContent);

    return buffer.toString().trim();
  }

  /// Extract only the important transaction content from email body
  /// SIMPLIFIED: Just take first 2-3 lines with transaction keywords
  String _extractImportantContent(String bodyText) {
    // Clean and split into lines
    final lines = bodyText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return '';

    // Just take first 3 lines that contain transaction-related content
    final transactionLines = <String>[];

    for (final line in lines) {
      // Skip greetings
      if (line.toLowerCase().startsWith('dear ') ||
          line.toLowerCase().startsWith('hello ') ||
          line.toLowerCase().startsWith('hi ')) {
        continue;
      }

      // Stop at common noise indicators
      if (line.toLowerCase().startsWith('in case') ||
          line.toLowerCase().startsWith('if you') ||
          line.toLowerCase().startsWith('the available') ||
          line.toLowerCase().startsWith('available credit') ||
          line.toLowerCase().startsWith('total credit')) {
        break;
      }

      // Add line if we haven't collected 3 yet
      if (transactionLines.length < 3) {
        transactionLines.add(line);
      } else {
        break;
      }
    }

    return transactionLines.join('\n');
  }

  /// Strip HTML tags from email body
  String _stripHtmlTags(String html) {
    // Remove script and style elements
    var text = html.replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '');
    text = text.replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '');

    // Remove HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');

    // Decode common HTML entities
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");

    // Clean up whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    return text.trim();
  }

  /// Parse multiple emails in batch
  Future<List<ParsingResult>> parseEmails(List<EmailMessage> emails) async {
    final results = <ParsingResult>[];

    for (final email in emails) {
      final result = await parseEmail(email);
      if (result != null && result.success) {
        results.add(result);
      }
    }

    return results;
  }

  /// Parse all unprocessed emails with rate limiting and progress tracking
  /// [onProgress] callback receives (current, total, status) updates
  /// [rateLimit] delay in milliseconds between each email parse (default 500ms = 0.5 sec)
  Future<List<ParsingResult>> parseUnprocessedEmails({
    int limit = 50,
    int rateLimit = 500,
    Function(int current, int total, String status)? onProgress,
  }) async {
    print('📧 Starting batch email parsing...');

    final unprocessedEmails = await _emailService.getUnprocessedEmails(
      limit: limit,
    );

    if (unprocessedEmails.isEmpty) {
      print('✅ No unprocessed emails to parse');
      return [];
    }

    final total = unprocessedEmails.length;
    print('📊 Found $total unprocessed emails');

    final results = <ParsingResult>[];
    int successCount = 0;
    int failedCount = 0;

    for (int i = 0; i < unprocessedEmails.length; i++) {
      final email = unprocessedEmails[i];
      final current = i + 1;

      onProgress?.call(
        current,
        total,
        'Parsing email $current/$total...',
      );

      print('📧 Parsing email $current/$total: ${email.subject}');

      final result = await parseEmail(email);

      if (result != null && result.success) {
        results.add(result);
        successCount++;
        print('✅ Successfully parsed email $current/$total');
      } else {
        failedCount++;
        print('❌ Failed to parse email $current/$total');
      }

      // Rate limiting: wait before parsing next email
      if (current < total && rateLimit > 0) {
        final delaySeconds = rateLimit >= 1000 ? '${(rateLimit / 1000).toStringAsFixed(1)} sec' : '${rateLimit}ms';
        onProgress?.call(
          current,
          total,
          'Rate limiting ($delaySeconds)...',
        );
        print('⏱️ Rate limiting: waiting $rateLimit ms...');
        await Future.delayed(Duration(milliseconds: rateLimit));
      }
    }

    print('✅ Batch parsing complete: $successCount succeeded, $failedCount failed');

    return results;
  }
}
