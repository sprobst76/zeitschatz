import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';

class ChildAchievementsScreen extends ConsumerStatefulWidget {
  const ChildAchievementsScreen({super.key});

  @override
  ConsumerState<ChildAchievementsScreen> createState() => _ChildAchievementsScreenState();
}

class _ChildAchievementsScreenState extends ConsumerState<ChildAchievementsScreen> {
  List<dynamic> _achievements = [];
  bool _loading = true;
  List<dynamic> _newlyUnlocked = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final api = ref.read(apiClientProvider);
    try {
      // Check for new achievements first
      final checkResult = await api.checkAchievements();
      final newlyUnlocked = checkResult['newly_unlocked'] as List<dynamic>? ?? [];

      // Fetch all achievements
      final achievements = await api.fetchAchievements();

      if (!mounted) return;
      setState(() {
        _achievements = achievements;
        _newlyUnlocked = newlyUnlocked;
        _loading = false;
      });

      // Show celebration dialog for newly unlocked achievements
      if (newlyUnlocked.isNotEmpty) {
        _showCelebrationDialog(newlyUnlocked);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showCelebrationDialog(List<dynamic> achievements) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            const Text('Neues Achievement!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: achievements.map((a) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _buildAchievementIcon(a['icon'] ?? 'star', true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Builder(
                          builder: (context) => Text(
                            a['description'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (a['reward_minutes'] != null)
                          Text(
                            '+${a['reward_minutes']} Bonus-Minuten!',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Super!'),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementIcon(String iconName, bool unlocked) {
    IconData icon;
    switch (iconName) {
      case 'local_fire_department':
        icon = Icons.local_fire_department;
        break;
      case 'star':
        icon = Icons.star;
        break;
      case 'military_tech':
        icon = Icons.military_tech;
        break;
      case 'workspace_premium':
        icon = Icons.workspace_premium;
        break;
      case 'emoji_events':
        icon = Icons.emoji_events;
        break;
      case 'school':
        icon = Icons.school;
        break;
      case 'psychology':
        icon = Icons.psychology;
        break;
      case 'wb_sunny':
        icon = Icons.wb_sunny;
        break;
      case 'celebration':
        icon = Icons.celebration;
        break;
      case 'photo_camera':
        icon = Icons.photo_camera;
        break;
      default:
        icon = Icons.star;
    }

    return Builder(
      builder: (context) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: unlocked
              ? Colors.amber.withValues(alpha: 0.15)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          boxShadow: unlocked
              ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2)]
              : null,
        ),
        child: Icon(
          icon,
          color: unlocked
              ? Colors.amber
              : Theme.of(context).colorScheme.onSurfaceVariant,
          size: 24,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final unlocked = _achievements.where((a) => a['unlocked'] == true).toList();
    final locked = _achievements.where((a) => a['unlocked'] != true).toList();

    // Group by category
    final categories = <String, List<dynamic>>{};
    for (final a in _achievements) {
      final cat = a['category'] as String? ?? 'general';
      categories.putIfAbsent(cat, () => []).add(a);
    }

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary
          Card(
            color: Colors.amber.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, size: 40, color: Colors.amber),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${unlocked.length} von ${_achievements.length}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const Text('Achievements freigeschaltet'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Categories
          ..._buildCategorySection('streak', 'Streak', Icons.local_fire_department, categories['streak'] ?? []),
          ..._buildCategorySection('tasks', 'Aufgaben', Icons.task_alt, categories['tasks'] ?? []),
          ..._buildCategorySection('learning', 'Lernen', Icons.school, categories['learning'] ?? []),
          ..._buildCategorySection('special', 'Spezial', Icons.auto_awesome, categories['special'] ?? []),
        ],
      ),
    );
  }

  List<Widget> _buildCategorySection(String key, String title, IconData icon, List<dynamic> achievements) {
    if (achievements.isEmpty) return [];

    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
      ...achievements.map((a) => _buildAchievementCard(a)),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildAchievementCard(Map<String, dynamic> achievement) {
    final unlocked = achievement['unlocked'] == true;
    final name = achievement['name'] ?? '';
    final description = achievement['description'] ?? '';
    final iconName = achievement['icon'] ?? 'star';
    final rewardMinutes = achievement['reward_minutes'] as int?;

    return Builder(
      builder: (context) => Card(
        color: unlocked ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ListTile(
          leading: _buildAchievementIcon(iconName, unlocked),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: unlocked ? null : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: unlocked
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
              if (rewardMinutes != null)
                Text(
                  unlocked ? 'Bonus: $rewardMinutes Min' : '+$rewardMinutes Min bei Freischaltung',
                  style: TextStyle(
                    fontSize: 11,
                    color: unlocked ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontWeight: unlocked ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
            ],
          ),
          trailing: unlocked
              ? const Icon(Icons.check_circle, color: Colors.green)
              : Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
