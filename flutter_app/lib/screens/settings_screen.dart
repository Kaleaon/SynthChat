import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../models/app_settings.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _apiEndpointController = TextEditingController();
  final _modelController = TextEditingController();

  String _selectedProvider = 'openai';
  double _temperature = 0.7;
  int _maxTokens = 500;
  bool _isLoading = false;
  bool _obscureApiKey = true;

  final List<Map<String, String>> _providers = [
    {'value': 'openai', 'name': 'OpenAI'},
    {'value': 'gemini', 'name': 'Google Gemini'},
    {'value': 'anthropic', 'name': 'Anthropic Claude'},
    {'value': 'custom', 'name': 'Custom API'},
  ];

  // Use centralized model lists from AppSettings
  Map<String, List<String>> get _modelsByProvider => {
    ...AppSettings.availableModels,
    'custom': [],
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final settingsService = context.read<SettingsService>();
    final settings = settingsService.settings;

    if (settings != null) {
      setState(() {
        _selectedProvider = settings.llmProvider;
        _apiKeyController.text = settings.apiKey;
        _apiEndpointController.text = settings.apiEndpoint;
        _modelController.text = settings.model;
        _temperature = settings.temperature;
        _maxTokens = settings.maxTokens;
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiEndpointController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final settingsService = context.read<SettingsService>();

    try {
      final success = await settingsService.saveSettings(
        llmProvider: _selectedProvider,
        apiKey: _apiKeyController.text.trim(),
        apiEndpoint: _apiEndpointController.text.trim(),
        model: _modelController.text.trim(),
        temperature: _temperature,
        maxTokens: _maxTokens,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onProviderChanged(String? provider) {
    if (provider == null) return;

    setState(() {
      _selectedProvider = provider;
      // Update model to default for new provider
      final models = _modelsByProvider[provider] ?? [];
      if (models.isNotEmpty) {
        _modelController.text = models[0];
      } else {
        _modelController.text = '';
      }
      
      // Clear endpoint for non-custom providers
      if (provider != 'custom') {
        _apiEndpointController.text = '';
      }
    });
  }

  String _getProviderInfo(String provider) {
    switch (provider) {
      case 'openai':
        return 'Get your API key from platform.openai.com';
      case 'gemini':
        return 'Get your API key from ai.google.dev';
      case 'anthropic':
        return 'Get your API key from console.anthropic.com';
      case 'custom':
        return 'Use any OpenAI-compatible API endpoint';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Provider Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LLM Provider',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedProvider,
                      decoration: const InputDecoration(
                        labelText: 'Provider',
                        border: OutlineInputBorder(),
                      ),
                      items: _providers.map((provider) {
                        return DropdownMenuItem(
                          value: provider['value'],
                          child: Text(provider['name']!),
                        );
                      }).toList(),
                      onChanged: _onProviderChanged,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getProviderInfo(_selectedProvider),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // API Key
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'API Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _apiKeyController,
                      obscureText: _obscureApiKey,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureApiKey
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureApiKey = !_obscureApiKey;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your API key';
                        }
                        return null;
                      },
                    ),
                    if (_selectedProvider == 'custom') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _apiEndpointController,
                        decoration: const InputDecoration(
                          labelText: 'API Endpoint',
                          hintText: 'https://api.example.com/v1/chat/completions',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (_selectedProvider == 'custom' &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Please enter API endpoint for custom provider';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Model Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Model Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_modelsByProvider[_selectedProvider]?.isNotEmpty ??
                        false)
                      DropdownButtonFormField<String>(
                        value: _modelsByProvider[_selectedProvider]!
                                .contains(_modelController.text)
                            ? _modelController.text
                            : _modelsByProvider[_selectedProvider]![0],
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          border: OutlineInputBorder(),
                        ),
                        items: _modelsByProvider[_selectedProvider]!
                            .map((model) {
                          return DropdownMenuItem(
                            value: model,
                            child: Text(model),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _modelController.text = value;
                          }
                        },
                      )
                    else
                      TextFormField(
                        controller: _modelController,
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          hintText: 'e.g., gpt-3.5-turbo',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a model name';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'Temperature: ${_temperature.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Slider(
                      value: _temperature,
                      min: 0.0,
                      max: 2.0,
                      divisions: 20,
                      label: _temperature.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() {
                          _temperature = value;
                        });
                      },
                    ),
                    const Text(
                      'Lower values make output more focused and deterministic',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: _maxTokens.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Max Tokens',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter max tokens';
                        }
                        final tokens = int.tryParse(value);
                        if (tokens == null || tokens <= 0) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        final tokens = int.tryParse(value);
                        if (tokens != null) {
                          _maxTokens = tokens;
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Info Card
            Card(
              color: AppColors.cardBackground.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[300]),
                        const SizedBox(width: 8),
                        const Text(
                          'About API Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• Your API key is stored securely on your device\n'
                      '• Different characters can use different models\n'
                      '• Temperature controls creativity (0=focused, 2=creative)\n'
                      '• Max tokens limits response length',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
