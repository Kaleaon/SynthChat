import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/room_service.dart';
import '../services/auth_service.dart';
import '../services/character_service.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';

/// V2: Rooms screen for collaborative character interactions
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthService>();
    final roomService = context.read<RoomService>();
    if (auth.currentUser != null) {
      await Future.wait([
        roomService.loadRooms(auth.currentUser!.id),
        roomService.loadAllInvitations(auth.currentUser!.id),
      ]);
    }
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
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(
              icon: Icon(Icons.meeting_room),
              text: 'My Rooms',
            ),
            Consumer<RoomService>(
              builder: (context, roomService, _) {
                final count = roomService.pendingInvitationsCount;
                return Tab(
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: const Icon(Icons.mail),
                  ),
                  text: 'Invitations',
                );
              },
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRoomsTab(),
          _buildInvitationsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRoomDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Room'),
      ),
    );
  }

  Widget _buildRoomsTab() {
    return Consumer<RoomService>(
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
    );
  }

  Widget _buildInvitationsTab() {
    return Consumer<RoomService>(
      builder: (context, roomService, child) {
        final invitations = roomService.pendingInvitations;

        if (invitations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 80,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Pending Invitations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white.withOpacity(0.7),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'When someone invites you to a room, it will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: invitations.length,
          itemBuilder: (context, index) {
            final invitation = invitations[index];
            return _InvitationCard(
              invitation: invitation,
              onAccept: () => _acceptInvitation(invitation),
              onReject: () => _rejectInvitation(invitation),
            );
          },
        );
      },
    );
  }

  Future<void> _acceptInvitation(RoomInvitation invitation) async {
    final auth = context.read<AuthService>();
    if (auth.currentUser == null) return;

    final roomService = context.read<RoomService>();
    final (success, message) = await roomService.acceptInvitation(
      invitation.id,
      auth.currentUser!.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  Future<void> _rejectInvitation(RoomInvitation invitation) async {
    final auth = context.read<AuthService>();
    if (auth.currentUser == null) return;

    final roomService = context.read<RoomService>();
    final (success, message) = await roomService.rejectInvitation(
      invitation.id,
      auth.currentUser!.id,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }
}

class _InvitationCard extends StatelessWidget {
  final RoomInvitation invitation;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _InvitationCard({
    required this.invitation,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.accent,
                  child: const Icon(Icons.mail, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.roomName ?? 'Room',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Invited by ${invitation.inviterUsername ?? 'Unknown'}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (invitation.message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${invitation.message}"',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
    final auth = context.read<AuthService>();
    final isOwner = auth.currentUser?.id == widget.room.ownerId;

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
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1),
                  tooltip: 'Invite User',
                  onPressed: _showInviteUserDialog,
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
          // Invite button (prominent for owners)
          if (isOwner) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showInviteUserDialog,
                icon: const Icon(Icons.mail_outline),
                label: const Text('Invite Users to Room'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
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

  void _showInviteUserDialog() {
    final usernameController = TextEditingController();
    final messageController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1, color: AppColors.accent),
              SizedBox(width: 8),
              Text('Invite User'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite someone to join "${widget.room.name}"',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username or Email',
                  hintText: 'Enter username or email address',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: 'Message (optional)',
                  hintText: 'Add a personal message',
                  prefixIcon: Icon(Icons.message_outlined),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (usernameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a username or email'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      final auth = context.read<AuthService>();
                      if (auth.currentUser == null) {
                        Navigator.pop(dialogContext);
                        return;
                      }

                      final roomService = context.read<RoomService>();
                      final (success, message) = await roomService.inviteUserToRoom(
                        roomId: widget.room.id,
                        inviterId: auth.currentUser!.id,
                        usernameOrEmail: usernameController.text.trim(),
                        message: messageController.text.trim(),
                      );

                      if (mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(message),
                            backgroundColor: success ? AppColors.success : AppColors.error,
                          ),
                        );
                      }
                    },
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('Send Invite'),
            ),
          ],
        ),
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
