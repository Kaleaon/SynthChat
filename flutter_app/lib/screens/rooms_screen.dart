import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/room_service.dart';
import '../services/auth_service.dart';
import '../services/character_service.dart';
import '../theme/app_theme.dart';

/// V2: Rooms screen for collaborative character interactions
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    final auth = context.read<AuthService>();
    final roomService = context.read<RoomService>();
    if (auth.currentUser != null) {
      await roomService.loadRooms(auth.currentUser!.id);
    }
  }

  void _showCreateRoomDialog() {
    final nameController = TextEditingController();
    bool isPublic = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Create Room'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  hintText: 'Enter a name for your room',
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Public Room'),
                subtitle: const Text('Anyone can join'),
                value: isPublic,
                onChanged: (value) {
                  setDialogState(() => isPublic = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final auth = context.read<AuthService>();
                if (auth.currentUser == null) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please log in to create a room')),
                  );
                  return;
                }
                if (nameController.text.trim().isNotEmpty) {
                  final roomService = context.read<RoomService>();
                  await roomService.createRoom(
                    name: nameController.text.trim(),
                    ownerId: auth.currentUser!.id,
                    isPublic: isPublic,
                  );
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomDetails(Room room) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => _RoomDetailsSheet(room: room),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRooms,
          ),
        ],
      ),
      body: Consumer<RoomService>(
        builder: (context, roomService, child) {
          if (roomService.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (roomService.rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.meeting_room_outlined,
                    size: 80,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Rooms Yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white.withOpacity(0.7),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a room to start collaborative interactions',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: roomService.rooms.length,
            itemBuilder: (context, index) {
              final room = roomService.rooms[index];
              return _RoomCard(
                room: room,
                onTap: () => _showRoomDetails(room),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRoomDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Room'),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;

  const _RoomCard({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: room.isPublic ? AppColors.accent : AppColors.primary,
          child: Icon(
            room.isPublic ? Icons.public : Icons.lock,
            color: Colors.white,
          ),
        ),
        title: Text(
          room.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${room.participantCount} participant${room.participantCount != 1 ? 's' : ''}',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}

class _RoomDetailsSheet extends StatefulWidget {
  final Room room;

  const _RoomDetailsSheet({required this.room});

  @override
  State<_RoomDetailsSheet> createState() => _RoomDetailsSheetState();
}

class _RoomDetailsSheetState extends State<_RoomDetailsSheet> {
  @override
  void initState() {
    super.initState();
    _loadParticipants();
  }

  Future<void> _loadParticipants() async {
    final roomService = context.read<RoomService>();
    await roomService.setCurrentRoom(widget.room.id);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: widget.room.isPublic ? AppColors.accent : AppColors.primary,
                radius: 24,
                child: Icon(
                  widget.room.isPublic ? Icons.public : Icons.lock,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.room.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      widget.room.isPublic ? 'Public Room' : 'Private Room',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Participants',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Consumer<RoomService>(
            builder: (context, roomService, child) {
              final participants = roomService.currentParticipants;
              if (participants.isEmpty) {
                return Text(
                  'No participants yet',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: participants.map((p) {
                  final displayName = p.username ?? 'U';
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    label: Text(p.characterName ?? p.username ?? 'Unknown'),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Add character to room
                    _showAddCharacterDialog();
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Character'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to room chat (future implementation)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Room chat coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('Enter Room'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddCharacterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Select Character'),
        content: Consumer<CharacterService>(
          builder: (context, characterService, child) {
            if (characterService.characters.isEmpty) {
              return const Text('No characters available');
            }
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: characterService.characters.length,
                itemBuilder: (context, index) {
                  final character = characterService.characters[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Text(
                        character.name.isNotEmpty ? character.name[0].toUpperCase() : '?',
                      ),
                    ),
                    title: Text(character.name),
                    onTap: () async {
                      final auth = context.read<AuthService>();
                      if (auth.currentUser == null) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please log in to join a room')),
                        );
                        return;
                      }
                      final roomService = context.read<RoomService>();
                      await roomService.joinRoom(
                        widget.room.id,
                        auth.currentUser!.id,
                        characterId: character.id,
                      );
                      if (mounted) Navigator.pop(context);
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
