import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/personality_evolution_service.dart';
import '../models/character.dart';
import '../theme/app_theme.dart';

/// V5: Personality evolution screen with mood tracking and internal reasoning
class PersonalityScreen extends StatefulWidget {
  const PersonalityScreen({super.key});

  @override
  State<PersonalityScreen> createState() => _PersonalityScreenState();
}

class _PersonalityScreenState extends State<PersonalityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Character? _character;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Character && args != _character) {
      _character = args;
      _loadPersonality();
    }
  }

  Future<void> _loadPersonality() async {
    if (_character == null) return;
    final service = context.read<PersonalityEvolutionService>();
    await service.loadCharacterPersonality(_character!.id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_character?.name ?? 'Personality'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.mood), text: 'Mood'),
            Tab(icon: Icon(Icons.psychology), text: 'Traits'),
            Tab(icon: Icon(Icons.timeline), text: 'Evolution'),
          ],
        ),
      ),
      body: Consumer<PersonalityEvolutionService>(
        builder: (context, service, child) {
          if (service.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _MoodTab(service: service, character: _character),
              _TraitsTab(service: service, character: _character),
              _EvolutionTab(service: service),
            ],
          );
        },
      ),
    );
  }
}

class _MoodTab extends StatelessWidget {
  final PersonalityEvolutionService service;
  final Character? character;

  const _MoodTab({required this.service, this.character});

  @override
  Widget build(BuildContext context) {
    final mood = service.currentMood;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Current mood display
          Card(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    mood?.emoji ?? '😐',
                    style: const TextStyle(fontSize: 64),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Current Mood',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (mood?.current ?? 'Neutral').toUpperCase(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Color(mood?.color ?? 0xFF808080),
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  // Intensity bar
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Intensity'),
                          Text('${((mood?.intensity ?? 0.5) * 100).toInt()}%'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: mood?.intensity ?? 0.5,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation(
                          Color(mood?.color ?? 0xFF808080),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Mood selector
          Text(
            'Set Mood Manually',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PersonalityEvolutionService.availableMoods.map((moodName) {
              final isSelected = mood?.current == moodName;
              final moodState = MoodState(current: moodName, intensity: 0.5);
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(moodState.emoji),
                    const SizedBox(width: 4),
                    Text(moodName.capitalize()),
                  ],
                ),
                selected: isSelected,
                onSelected: character != null
                    ? (_) {
                        service.updateMood(character!.id, moodName, 0.7);
                      }
                    : null,
                selectedColor: Color(moodState.color),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TraitsTab extends StatelessWidget {
  final PersonalityEvolutionService service;
  final Character? character;

  const _TraitsTab({required this.service, this.character});

  @override
  Widget build(BuildContext context) {
    final traits = service.currentTraits;

    if (traits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Traits Developed Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white.withOpacity(0.7),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Traits evolve through conversations',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: traits.length,
      itemBuilder: (context, index) {
        final entry = traits.entries.elementAt(index);
        return _TraitCard(
          name: entry.key,
          value: entry.value,
          onChanged: character != null
              ? (delta) {
                  service.evolveTrait(character!.id, entry.key, delta);
                }
              : null,
        );
      },
    );
  }
}

class _TraitCard extends StatelessWidget {
  final String name;
  final double value;
  final void Function(double)? onChanged;

  const _TraitCard({
    required this.name,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name.capitalize(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${(value * 100).toInt()}%',
                  style: TextStyle(
                    color: _getTraitColor(value),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(_getTraitColor(value)),
            ),
            if (onChanged != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 16),
                    onPressed: () => onChanged!(-0.05),
                    tooltip: 'Decrease',
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: () => onChanged!(0.05),
                    tooltip: 'Increase',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getTraitColor(double value) {
    if (value >= 0.8) return Colors.green;
    if (value >= 0.6) return Colors.lightGreen;
    if (value >= 0.4) return Colors.orange;
    if (value >= 0.2) return Colors.deepOrange;
    return Colors.red;
  }
}

class _EvolutionTab extends StatelessWidget {
  final PersonalityEvolutionService service;

  const _EvolutionTab({required this.service});

  @override
  Widget build(BuildContext context) {
    final events = service.events;

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Evolution History',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white.withOpacity(0.7),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Personality changes will appear here',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return _EventCard(event: event);
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  final PersonalityEvent event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.3),
          child: Text(
            event.icon,
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(event.eventType.replaceAll('_', ' ').capitalize()),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.description,
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(event.createdAt),
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.month}/${date.day}/${date.year}';
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
