import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../models/email_message.dart';
import '../services/email_service.dart';
import '../services/llm_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';

class EmailParserTesterScreen extends StatefulWidget {
  const EmailParserTesterScreen({Key? key}) : super(key: key);

  @override
  State<EmailParserTesterScreen> createState() => _EmailParserTesterScreenState();
}

class _EmailParserTesterScreenState extends State<EmailParserTesterScreen> {
  final EmailService _emailService = EmailService();
  final LLMService _llmService = LLMService();

  List<EmailMessage> _emails = [];
  EmailMessage? _selectedEmail;
  final TextEditingController _customTextController = TextEditingController();

  bool _isLoading = false;
  bool _isParsing = false;
  String _inputMode = 'email'; // 'email' or 'custom'

  // Results
  String? _preparedContent;
  String? _rawLLMResponse;
  Map<String, dynamic>? _parsedJSON;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEmails();
  }

  @override
  void dispose() {
    _customTextController.dispose();
    super.dispose();
  }

  Future<void> _loadEmails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final emails = await _emailService.getAllEmails(limit: 50);
      setState(() {
        _emails = emails;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load emails: $e';
      });
    }
  }

  String _prepareEmailContent(EmailMessage email) {
    final buffer = StringBuffer();
    buffer.writeln('From: ${email.fromName} <${email.from}>');
    buffer.writeln('Subject: ${email.subject}');
    buffer.writeln();

    if (email.textBody != null && email.textBody!.isNotEmpty) {
      buffer.writeln(email.textBody);
    } else if (email.snippet != null) {
      buffer.writeln(email.snippet);
    }

    return buffer.toString().trim();
  }

  Future<void> _parseContent() async {
    setState(() {
      _isParsing = true;
      _error = null;
      _preparedContent = null;
      _rawLLMResponse = null;
      _parsedJSON = null;
    });

    try {
      // Prepare content
      String content;
      if (_inputMode == 'email' && _selectedEmail != null) {
        content = _prepareEmailContent(_selectedEmail!);
      } else if (_inputMode == 'custom') {
        content = _customTextController.text.trim();
      } else {
        setState(() {
          _error = 'Please select an email or enter custom text';
          _isParsing = false;
        });
        return;
      }

      setState(() {
        _preparedContent = content;
      });

      // Call LLM
      print('📧 Calling LLM with content:\n$content');
      final llmResult = await _llmService.parseSMS(content);

      setState(() {
        if (llmResult['success']) {
          _rawLLMResponse = llmResult['rawResponse'];
          _parsedJSON = llmResult['data'];
        } else {
          _error = llmResult['error'] ?? 'Unknown error';
        }

        _isParsing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isParsing = false;
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Copied to clipboard'),
        backgroundColor: AppTheme.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDark(context);
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: ThemeHelper.backgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Email Parser Tester',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // White content section
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? scaffoldBg : AppTheme.whiteBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: _buildContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Input mode selector
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildModeChip('Select Email', 'email'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeChip('Custom Text', 'custom'),
              ),
            ],
          ),
        ),

        // Input section
        if (_inputMode == 'email') _buildEmailSelector() else _buildCustomTextInput(),

        // Parse button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isParsing ? null : _parseContent,
              icon: _isParsing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_fix_high),
              label: Text(_isParsing ? 'Parsing...' : 'Parse with LLM'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Results section
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildModeChip(String label, String mode) {
    final isSelected = _inputMode == mode;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _inputMode = mode;
          _error = null;
          _preparedContent = null;
          _rawLLMResponse = null;
          _parsedJSON = null;
        });
      },
      backgroundColor: ThemeHelper.surfaceColor(context),
      selectedColor: AppTheme.purple.withOpacity(0.2),
      checkmarkColor: AppTheme.purple,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.purple : ThemeHelper.textPrimary(context),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildEmailSelector() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      );
    }

    if (_emails.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No emails found. Sync emails first.',
          style: TextStyle(color: ThemeHelper.textSecondary(context)),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: ThemeHelper.cardDecoration(context),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<EmailMessage>(
          value: _selectedEmail,
          isExpanded: true,
          hint: Text(
            'Select an email to test',
            style: TextStyle(color: ThemeHelper.textSecondary(context)),
          ),
          items: _emails.map((email) {
            return DropdownMenuItem<EmailMessage>(
              value: email,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    email.subject,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ThemeHelper.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    email.fromName,
                    style: TextStyle(
                      fontSize: 12,
                      color: ThemeHelper.textSecondary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (email) {
            setState(() {
              _selectedEmail = email;
              _error = null;
              _preparedContent = null;
              _rawLLMResponse = null;
              _parsedJSON = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildCustomTextInput() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: ThemeHelper.cardDecoration(context),
      child: TextField(
        controller: _customTextController,
        maxLines: 6,
        decoration: InputDecoration(
          hintText: 'Paste email content here...\n\nFrom: sender@example.com\nSubject: Transaction Alert\n\nYour account was debited INR 500...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: ThemeHelper.textSecondary(context)),
        ),
        style: TextStyle(
          fontSize: 13,
          color: ThemeHelper.textPrimary(context),
          fontFamily: 'Courier',
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.coral.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.coral),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppTheme.coral),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.coral),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_preparedContent == null && _rawLLMResponse == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.science_outlined,
              size: 80,
              color: ThemeHelper.textSecondary(context).withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Select an email or enter text\nthen tap "Parse with LLM"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: ThemeHelper.textSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            labelColor: AppTheme.purple,
            unselectedLabelColor: ThemeHelper.textSecondary(context),
            indicatorColor: AppTheme.purple,
            tabs: const [
              Tab(text: 'Prepared'),
              Tab(text: 'Raw Response'),
              Tab(text: 'Parsed JSON'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildTab(
                  'Prepared Email Content',
                  _preparedContent ?? 'No content yet',
                  Icons.email,
                ),
                _buildTab(
                  'Raw LLM Response',
                  _rawLLMResponse ?? 'No response yet',
                  Icons.code,
                ),
                _buildTab(
                  'Parsed JSON Data',
                  _parsedJSON != null
                      ? const JsonEncoder.withIndent('  ').convert(_parsedJSON)
                      : 'No parsed data yet',
                  Icons.data_object,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, String content, IconData icon) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.purple, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ThemeHelper.textPrimary(context),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _copyToClipboard(content),
                icon: const Icon(Icons.copy, size: 20),
                color: AppTheme.purple,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThemeHelper.surfaceColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ThemeHelper.textSecondary(context).withOpacity(0.2),
              ),
            ),
            child: SelectableText(
              content,
              style: TextStyle(
                fontSize: 12,
                color: ThemeHelper.textPrimary(context),
                fontFamily: 'Courier',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
