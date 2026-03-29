import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class MathLabGamePage extends StatefulWidget {
  const MathLabGamePage({super.key});

  @override
  State<MathLabGamePage> createState() => _MathLabGamePageState();
}

class _MathLabGamePageState extends State<MathLabGamePage> {
  final List<_MathQuestion> _questions = [];
  int _currentIndex = 0;
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;
  bool _hasError = false;
  bool _answered = false;
  bool _isCorrect = false;
  int _score = 0;
  bool _isFinished = false;

  static const int _totalQuestions = 5;

  @override
  void initState() {
    super.initState();
    _fetchAllQuestions();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchAllQuestions() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _questions.clear();
      _currentIndex = 0;
      _score = 0;
      _isFinished = false;
      _answered = false;
      _controller.clear();
    });

    final endpoints = ['add', 'sub', 'mul', 'div', 'add'];
    final symbols = ['+', '-', '×', '÷', '+'];
    final colors = [
      const Color(0xFFFF9800),
      const Color(0xFFE53935),
      const Color(0xFF1E88E5),
      const Color(0xFF4CAF50),
      const Color(0xFFAB47BC),
    ];

    try {
      for (int i = 0; i < _totalQuestions; i++) {
        final res = await http.get(
          Uri.parse('https://shadify.yurace.pro/api/math/${endpoints[i]}'),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          _questions.add(_MathQuestion(
            expression: data['expression'] as String,
            result: data['result'].toString(),
            symbol: symbols[i],
            color: colors[i],
          ));
        }
      }
      setState(() { _isLoading = false; });
    } catch (e) {
      setState(() { _hasError = true; _isLoading = false; });
    }
  }

  void _submitAnswer() {
    if (_answered) return;
    final answer = _controller.text.trim();
    final correct = answer == _questions[_currentIndex].result;
    setState(() {
      _answered = true;
      _isCorrect = correct;
      if (correct) _score++;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _isCorrect = false;
        _controller.clear();
      });
    } else {
      setState(() { _isFinished = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildTopBar(context),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? _buildError()
                    : _isFinished
                        ? _buildFinishedScreen()
                        : _buildGame(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Text(
              'Math Lab',
              style: GoogleFonts.iceland(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1C1C1E),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Score: $_score',
                style: GoogleFonts.iceland(
                  fontSize: 18,
                  color: const Color(0xFFFF9800),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 24),
              onPressed: _fetchAllQuestions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Failed to load questions'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchAllQuestions, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildGame() {
    final q = _questions[_currentIndex];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalQuestions, (i) {
                Color color;
                if (i < _currentIndex) color = const Color(0xFF4CAF50);
                else if (i == _currentIndex) color = q.color;
                else color = Colors.grey.shade300;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 32,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              'Question ${_currentIndex + 1} of $_totalQuestions',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
            const SizedBox(height: 40),

            // Expression card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: q.color, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    q.expression,
                    style: GoogleFonts.iceland(
                      fontSize: 48,
                      color: q.color,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_answered) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isCorrect ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _isCorrect ? '✓ Correct!' : '✗ Answer: ${q.result}',
                        style: GoogleFonts.iceland(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            if (!_answered) ...[
              TextField(
                controller: _controller,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                textAlign: TextAlign.center,
                autofocus: true,
                style: GoogleFonts.iceland(fontSize: 32, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Your answer...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: q.color, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: q.color, width: 2),
                  ),
                ),
                onSubmitted: (_) => _submitAnswer(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: q.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'SUBMIT',
                    style: GoogleFonts.iceland(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1C1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: q.color, width: 2),
                    ),
                  ),
                  child: Text(
                    _currentIndex < _questions.length - 1 ? 'NEXT →' : 'FINISH',
                    style: GoogleFonts.iceland(
                      fontSize: 22,
                      color: q.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    final percent = (_score / _totalQuestions * 100).round();
    final emoji = percent == 100 ? '🏆' : percent >= 60 ? '👏' : '💪';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text(
              'Game Over!',
              style: GoogleFonts.iceland(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$_score / $_totalQuestions',
                style: GoogleFonts.iceland(
                  fontSize: 56,
                  color: const Color(0xFFFF9800),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 220,
              height: 52,
              child: ElevatedButton(
                onPressed: _fetchAllQuestions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'PLAY AGAIN',
                  style: GoogleFonts.iceland(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MathQuestion {
  final String expression;
  final String result;
  final String symbol;
  final Color color;

  const _MathQuestion({
    required this.expression,
    required this.result,
    required this.symbol,
    required this.color,
  });
}