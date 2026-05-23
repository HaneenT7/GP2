import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class QuizPage extends StatefulWidget {
  final List quiz;
  final VoidCallback onExit; // لاستدعاء الخروج من صفحة الهبوط
  
  // Optional: Task auto-completion parameters
  final String? taskDocId;
  final String? taskId;
  final String? dateKey;
  final List? fullDailyTasks;

  const QuizPage({
    super.key,
    required this.quiz,
    required this.onExit,
    this.taskDocId,
    this.taskId,
    this.dateKey,
    this.fullDailyTasks,
  });

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int currentQuestion = 0;
  String? selectedAnswer;
  int score = 0;

  bool _quizStarted = false;
  bool _quizFinished = false;
  bool _answered = false;

  final Map<int, String> _userAnswers = {};

  void _startQuiz() {
    setState(() {
      _quizStarted = true;
    });
  }

  Future<void> _saveQuizResult() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _firestore
          .collection('students')
          .doc(user.uid)
          .collection('quizResults')
          .add({
        'correct': score,
        'total': widget.quiz.length,
        'completedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Failed to save quiz result: $e');
    }
  }

  void _onAnswerSelected(String option) {
    if (_answered) return;
    final correctAnswer = widget.quiz[currentQuestion]["answer"];
    if (option == correctAnswer) score++;
    setState(() {
      selectedAnswer = option;
      _answered = true;
      _userAnswers[currentQuestion] = option;
    });
  }

  void _nextQuestion() {
    if (currentQuestion < widget.quiz.length - 1) {
      final saved = _userAnswers[currentQuestion + 1];
      setState(() {
        currentQuestion++;
        selectedAnswer = saved;
        _answered = saved != null;
      });
    } else {
      _saveQuizResult();
      setState(() {
        _quizFinished = true;
      });
    }
  }

  void _prevQuestion() {
    if (currentQuestion > 0) {
      final saved = _userAnswers[currentQuestion - 1];
      setState(() {
        currentQuestion--;
        selectedAnswer = saved;
        _answered = saved != null;
      });
    }
  }

  Color _optionColor(String option) {
    if (!_answered) return Colors.white;
    final correctAnswer = widget.quiz[currentQuestion]["answer"];
    if (option == correctAnswer) return const Color(0xFFD4EDDA);
    if (option == selectedAnswer) return const Color(0xFFF8D7DA);
    return Colors.white;
  }

  Color _optionBorderColor(String option) {
    if (!_answered) return Colors.grey.shade300;
    final correctAnswer = widget.quiz[currentQuestion]["answer"];
    if (option == correctAnswer) return const Color(0xFF28A745);
    if (option == selectedAnswer) return const Color(0xFFDC3545);
    return Colors.grey.shade300;
  }

  Widget? _optionIcon(String option) {
    if (!_answered) return null;
    final correctAnswer = widget.quiz[currentQuestion]["answer"];
    if (option == correctAnswer) return const Icon(Icons.check_circle, color: Color(0xFF28A745));
    if (option == selectedAnswer) return const Icon(Icons.cancel, color: Color(0xFFDC3545));
    return null;
  }

  Widget _buildResultScreen() {
    final total = widget.quiz.length;
    final percentage = score / total;

    String message;
    String emoji;
    if (percentage == 1.0) {
      message = "Excellent!";
      emoji = "✨";
    } else if (percentage >= 0.7) {
      message = "Great Job!";
      emoji = "👏";
    } else if (percentage >= 0.5) {
      message = "Good Try!";
      emoji = "💪";
    } else {
      message = "Keep Practicing!";
      emoji = "📚";
    }

    // Auto-mark task as done if score >= 80%
    if (percentage >= 0.8 && widget.taskDocId != null && widget.taskId != null && 
        widget.dateKey != null && widget.fullDailyTasks != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoMarkTaskAsDone();
      });
    }

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/brain_character.png',
                height: 200,
                errorBuilder: (_, __, ___) => const Icon(Icons.emoji_events, size: 100, color: Color(0xFF5C3D9E)),
              ),
              const SizedBox(height: 24),
              Text("$message $emoji", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 12),
              Text("You got $score/$total", style: const TextStyle(fontSize: 22, color: Color(0xFF444466), fontWeight: FontWeight.w600)),
              
              // Show auto-mark notification if applicable
              if (percentage >= 0.8) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4EDDA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF28A745), width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF28A745), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Task marked as completed!',
                        style: TextStyle(color: Color(0xFF155724), fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onExit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C3D9E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Ok", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _autoMarkTaskAsDone() async {
    try {
      final docId = widget.taskDocId;
      final taskId = widget.taskId;
      final dateKey = widget.dateKey;
      final fullDailyTasks = widget.fullDailyTasks;

      if (docId == null || taskId == null || dateKey == null || fullDailyTasks == null) {
        return;
      }

      // Update the task's completed status
      for (var day in fullDailyTasks) {
        if (day['date'] == dateKey) {
          for (var t in day['tasks']) {
            if (t['taskId'] == taskId) {
              t['completed'] = true;
            }
          }
        }
      }

      // Write back to Firestore
      await FirebaseFirestore.instance
          .collection('revisionPlans')
          .doc(docId)
          .update({'dailyTasks': jsonEncode(fullDailyTasks)});
    } catch (e) {
      debugPrint('Error auto-marking task as done: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_quizFinished) return _buildResultScreen();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: widget.onExit, // يعود لصفحة الهبوط
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_quizStarted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.quiz, size: 64, color: Theme.of(context).primaryColor),
              const SizedBox(height: 24),
              const Text("Ready to test your knowledge?", style: TextStyle(fontSize: 18), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _startQuiz, child: const Text("Start Your Quiz")),
              ),
            ],
          ),
        ),
      );
    }

    final question = widget.quiz[currentQuestion];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: (currentQuestion + 1) / widget.quiz.length),
            const SizedBox(height: 16),
            Text("Question ${currentQuestion + 1} / ${widget.quiz.length}", style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 16),
            Text(question["question"], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ...question["options"].map<Widget>((option) {
              final icon = _optionIcon(option);
              return GestureDetector(
                onTap: () => _onAnswerSelected(option.toString()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: _optionColor(option),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _optionBorderColor(option), width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(child: Text(option, style: const TextStyle(fontSize: 16))),
                        if (icon != null) icon,
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 30),
            Row(
              children: [
                if (currentQuestion > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _prevQuestion,
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text("Back"),
                    ),
                  ),
                if (currentQuestion > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _answered ? _nextQuestion : null,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: Text(currentQuestion == widget.quiz.length - 1 ? "Finish" : "Next"),
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