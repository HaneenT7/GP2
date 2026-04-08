import 'package:flutter/material.dart';

class QuizPage extends StatefulWidget {
  final List quiz;

  const QuizPage({super.key, required this.quiz});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {

  int currentQuestion = 0;
  String? selectedAnswer;
  int score = 0;

  bool _quizStarted = false;

  void _startQuiz() {
    setState(() {
      _quizStarted = true;
    });
  }

  void nextQuestion() {

    final correctAnswer = widget.quiz[currentQuestion]["answer"];

    if (selectedAnswer == correctAnswer) {
      score++;
    }

    if (currentQuestion < widget.quiz.length - 1) {

      setState(() {
        currentQuestion++;
        selectedAnswer = null;
      });

    } else {

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Quiz Finished"),
          content: Text("Your score: $score / ${widget.quiz.length}"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("Close"),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    /// شاشة البداية
    if (!_quizStarted) {
      return Scaffold(
        appBar: AppBar(
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
                Icon(Icons.quiz,
                    size: 64,
                    color: Theme.of(context).primaryColor),

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
        body: const Center(
          child: Text("No questions available. Try again."),
        ),
      );
    }

    final question = widget.quiz[currentQuestion];

    /// صفحة الأسئلة
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz"),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: SafeArea(
  child: SizedBox(
    width: double.infinity,
    height: double.infinity,
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            LinearProgressIndicator(
              value: (currentQuestion + 1) / widget.quiz.length,
            ),

            const SizedBox(height: 20),

            Text(
              "Question ${currentQuestion + 1} / ${widget.quiz.length}",
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 20),

            Text(
              question["question"],
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            ...question["options"].map<Widget>((option) {

              return Card(
                child: RadioListTile(
                  value: option,
                  groupValue: selectedAnswer,
                  onChanged: (value) {
                    setState(() {
                      selectedAnswer = value.toString();
                    });
                  },
                  title: Text(option),
                ),
              );

            }).toList(),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedAnswer == null ? null : nextQuestion,
                child: Text(
                  currentQuestion == widget.quiz.length - 1
                      ? "Finish"
                      : "Next",
                ),
              ),
            )
          ],
        ),
      ),),)),
    );
  }
}