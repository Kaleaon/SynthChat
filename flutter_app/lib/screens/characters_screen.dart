import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/character_service.dart';
import '../services/chat_service.dart';
import '../models/character.dart';
import '../theme/app_theme.dart';
import '../widgets/character_card.dart';

class CharactersScreen extends StatefulWidget {
  const CharactersScreen({super.key});

  @override
  State<CharactersScreen> createState() => _CharactersScreenState();
}

class _CharactersScreenState extends State<CharactersScreen> {
  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    await context.read<CharacterService>().loadCharacters();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
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
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<AuthService>().logout();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _openCharacter(Character character) {
    context.read<CharacterService>().selectCharacter(character.id);
    context.read<ChatService>().clearCurrentMessages();
    Navigator.pushNamed(context, '/chat');
  }

  void _editCharacter(Character character) {
    context.read<CharacterService>().selectCharacter(character.id);
    Navigator.pushNamed(context, '/character/edit');
  }

  void _createCharacter() {
    context.read<CharacterService>().clearSelection();
    Navigator.pushNamed(context, '/character/new');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final characterService = context.watch<CharacterService>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('SynthChat'),
          ],
        ),
        actions: [
          // V2: Rooms for collaborative interactions
          IconButton(
            icon: const Icon(Icons.meeting_room_outlined),
            tooltip: 'Rooms',
            onPressed: () => Navigator.pushNamed(context, '/rooms'),
          ),
          // V4: Import character from document
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Import Character',
            onPressed: () => Navigator.pushNamed(context, '/import'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  // TODO: Settings screen
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined),
                    SizedBox(width: 12),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.error),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCharacters,
        child: characterService.isLoading
            ? const Center(child: CircularProgressIndicator())
            : characterService.characters.isEmpty
                ? _buildEmptyState()
                : _buildCharacterGrid(characterService.characters),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCharacter,
        icon: const Icon(Icons.add),
        label: const Text('New Character'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: const Icon(
                Icons.person_add,
                size: 50,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Characters Yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first AI character to start chatting!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _createCharacter,
              icon: const Icon(Icons.add),
              label: const Text('Create Character'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterGrid(List<Character> characters) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: characters.length,
        itemBuilder: (context, index) {
          final character = characters[index];
          return CharacterCard(
            character: character,
            onTap: () => _openCharacter(character),
            onLongPress: () => _editCharacter(character),
          );
        },
      ),
    );
  }
}
