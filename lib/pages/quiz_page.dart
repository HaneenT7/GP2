import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuizPage extends StatefulWidget {
  final List quiz;

  const QuizPage({super.key, required this.quiz});

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
  bool _answered = false; // هل اختار إجابة؟

  final Map<int, String> _userAnswers = {}; // يحفظ إجابة كل سؤال

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

  /// عند اختيار إجابة — تظهر الفيدباك فقط
  void _onAnswerSelected(String option) {
    if (_answered) return; // منع التغيير بعد الاختيار

    final correctAnswer = widget.quiz[currentQuestion]["answer"];
    if (option == correctAnswer) score++;

    setState(() {
      selectedAnswer = option;
      _answered = true;
      _userAnswers[currentQuestion] = option; // احفظ الإجابة
    });
  }

  /// عند الضغط على Next / Finish
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

  /// الرجوع للسؤال السابق بحالته
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

  /// لون الخيار بناءً على الفيدباك
  Color _optionColor(String option) {
    if (!_answered) return Colors.white;

    final correctAnswer = widget.quiz[currentQuestion]["answer"];
    if (option == correctAnswer) return const Color(0xFFD4EDDA); // أخضر فاتح
    if (option == selectedAnswer) return const Color(0xFFF8D7DA); // أحمر فاتح
    return Colors.white;
  }

  /// لون border الخيار
  Color _optionBorderColor(String option) {
    if (!_answered) return Colors.grey.shade300;

    final correctAnswer = widget.quiz[currentQuestion]["answer"];
    if (option == correctAnswer) return const Color(0xFF28A745);
    if (option == selectedAnswer) return const Color(0xFFDC3545);
    return Colors.grey.shade300;
  }

  /// أيقونة الفيدباك بجانب الخيار
  Widget? _optionIcon(String option) {
    if (!_answered) return null;

    final correctAnswer = widget.quiz[currentQuestion]["answer"];
    if (option == correctAnswer) {
      return const Icon(Icons.check_circle, color: Color(0xFF28A745));
    }
    if (option == selectedAnswer) {
      return const Icon(Icons.cancel, color: Color(0xFFDC3545));
    }
    return null;
  }

  // ----------------------------------------------------------------
  // شاشة النتيجة النهائية
  // ----------------------------------------------------------------
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // صورة الشخصية — ضع الصورة في assets/images/brain_character.png
                Image.asset(
                  'assets/images/brain_character.png',
                  height: 200,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.emoji_events,
                    size: 100,
                    color: Color(0xFF5C3D9E),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  "$message $emoji",
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  "You got $score/$total",
                  style: const TextStyle(
                    fontSize: 22,
                    color: Color(0xFF444466),
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "in this quiz",
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C3D9E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Go Back to Dashboard",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // Build
  // ----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // شاشة النتيجة
    if (_quizFinished) return _buildResultScreen();

    // شاشة البداية
    if (!_quizStarted) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text("Quiz"),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.quiz, size: 64, color: Theme.of(context).primaryColor),
                const SizedBox(height: 24),
                const Text(
                  "Ready to test your knowledge?",
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _startQuiz,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text("Start Your Quiz"),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (widget.quiz.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Quiz"),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text("No questions available. Try again.")),
      );
    }

    final question = widget.quiz[currentQuestion];

    // شاشة الأسئلة
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("Quiz"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: (currentQuestion + 1) / widget.quiz.length,
              ),

              const SizedBox(height: 16),

              Text(
                "Question ${currentQuestion + 1} / ${widget.quiz.length}",
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),

              const SizedBox(height: 16),

              Text(
                question["question"],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // الخيارات
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
                      border: Border.all(
                        color: _optionBorderColor(option),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
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
                  // زر Back — يسار — يظهر من السؤال الثاني
                  if (currentQuestion > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _prevQuestion,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text("Back"),
                      ),
                    ),

                  if (currentQuestion > 0) const SizedBox(width: 12),

                  // زر Next/Finish — يمين — يظهر فقط بعد الإجابة
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _answered ? _nextQuestion : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        currentQuestion == widget.quiz.length - 1
                            ? "Finish"
                            : "Next",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}