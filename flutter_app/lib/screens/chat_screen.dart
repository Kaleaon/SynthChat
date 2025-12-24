import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/character_service.dart';
import '../services/chat_service.dart';
import '../services/personality_evolution_service.dart';
import '../services/memory_branch_service.dart';
import '../models/message.dart';
import '../theme/app_theme.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
      _initPersonalityService();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initPersonalityService() {
    // V5: Connect personality service to chat service
    final chatService = context.read<ChatService>();
    final personalityService = context.read<PersonalityEvolutionService>();
    chatService.setPersonalityService(personalityService);
  }

  Future<void> _loadMessages() async {
    final characterService = context.read<CharacterService>();
    final chatService = context.read<ChatService>();
    final personalityService = context.read<PersonalityEvolutionService>();
    
    if (characterService.selectedCharacter != null) {
      await chatService.loadMessages(characterService.selectedCharacter!.id);
      await chatService.addGreetingIfNeeded(characterService.selectedCharacter!);
      // V5: Load personality data
      await personalityService.loadCharacterPersonality(characterService.selectedCharacter!.id);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final character = context.read<CharacterService>().selectedCharacter;
    if (character == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final chatService = context.read<ChatService>();
      await chatService.sendMessage(character, content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
    _scrollToBottom();
  }

  void _showCharacterInfo() {
    final character = context.read<CharacterService>().selectedCharacter;
    if (character == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildCharacterInfoSheet(character),
    );
  }

  // V3: Show memory branch dialog
  void _showMemoryBranchDialog(character) {
    // Note: Using dynamic type to avoid circular import with Character model
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.account_tree, color: AppColors.accent),
            SizedBox(width: 8),
            Text('Create Memory Branch'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a private memory branch to have separate conversations that won\'t affect the main memory.',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Branch Name',
                hintText: 'e.g., "Private Chat", "Alt Timeline"',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final branchService = context.read<MemoryBranchService>();
                final branch = await branchService.createBranch(
                  characterId: character.id,
                  name: nameController.text.trim(),
                  isPrivate: true,
                );
                if (branch != null && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Memory branch "${branch.name}" created!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Branch'),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterInfoSheet(character) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildAvatar(character.name, 60),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      character.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      '${character.messageCount} messages',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (character.personality.isNotEmpty) ...[
            Text(
              'Personality',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
            const SizedBox(height: 4),
            Text(character.personality),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              _buildInfoChip(Icons.memory, character.model),
              const SizedBox(width: 8),
              _buildInfoChip(Icons.thermostat, 'T: ${character.temperature}'),
            ],
          ),
          const SizedBox(height: 24),
          // V3: Memory Branch button
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showMemoryBranchDialog(character);
            },
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('Fork Memory Branch'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/character/edit');
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear Chat'),
                        content: const Text(
                            'This will delete all messages with this character. Continue?'),
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
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await context
                          .read<ChatService>()
                          .clearMessages(character.id);
                    }
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.error),
                  label: const Text('Clear Chat',
                      style: TextStyle(color: AppColors.error)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final characterService = context.watch<CharacterService>();
    final chatService = context.watch<ChatService>();
    final character = characterService.selectedCharacter;

    if (character == null) {
      return const Scaffold(
        body: Center(child: Text('No character selected')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            _buildAvatar(character.name, 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name,
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Online',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.success,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // V5: Personality/mood indicator
          Consumer<PersonalityEvolutionService>(
            builder: (context, service, child) {
              final mood = service.currentMood;
              if (mood == null) return const SizedBox.shrink();
              return IconButton(
                icon: Text(
                  mood.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
                tooltip: 'Mood: ${mood.current}',
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/personality',
                    arguments: character,
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'Personality',
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/personality',
                arguments: character,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showCharacterInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: chatService.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatService.messages.isEmpty
                    ? _buildEmptyChat()
                    : _buildMessageList(chatService.messages, chatService.isTyping),
          ),
          // Input
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getAvatarColor(name),
            _getAvatarColor(name).withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          _getInitials(name),
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation!',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<Message> messages, bool isTyping) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: messages.length + (isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (isTyping && index == messages.length) {
          return _buildTypingIndicator();
        }
        final message = messages[index];
        final character = context.read<CharacterService>().selectedCharacter;
        return MessageBubble(
          message: message,
          characterName: character?.name ?? 'AI',
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    final character = context.read<CharacterService>().selectedCharacter;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _buildAvatar(character?.name ?? 'AI', 32),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.textMuted.withOpacity(0.5 + (value * 0.5)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
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

  Color _getAvatarColor(String name) {
    final colors = [
      AppColors.primary,
      AppColors.primaryLight,
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];

    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }
}
