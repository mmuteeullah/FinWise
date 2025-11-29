import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/llm_service.dart';
import '../services/transaction_service.dart';
import '../theme/app_theme.dart';
import 'error_log_screen.dart';

class LLMSettingsScreen extends StatefulWidget {
  const LLMSettingsScreen({super.key});

  @override
  State<LLMSettingsScreen> createState() => _LLMSettingsScreenState();
}

class _LLMSettingsScreenState extends State<LLMSettingsScreen> {
  final LLMService _llmService = LLMService();
  final TransactionService _transactionService = TransactionService();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _customModelController = TextEditingController();

  bool _isEnabled = false;
  bool _obscureApiKey = true;
  String _selectedModel = '';
  List<String> _availableModels = [];
  int _apiCallCount = 0;
  String? _lastError;
  bool _isLoading = false;
  bool _isTesting = false;
  bool _isReparsing = false;
  LLMProvider _selectedProvider = LLMProvider.openRouter;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final apiKey = await _llmService.getApiKey();
    _apiKeyController.text = apiKey ?? '';

    final enabled = await _llmService.isEnabled();
    final provider = await _llmService.getProvider();
    final model = await _llmService.getSelectedModel();
    final models = await _llmService.getAllModels();
    final stats = await _llmService.getStats();

    setState(() {
      _isEnabled = enabled;
      _selectedProvider = provider;
      _selectedModel = model;
      _availableModels = models;
      _apiCallCount = stats['apiCallCount'] ?? 0;
      _lastError = stats['lastError'];
      _isLoading = false;
    });
  }

  Future<void> _saveApiKey() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _showSnackBar('Please enter an API key', isError: true);
      return;
    }

    await _llmService.saveApiKey(apiKey);
    _showSnackBar('API key saved successfully');
  }

  Future<void> _toggleEnabled(bool value) async {
    await _llmService.setEnabled(value);
    setState(() => _isEnabled = value);
    _showSnackBar(value ? 'LLM parsing enabled' : 'LLM parsing disabled');

    if (value) {
      // Ask user if they want to re-parse all transactions
      final shouldReparse = await _showReparseDialog();
      if (shouldReparse == true) {
        _reparseAllTransactions();
      }
    }
  }

  Future<bool?> _showReparseDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-parse Transactions?'),
        content: const Text(
          'Would you like to re-parse all existing transactions using LLM? '
          'This may take a few moments and will consume API credits.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Re-parse All'),
          ),
        ],
      ),
    );
  }

  Future<void> _testConnection() async {
    if (_apiKeyController.text.trim().isEmpty) {
      _showSnackBar('Please enter an API key first', isError: true);
      return;
    }

    setState(() => _isTesting = true);

    // Save API key before testing
    await _saveApiKey();

    final result = await _llmService.testConnection();

    setState(() => _isTesting = false);

    if (result['success']) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Connection Successful'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Model: ${result['model']}'),
              const SizedBox(height: 8),
              Text('Response: ${result['response']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('Connection Failed'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Error:'),
              const SizedBox(height: 8),
              SelectableText(result['error'] ?? 'Unknown error'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result['error'] ?? ''));
                _showSnackBar('Error copied to clipboard');
              },
              child: const Text('Copy Error'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _changeModel(String? newModel) async {
    if (newModel == null) return;
    await _llmService.saveSelectedModel(newModel);
    setState(() => _selectedModel = newModel);
    _showSnackBar('Model changed to $newModel');
  }

  Future<void> _changeProvider(LLMProvider? newProvider) async {
    if (newProvider == null || newProvider == _selectedProvider) return;

    await _llmService.saveProvider(newProvider);

    // Reload settings to get new provider's models
    await _loadSettings();

    _showSnackBar('Provider changed to ${LLMService.getProviderDisplayName(newProvider)}');
  }

  Future<void> _addCustomModel() async {
    final model = _customModelController.text.trim();
    if (model.isEmpty) {
      _showSnackBar('Please enter a model name', isError: true);
      return;
    }

    await _llmService.addCustomModel(model);
    _customModelController.clear();

    final models = await _llmService.getAllModels();
    setState(() => _availableModels = models);

    _showSnackBar('Custom model added: $model');
  }

  Future<void> _removeCustomModel(String model) async {
    // Don't allow removing default models from any provider
    if (LLMService.allDefaultModels.contains(model)) {
      _showSnackBar('Cannot remove default models', isError: true);
      return;
    }

    await _llmService.removeCustomModel(model);

    // If removed model was selected, switch to first available
    if (_selectedModel == model) {
      final defaultModels = await _llmService.getDefaultModels();
      if (defaultModels.isNotEmpty) {
        _selectedModel = defaultModels[0];
        await _llmService.saveSelectedModel(_selectedModel);
      }
    }

    final models = await _llmService.getAllModels();
    setState(() => _availableModels = models);

    _showSnackBar('Model removed: $model');
  }

  Future<void> _showReparseConfirmation() async {
    final transactions = await _transactionService.getAllTransactions();

    if (transactions.isEmpty) {
      _showSnackBar('No transactions to re-parse', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.coral),
            const SizedBox(width: 8),
            const Text('Confirm Re-parse'),
          ],
        ),
        content: Text(
          'This will re-parse ${transactions.length} transaction${transactions.length > 1 ? 's' : ''} using the LLM.\n\n'
          'This action may take a few minutes and consume API credits. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.coral,
            ),
            child: const Text('Re-parse'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _reparseAllTransactions();
    }
  }

  Future<void> _reparseAllTransactions() async {
    setState(() => _isReparsing = true);

    try {
      final transactions = await _transactionService.getAllTransactions();
      int successCount = 0;
      int failCount = 0;

      for (final transaction in transactions) {
        final result = await _llmService.parseSMS(transaction.rawMessage);

        if (result['success']) {
          final updatedTransaction = await _llmService.responseToTransaction(
            result,
            transaction.rawMessage,
          );

          if (updatedTransaction != null) {
            // Update the transaction with new parsing data
            await _transactionService.updateTransaction(
              updatedTransaction.copyWith(id: transaction.id),
            );
            successCount++;
          } else {
            failCount++;
          }
        } else {
          // Store error in transaction
          await _transactionService.updateTransaction(
            transaction.copyWith(
              parsingError: result['error'],
              parserType: 'LLM:Failed',
            ),
          );
          failCount++;
        }
      }

      setState(() => _isReparsing = false);

      _showSnackBar(
        'Re-parsing complete: $successCount succeeded, $failCount failed',
      );

      // Reload stats
      _loadSettings();
    } catch (e) {
      setState(() => _isReparsing = false);
      _showSnackBar('Re-parsing failed: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppTheme.coral,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LLM Integration'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Enable/Disable Toggle
                Card(
                  child: SwitchListTile(
                    title: const Text('Enable LLM Parsing'),
                    subtitle: Text(
                      _isEnabled
                          ? 'Using LLM for transaction parsing'
                          : 'Using regex patterns only',
                    ),
                    value: _isEnabled,
                    onChanged: _toggleEnabled,
                    activeColor: AppTheme.coral,
                  ),
                ),

                const SizedBox(height: 16),

                // Provider Selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Provider',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<LLMProvider>(
                          value: _selectedProvider,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Select Provider',
                          ),
                          items: LLMProvider.values.map((provider) {
                            return DropdownMenuItem(
                              value: provider,
                              child: Row(
                                children: [
                                  Icon(
                                    provider == LLMProvider.nvidia
                                        ? Icons.memory
                                        : Icons.router,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(LLMService.getProviderDisplayName(provider)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: _changeProvider,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedProvider == LLMProvider.nvidia
                                      ? 'NVIDIA provides free access to various models'
                                      : 'OpenRouter provides access to multiple AI models',
                                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // API Key Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'API Key',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _apiKeyController,
                          obscureText: _obscureApiKey,
                          decoration: InputDecoration(
                            hintText: 'sk-or-v1-...',
                            border: const OutlineInputBorder(),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _obscureApiKey
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscureApiKey = !_obscureApiKey);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.save),
                                  onPressed: _saveApiKey,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _isTesting ? null : _testConnection,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_tethering),
                          label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.coral,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Model Selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Model Selection',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedModel.isEmpty ? null : _selectedModel,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Selected Model',
                          ),
                          items: _availableModels.map((model) {
                            return DropdownMenuItem(
                              value: model,
                              child: Row(
                                children: [
                                  Expanded(child: Text(model)),
                                  if (!LLMService.allDefaultModels.contains(model))
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18),
                                      onPressed: () => _removeCustomModel(model),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: _changeModel,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Add Custom Model',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customModelController,
                                decoration: const InputDecoration(
                                  hintText: 'e.g., anthropic/claude-3.5-sonnet',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _addCustomModel,
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.coral,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Statistics
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Statistics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          leading: const Icon(Icons.api),
                          title: const Text('API Calls Made'),
                          trailing: Text(
                            _apiCallCount.toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ListTile(
                          leading: Icon(
                            _lastError == null ? Icons.check_circle : Icons.error,
                            color: _lastError == null ? Colors.green : Colors.red,
                          ),
                          title: const Text('Last Status'),
                          subtitle: Text(
                            _lastError == null ? 'No errors' : 'Error occurred',
                          ),
                        ),
                        if (_lastError != null)
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ErrorLogScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.error_outline),
                            label: const Text('View Error Log'),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Actions
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _isReparsing ? null : _showReparseConfirmation,
                          icon: _isReparsing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(_isReparsing
                              ? 'Re-parsing...'
                              : 'Re-parse All Transactions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await _llmService.resetApiCallCount();
                            _loadSettings();
                            _showSnackBar('API call count reset');
                          },
                          icon: const Icon(Icons.restore),
                          label: const Text('Reset API Call Count'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Info Card
                Card(
                  color: AppTheme.purple.withAlpha(25),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: AppTheme.purple),
                            SizedBox(width: 8),
                            Text(
                              'How it works',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• LLM parsing uses AI to extract transaction details\n'
                          '• Falls back to regex if LLM fails\n'
                          '• Regex remains as a backup method\n'
                          '• API key is stored locally on your device\n'
                          '• Get your API key from openrouter.ai',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _customModelController.dispose();
    super.dispose();
  }
}
