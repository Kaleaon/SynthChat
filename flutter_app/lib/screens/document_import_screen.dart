import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/document_parser_service.dart';
import '../services/auth_service.dart';
import '../services/character_service.dart';
import '../theme/app_theme.dart';

/// V4: Document import screen for AI-powered character creation
class DocumentImportScreen extends StatefulWidget {
  const DocumentImportScreen({super.key});

  @override
  State<DocumentImportScreen> createState() => _DocumentImportScreenState();
}

class _DocumentImportScreenState extends State<DocumentImportScreen> {
  ExtractedCharacterData? _extractedData;
  bool _isCreatingCharacter = false;

  Future<void> _pickAndImportDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['md', 'txt', 'json', 'html'],
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final auth = context.read<AuthService>();
        final parserService = context.read<DocumentParserService>();

        final extractedData = await parserService.importDocument(
          userId: auth.currentUser!.id,
          filePath: file.path!,
          filename: file.name,
        );

        if (extractedData != null && mounted) {
          setState(() {
            _extractedData = extractedData;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing document: $e')),
        );
      }
    }
  }

  Future<void> _createCharacterFromExtracted() async {
    if (_extractedData == null) return;

    setState(() {
      _isCreatingCharacter = true;
    });

    try {
      final auth = context.read<AuthService>();
      final parserService = context.read<DocumentParserService>();
      final characterService = context.read<CharacterService>();

      final character = await parserService.createCharacterFromExtracted(
        userId: auth.currentUser!.id,
        data: _extractedData!,
      );

      if (character != null) {
        // Refresh character list
        await characterService.loadCharacters();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Character "${_extractedData!.name}" created!'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _extractedData = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating character: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingCharacter = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Character'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Import section
            Card(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 64,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Import Character from Document',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Supported formats: Markdown (.md), Text (.txt), JSON (.json), HTML (.html)',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Consumer<DocumentParserService>(
                      builder: (context, parserService, child) {
                        if (parserService.isProcessing) {
                          return Column(
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(parserService.processingStatus),
                            ],
                          );
                        }
                        return ElevatedButton.icon(
                          onPressed: _pickAndImportDocument,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Select Document'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Extracted data preview
            if (_extractedData != null) ...[
              const SizedBox(height: 24),
              Card(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primary,
                            radius: 24,
                            child: Text(
                              _extractedData!.name.isNotEmpty 
                                  ? _extractedData!.name[0].toUpperCase() 
                                  : '?',
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _extractedData!.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text(
                                  'Extracted Character',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _extractedData = null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      _buildPreviewField('Description', _extractedData!.description),
                      _buildPreviewField('Personality', _extractedData!.personality),
                      _buildPreviewField('Greeting', _extractedData!.greeting),
                      if (_extractedData!.backstory.isNotEmpty)
                        _buildPreviewField('Backstory', _extractedData!.backstory),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isCreatingCharacter ? null : _createCharacterFromExtracted,
                          icon: _isCreatingCharacter
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.person_add),
                          label: Text(
                            _isCreatingCharacter ? 'Creating...' : 'Create Character',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Document format guide
            const SizedBox(height: 24),
            Card(
              color: AppColors.surface.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text(
                          'Document Format Guide',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'For best results, structure your document with these sections:',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 8),
                    _buildFormatExample('# Character Name'),
                    _buildFormatExample('## Description'),
                    _buildFormatExample('Your character description...'),
                    _buildFormatExample('## Personality'),
                    _buildFormatExample('Personality traits...'),
                    _buildFormatExample('## Greeting'),
                    _buildFormatExample('How they greet others...'),
                    _buildFormatExample('## Backstory'),
                    _buildFormatExample('Background story...'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewField(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.length > 200 ? '${value.substring(0, 200)}...' : value,
            style: TextStyle(color: Colors.white.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatExample(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }
}
