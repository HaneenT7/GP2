import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class MathLabGamePage extends StatefulWidget {
  final VoidCallback onExit;
  const MathLabGamePage({super.key, required this.onExit});

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
  String _typedAnswer = '';

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
      _typedAnswer = '';
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
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final dynamic rawAnswer = data['answer'] ?? data['result'];
          final expr = data['expression'];
          if (rawAnswer == null || expr == null) continue;
          _questions.add(_MathQuestion(
            expression: expr.toString(),
            result: rawAnswer.toString(),
            symbol: symbols[i],
            color: colors[i],
          ));
        }
      }
      if (_questions.length != _totalQuestions) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _pressKey(String value) {
    setState(() {
      if (value == '−') {
        if (_typedAnswer.isEmpty) _typedAnswer = '-';
      } else if (value == '⌫') {
        if (_typedAnswer.isNotEmpty) {
          _typedAnswer = _typedAnswer.substring(0, _typedAnswer.length - 1);
        }
      } else {
        if (_typedAnswer.length < 8) _typedAnswer += value;
      }
    });
  }

  void _submitAnswer() {
    if (_answered || _typedAnswer.isEmpty || _typedAnswer == '-') return;
    _controller.text = _typedAnswer;
    final answer = _typedAnswer.trim();
    final correct = _mathAnswersMatch(answer, _questions[_currentIndex].result);
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
        _typedAnswer = '';
        _controller.clear();
      });
    } else {
      setState(() {
        _isFinished = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
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
              icon: const Icon(Icons.close, size: 24),
              onPressed: widget.onExit,
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
          ElevatedButton(
              onPressed: _fetchAllQuestions, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildGame() {
    final q = _questions[_currentIndex];
    return LayoutBuilder(
      builder: (context, constraints) {
        final availH = constraints.maxHeight;
        final pad = 16.0;
        // Fixed-height elements (approximate):
        // progress row: 6 + 4 + 18 (text) + 10 = ~38
        // card vertical padding: 14*2 = 28
        // expr text: 34, gap: 8, answer box: 40
        // gap below card: 10
        // bottom row height: 42, gap: 8, submit: 42, gap: 8
        const fixedH = 38.0 + 28.0 + 34.0 + 8.0 + 40.0 + 10.0 + 42.0 + 8.0 + 42.0 + 8.0;
        // remaining space split across 3 numpad rows + 2 gaps
        final numpadH = ((availH - fixedH - pad * 2) / 4).clamp(36.0, 80.0);
        final gap = 8.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: _answered ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              // Progress bars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalQuestions, (i) {
                  Color color;
                  if (i < _currentIndex)
                    color = const Color(0xFF4CAF50);
                  else if (i == _currentIndex)
                    color = q.color;
                  else
                    color = Colors.grey.shade300;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 32,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                'Question ${_currentIndex + 1} of $_totalQuestions',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 10),

              // Expression card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: q.color, width: 2),
                ),
                child: Column(
                  children: [
                    Text(
                      q.expression,
                      style: GoogleFonts.iceland(
                        fontSize: 34,
                        color: q.color,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _answered
                              ? (_isCorrect
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFE53935))
                              : q.color.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        _typedAnswer.isEmpty ? '···' : _typedAnswer,
                        style: GoogleFonts.iceland(
                          fontSize: 26,
                          color: _typedAnswer.isEmpty
                              ? Colors.grey.shade700
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_answered) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: _isCorrect
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _isCorrect ? '✓ Correct!' : '✗ Answer: ${q.result}',
                          style: GoogleFonts.iceland(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 10),

              if (!_answered) ...[
                // 3 rows of numpad
                for (final row in [
                  ['7', '8', '9'],
                  ['4', '5', '6'],
                  ['1', '2', '3'],
                ]) ...[
                  SizedBox(
                    height: numpadH,
                    child: Row(
                      children: [
                        for (int i = 0; i < row.length; i++) ...[
                          if (i > 0) SizedBox(width: gap),
                          Expanded(child: _numpadButton(row[i], q.color)),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: gap),
                ],

                // Bottom row: −, 0, ⌫
                SizedBox(
                  height: numpadH,
                  child: Row(
                    children: [
                      Expanded(child: _numpadButton('−', q.color, outlined: true)),
                      SizedBox(width: gap),
                      Expanded(child: _numpadButton('0', q.color)),
                      SizedBox(width: gap),
                      Expanded(child: _numpadButton('⌫', q.color, outlined: true)),
                    ],
                  ),
                ),
                SizedBox(height: gap),

                // Submit
                Expanded(
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
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 24),
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
                        fontSize: 20,
                        color: q.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Builds a single numpad button.
  Widget _numpadButton(String label, Color accentColor,
      {bool outlined = false}) {
    return GestureDetector(
      onTap: () => _pressKey(label),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: outlined ? accentColor : const Color(0xFF3A3A3C),
            width: outlined ? 2 : 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.iceland(
            fontSize: 22,
            color: outlined ? accentColor : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    final percent = (_score / _totalQuestions * 100).round();
    final emoji = percent == 100
        ? '🏆'
        : percent >= 60
            ? '👏'
            : '💪';
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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

/// Shadify sends numeric [answer]; users may type "5", "5.0", or use comma decimals.
bool _mathAnswersMatch(String userAnswer, String correctAnswer) {
  final u = userAnswer.trim().replaceAll(',', '.');
  final c = correctAnswer.trim().replaceAll(',', '.');
  if (u.isEmpty) return false;
  if (u == c) return true;
  final nu = num.tryParse(u);
  final nc = num.tryParse(c);
  if (nu == null || nc == null) return false;
  final du = nu.toDouble();
  final dc = nc.toDouble();
  final tol = math.max(1e-9, math.max(du.abs(), dc.abs()) * 1e-12);
  return (du - dc).abs() <= tol;
}