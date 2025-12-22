import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';

class ParentStatsScreen extends ConsumerStatefulWidget {
  const ParentStatsScreen({super.key});

  @override
  ConsumerState<ParentStatsScreen> createState() => _ParentStatsScreenState();
}

class _ParentStatsScreenState extends ConsumerState<ParentStatsScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final stats = await api.fetchStatsOverview();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Fehler: $_error'),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Erneut versuchen')),
          ],
        ),
      );
    }

    final stats = _stats!;
    final summary = stats['summary'] as Map<String, dynamic>;
    final children = stats['children'] as List<dynamic>;
    final deviceUsage = stats['device_usage'] as List<dynamic>;
    final weeklyTrend = stats['weekly_trend'] as List<dynamic>;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary Cards
          _buildSummaryCards(summary),
          const SizedBox(height: 24),

          // Children Stats
          const Text(
            'Kinder',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children.map((child) => _buildChildCard(child)),
          const SizedBox(height: 24),

          // Device Usage
          const Text(
            'Geraete-Nutzung',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildDeviceUsageCard(deviceUsage),
          const SizedBox(height: 24),

          // Weekly Trend
          const Text(
            'Wochen-Trend',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildWeeklyTrendCard(weeklyTrend),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryCard(
          icon: Icons.people,
          label: 'Kinder',
          value: '${summary['total_children']}',
          color: Colors.blue,
        ),
        _SummaryCard(
          icon: Icons.check_circle,
          label: 'Erledigt',
          value: '${summary['total_completed_all']}',
          color: Colors.green,
        ),
        _SummaryCard(
          icon: Icons.pending,
          label: 'Offen',
          value: '${summary['total_pending']}',
          color: Colors.orange,
        ),
        _SummaryCard(
          icon: Icons.timer,
          label: 'Minuten',
          value: '${summary['total_minutes_all']}',
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    final streak = child['current_streak'] as int;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Builder(
                  builder: (context) => CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      (child['child_name'] as String? ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child['child_name'] ?? 'Kind',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Builder(
                        builder: (context) => Text(
                          '${child['total_minutes_earned']} Minuten verdient',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (streak > 0) _StreakBadge(streak: streak),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatItem(
                  label: 'Gesamt',
                  value: '${child['total_completed']}',
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(width: 24),
                _StatItem(
                  label: 'Diese Woche',
                  value: '${child['week_completed']}',
                  icon: Icons.date_range,
                ),
                const SizedBox(width: 24),
                _StatItem(
                  label: 'Dieser Monat',
                  value: '${child['month_completed']}',
                  icon: Icons.calendar_month,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceUsageCard(List<dynamic> deviceUsage) {
    if (deviceUsage.isEmpty) {
      return Builder(
        builder: (context) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Noch keine Daten',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    final totalMinutes = deviceUsage.fold<int>(
      0,
      (sum, d) => sum + ((d['total_minutes'] as int?) ?? 0),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: deviceUsage.map((device) {
            final minutes = (device['total_minutes'] as int?) ?? 0;
            final count = (device['count'] as int?) ?? 0;
            final deviceName = device['device'] as String? ?? 'unknown';
            final percentage = totalMinutes > 0 ? minutes / totalMinutes : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(_deviceIcon(deviceName), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _deviceLabel(deviceName),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Builder(
                              builder: (context) => Text(
                                '$minutes Min ($count TANs)',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Builder(
                          builder: (context) => ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percentage,
                              minHeight: 8,
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            ),
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
      ),
    );
  }

  Widget _buildWeeklyTrendCard(List<dynamic> weeklyTrend) {
    if (weeklyTrend.isEmpty) {
      return Builder(
        builder: (context) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Noch keine Daten',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }

    final maxCompleted = weeklyTrend.fold<int>(
      1,
      (max, w) => (w['completed'] as int) > max ? w['completed'] as int : max,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: weeklyTrend.asMap().entries.map((entry) {
            final week = entry.value;
            final completed = (week['completed'] as int?) ?? 0;
            final height = maxCompleted > 0 ? (completed / maxCompleted) * 80 : 0.0;
            final weekStart = week['week_start'] as String? ?? '';
            final weekLabel = _formatWeekLabel(weekStart);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$completed',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 40,
                  height: height.clamp(8.0, 80.0),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Builder(
                  builder: (context) => Text(
                    weekLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatWeekLabel(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}.${date.month}';
    } catch (_) {
      return isoDate.substring(5, 10);
    }
  }

  IconData _deviceIcon(String device) {
    switch (device) {
      case 'phone':
        return Icons.phone_android;
      case 'tablet':
        return Icons.tablet_android;
      case 'pc':
        return Icons.computer;
      default:
        return Icons.devices;
    }
  }

  String _deviceLabel(String device) {
    switch (device) {
      case 'phone':
        return 'Handy';
      case 'tablet':
        return 'Tablet';
      case 'pc':
        return 'PC';
      default:
        return device;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Builder(
              builder: (context) => Text(
                label,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;

  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department, size: 18, color: Colors.orange),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
