import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/character_service.dart';
import '../theme/app_theme.dart';

class CharacterEditScreen extends StatefulWidget {
  final bool isNew;

  const CharacterEditScreen({super.key, this.isNew = false});

  @override
  State<CharacterEditScreen> createState() => _CharacterEditScreenState();
}

class _CharacterEditScreenState extends State<CharacterEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _personalityController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _greetingController = TextEditingController();

  String _selectedModel = 'gpt-3.5-turbo';
  double _temperature = 0.7;
  int _maxTokens = 500;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _models = [
    'gpt-3.5-turbo',
    'gpt-4',
    'gpt-4-turbo',
    'gpt-4o',
    'gpt-4o-mini',
  ];

  @override
  void initState() {
    super.initState();
    if (!widget.isNew) {
      _loadCharacter();
    }
  }

  void _loadCharacter() {
    final character = context.read<CharacterService>().selectedCharacter;
    if (character != null) {
      _nameController.text = character.name;
      _descriptionController.text = character.description;
      _personalityController.text = character.personality;
      _systemPromptController.text = character.systemPrompt;
      _greetingController.text = character.greeting;
      _selectedModel = character.model;
      _temperature = character.temperature;
      _maxTokens = character.maxTokens;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _personalityController.dispose();
    _systemPromptController.dispose();
    _greetingController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final characterService = context.read<CharacterService>();

    try {
      if (widget.isNew) {
        final (success, message) = await characterService.createCharacter(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          personality: _personalityController.text.trim(),
          systemPrompt: _systemPromptController.text.trim(),
          greeting: _greetingController.text.trim(),
          model: _selectedModel,
          temperature: _temperature,
          maxTokens: _maxTokens,
        );

        if (success) {
          if (mounted) Navigator.pop(context);
        } else {
          setState(() => _errorMessage = message);
        }
      } else {
        final character = characterService.selectedCharacter;
        if (character != null) {
          await characterService.updateCharacter(character.id, {
            'name': _nameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'personality': _personalityController.text.trim(),
            'system_prompt': _systemPromptController.text.trim(),
            'greeting': _greetingController.text.trim(),
            'model': _selectedModel,
            'temperature': _temperature,
            'max_tokens': _maxTokens,
          });
          if (mounted) Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final character = context.read<CharacterService>().selectedCharacter;
    if (character == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Character'),
        content: Text(
            'Are you sure you want to delete "${character.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<CharacterService>().deleteCharacter(character.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Create Character' : 'Edit Character'),
        actions: [
          if (!widget.isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar placeholder
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Center(
                        child: Text(
                          _nameController.text.isNotEmpty
                              ? _getInitials(_nameController.text)
                              : '?',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Character Name *',
                  hintText: 'e.g., Alice, Sherlock, etc.',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Short Description',
                  hintText: 'Brief description of the character',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Personality
              TextFormField(
                controller: _personalityController,
                decoration: const InputDecoration(
                  labelText: 'Personality',
                  hintText:
                      'Describe personality traits, behavior, speaking style...',
                  prefixIcon: Icon(Icons.psychology),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              // System prompt
              TextFormField(
                controller: _systemPromptController,
                decoration: const InputDecoration(
                  labelText: 'System Prompt (Optional)',
                  hintText:
                      'Custom instructions for the AI. Leave empty to auto-generate.',
                  prefixIcon: Icon(Icons.terminal),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              // Greeting
              TextFormField(
                controller: _greetingController,
                decoration: const InputDecoration(
                  labelText: 'Greeting Message',
                  hintText: 'First message when starting a conversation',
                  prefixIcon: Icon(Icons.waving_hand),
                  alignLabelWithHint: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // LLM Settings section
              Text(
                'LLM Settings',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              // Model dropdown
              DropdownButtonFormField<String>(
                value: _selectedModel,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  prefixIcon: Icon(Icons.memory),
                ),
                items: _models.map((model) {
                  return DropdownMenuItem(
                    value: model,
                    child: Text(model),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedModel = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Temperature slider
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Temperature',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        _temperature.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.border,
                      thumbColor: AppColors.primary,
                    ),
                    child: Slider(
                      value: _temperature,
                      min: 0,
                      max: 1,
                      divisions: 10,
                      onChanged: (value) {
                        setState(() => _temperature = value);
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Precise',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        'Creative',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Max tokens
              TextFormField(
                initialValue: _maxTokens.toString(),
                decoration: const InputDecoration(
                  labelText: 'Max Tokens',
                  prefixIcon: Icon(Icons.format_list_numbered),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final parsed = int.tryParse(value);
                  if (parsed != null) {
                    _maxTokens = parsed.clamp(100, 4000);
                  }
                },
              ),
              const SizedBox(height: 24),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),

              // Save button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save),
                            const SizedBox(width: 8),
                            Text(widget.isNew
                                ? 'Create Character'
                                : 'Save Changes'),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final words = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return words.isNotEmpty ? words[0][0].toUpperCase() : '?';
  }
}
