import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import 'learning_quiz_screen.dart';

class LearningHubScreen extends ConsumerStatefulWidget {
  const LearningHubScreen({super.key});

  @override
  ConsumerState<LearningHubScreen> createState() => _LearningHubScreenState();
}

class _LearningHubScreenState extends ConsumerState<LearningHubScreen> {
  List<dynamic> _subjects = [];
  List<dynamic> _difficulties = [];
  List<dynamic> _progress = [];
  bool _loading = true;

  String? _selectedSubject;
  String? _selectedDifficulty;

  static const _subjectIcons = {
    'math': Icons.calculate,
    'english': Icons.translate,
    'german': Icons.menu_book,
  };

  static const _subjectColors = {
    'math': Colors.blue,
    'english': Colors.green,
    'german': Colors.orange,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        api.fetchLearningSubjects(),
        api.fetchLearningDifficulties(),
        api.fetchLearningProgress(),
      ]);
      setState(() {
        _subjects = results[0] as List<dynamic>;
        _difficulties = results[1] as List<dynamic>;
        _progress = results[2] as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _startQuiz() async {
    if (_selectedSubject == null || _selectedDifficulty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Fach und Schwierigkeit auswaehlen')),
      );
      return;
    }

    final api = ref.read(apiClientProvider);
    try {
      final session = await api.startLearningSession(
        subject: _selectedSubject!,
        difficulty: _selectedDifficulty!,
      );

      if (!mounted) return;
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => LearningQuizScreen(session: session),
        ),
      );

      if (result == true) {
        await _load(); // Refresh progress
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final id = subject['id'] as String;
    final name = subject['name'] as String;
    final isSelected = _selectedSubject == id;
    final color = _subjectColors[id] ?? Colors.grey;
    final icon = _subjectIcons[id] ?? Icons.school;

    // Find progress for this subject
    final subjectProgress = _progress.where((p) => p['subject'] == id).toList();
    final totalSessions = subjectProgress.fold<int>(
      0,
      (sum, p) => sum + ((p['sessions_completed'] as int?) ?? 0),
    );

    return Builder(
      builder: (context) => Card(
        elevation: isSelected ? 4 : 1,
        color: isSelected ? color.withValues(alpha: 0.15) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide(color: color, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: () => setState(() => _selectedSubject = id),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(icon, size: 48, color: color),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isSelected ? color : null,
                  ),
                ),
                if (totalSessions > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$totalSessions Uebungen',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(Map<String, dynamic> difficulty) {
    final id = difficulty['id'] as String;
    final name = difficulty['name'] as String;
    final reward = difficulty['reward_minutes'] as int;
    final isSelected = _selectedDifficulty == id;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name),
            Text(
              '$reward Min',
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
        selected: isSelected,
        onSelected: (sel) {
          if (sel) setState(() => _selectedDifficulty = id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lernen')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final selectedDiffInfo = _difficulties.firstWhere(
      (d) => d['id'] == _selectedDifficulty,
      orElse: () => null,
    );
    final rewardMinutes = selectedDiffInfo?['reward_minutes'] as int? ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lernaufgaben'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Card(
            color: Colors.purple.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.school, size: 40, color: Colors.purple),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lerne und verdiene Zeit!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Beantworte 10 Fragen richtig (mind. 70%) und erhalte Bildschirmzeit.',
                          style: TextStyle(
                            color: Colors.purple.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Subject selection
          const Text(
            'Waehle ein Fach',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: _subjects
                .map((s) => Expanded(child: _buildSubjectCard(s as Map<String, dynamic>)))
                .toList(),
          ),
          const SizedBox(height: 24),

          // Difficulty selection
          const Text(
            'Waehle die Schwierigkeit',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _difficulties
                  .map((d) => _buildDifficultyChip(d as Map<String, dynamic>))
                  .toList(),
            ),
          ),
          const SizedBox(height: 32),

          // Start button
          if (_selectedSubject != null && _selectedDifficulty != null)
            FilledButton.icon(
              onPressed: _startQuiz,
              icon: const Icon(Icons.play_arrow),
              label: Text('Starten (+$rewardMinutes Min)'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            )
          else
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Fach und Schwierigkeit auswaehlen'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

          const SizedBox(height: 32),

          // Progress section
          if (_progress.isNotEmpty) ...[
            const Text(
              'Dein Fortschritt',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ..._progress.map((p) {
              final subject = p['subject'] as String;
              final accuracy = p['accuracy_percent'] as double? ?? 0;
              final sessions = p['sessions_completed'] as int? ?? 0;
              final subjectInfo = _subjects.firstWhere(
                (s) => s['id'] == subject,
                orElse: () => {'name': subject},
              );
              final color = _subjectColors[subject] ?? Colors.grey;

              return Card(
                child: ListTile(
                  leading: Icon(_subjectIcons[subject] ?? Icons.school, color: color),
                  title: Text(subjectInfo['name'] ?? subject),
                  subtitle: Text('$sessions Uebungen abgeschlossen'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accuracy >= 70
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${accuracy.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: accuracy >= 70 ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
