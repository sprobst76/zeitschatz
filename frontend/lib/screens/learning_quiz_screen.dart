import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';

class LearningQuizScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> session;

  const LearningQuizScreen({super.key, required this.session});

  @override
  ConsumerState<LearningQuizScreen> createState() => _LearningQuizScreenState();
}

class _LearningQuizScreenState extends ConsumerState<LearningQuizScreen> {
  final _answerController = TextEditingController();
  final _answerFocus = FocusNode();

  Map<String, dynamic>? _currentQuestion;
  bool _loading = true;
  bool _submitting = false;
  bool? _lastAnswerCorrect;
  String? _correctAnswer;
  int _correctCount = 0;
  int _wrongCount = 0;
  int _totalQuestions = 10;

  Timer? _timer;
  int _elapsedSeconds = 0;

  bool _showingResult = false;
  Map<String, dynamic>? _sessionResult;

  static const _subjectNames = {
    'math': 'Mathe',
    'english': 'Englisch',
    'german': 'Deutsch',
  };

  @override
  void initState() {
    super.initState();
    _totalQuestions = widget.session['total_questions'] as int? ?? 10;
    _startTimer();
    _loadQuestion();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _answerController.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _loadQuestion() async {
    final api = ref.read(apiClientProvider);
    setState(() {
      _loading = true;
      _lastAnswerCorrect = null;
      _correctAnswer = null;
    });

    try {
      final question = await api.getLearningQuestion(widget.session['session_id'] as int);
      setState(() {
        _currentQuestion = question;
        _loading = false;
      });
      _answerController.clear();
      _answerFocus.requestFocus();
    } catch (e) {
      // No more questions - complete session
      await _completeSession();
    }
  }

  Future<void> _submitAnswer() async {
    if (_answerController.text.trim().isEmpty) return;

    final api = ref.read(apiClientProvider);
    setState(() => _submitting = true);

    try {
      final result = await api.submitLearningAnswer(
        sessionId: widget.session['session_id'] as int,
        questionIndex: _currentQuestion!['question_index'] as int,
        answer: _answerController.text.trim(),
      );

      final isCorrect = result['correct'] as bool;
      setState(() {
        _lastAnswerCorrect = isCorrect;
        _correctAnswer = result['correct_answer'] as String?;
        _correctCount = result['current_score'] as int? ?? 0;
        _wrongCount = (result['total_answered'] as int? ?? 0) - _correctCount;
        _submitting = false;
      });

      // Wait a moment to show result, then load next question
      await Future.delayed(Duration(milliseconds: isCorrect ? 800 : 1500));

      final totalAnswered = result['total_answered'] as int? ?? 0;
      if (totalAnswered >= _totalQuestions) {
        await _completeSession();
      } else {
        await _loadQuestion();
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _completeSession() async {
    _timer?.cancel();

    final api = ref.read(apiClientProvider);
    try {
      final result = await api.completeLearningSession(widget.session['session_id'] as int);
      setState(() {
        _sessionResult = result;
        _showingResult = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
      Navigator.pop(context, false);
    }
  }

  Widget _buildResultScreen() {
    final passed = _sessionResult!['passed'] as bool? ?? false;
    final correct = _sessionResult!['correct_answers'] as int? ?? 0;
    final total = _sessionResult!['total_questions'] as int? ?? 10;
    final reward = _sessionResult!['tan_reward'] as int? ?? 0;
    final time = _sessionResult!['time_seconds'] as int? ?? 0;

    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                passed ? Icons.celebration : Icons.sentiment_neutral,
                size: 80,
                color: passed ? Colors.amber : Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                passed ? 'Geschafft!' : 'Nicht ganz...',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: passed ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatCard('Richtig', '$correct', Colors.green),
                  const SizedBox(width: 16),
                  _buildStatCard('Falsch', '${total - correct}', Colors.red),
                  const SizedBox(width: 16),
                  _buildStatCard('Zeit', _formatTime(time), Colors.blue),
                ],
              ),
              const SizedBox(height: 24),
              if (passed)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        '+$reward Minuten verdient!',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'Du brauchst mindestens 70% richtige Antworten.',
                        style: TextStyle(color: Colors.orange),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Versuche es nochmal!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check),
                label: const Text('Fertig'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showingResult) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_subjectNames[widget.session['subject']] ?? 'Quiz'),
          automaticallyImplyLeading: false,
        ),
        body: _buildResultScreen(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_subjectNames[widget.session['subject']] ?? 'Quiz'),
        actions: [
          Builder(
            builder: (context) => Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_elapsedSeconds),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Progress bar
                  Row(
                    children: [
                      Text(
                        'Frage ${(_currentQuestion?['question_index'] ?? 0) + 1} von $_totalQuestions',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_correctCount richtig',
                          style: const TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_wrongCount falsch',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) => LinearProgressIndicator(
                      value: ((_currentQuestion?['question_index'] ?? 0) + 1) / _totalQuestions,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Question card
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentQuestion?['question'] ?? '',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_currentQuestion?['hint'] != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.lightbulb, color: Colors.amber),
                                    const SizedBox(width: 8),
                                    Text(
                                      _currentQuestion!['hint'],
                                      style: const TextStyle(color: Colors.amber),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),

                            // Answer input
                            TextField(
                              controller: _answerController,
                              focusNode: _answerFocus,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 24),
                              decoration: InputDecoration(
                                hintText: 'Deine Antwort',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: _lastAnswerCorrect == null
                                    ? null
                                    : _lastAnswerCorrect!
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : Colors.red.withValues(alpha: 0.15),
                              ),
                              onSubmitted: (_) => _submitAnswer(),
                              enabled: !_submitting && _lastAnswerCorrect == null,
                            ),

                            // Feedback
                            if (_lastAnswerCorrect != null) ...[
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _lastAnswerCorrect! ? Icons.check_circle : Icons.cancel,
                                    color: _lastAnswerCorrect! ? Colors.green : Colors.red,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _lastAnswerCorrect! ? 'Richtig!' : 'Falsch!',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: _lastAnswerCorrect! ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              if (!_lastAnswerCorrect!) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Richtige Antwort: $_correctAnswer',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting || _lastAnswerCorrect != null
                          ? null
                          : _submitAnswer,
                      icon: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Antwort pruefen'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
