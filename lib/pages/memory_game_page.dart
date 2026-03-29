import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class MemoryGamePage extends StatefulWidget {
  const MemoryGamePage({super.key});
  @override
  State<MemoryGamePage> createState() => _MemoryGamePageState();
}

class _MemoryGamePageState extends State<MemoryGamePage> {
  List<_MemoryCard> _cards = [];
  bool _isLoading = true;
  bool _hasError = false;
  int _firstIndex = -1;
  int _secondIndex = -1;
  bool _isChecking = false;
  int _moves = 0;
  int _matchedPairs = 0;
  int _totalPairs = 0;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _fetchPuzzle();
  }

  Future<void> _fetchPuzzle() async {
    setState(() {
      _isLoading = true; _hasError = false; _cards = [];
      _firstIndex = -1; _secondIndex = -1; _isChecking = false;
      _moves = 0; _matchedPairs = 0; _totalPairs = 0; _isFinished = false;
    });
    try {
      // width=4, height=4 = 16 cells, pair-size=2 = 8 pairs
      final response = await http.get(
        Uri.parse('https://shadify.yurace.pro/api/memory/generator?width=4&height=4&pair-size=2'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // API returns: "grid" with letters (a,b,c...), "totalPairs"
        final gridRaw = data['grid'] as List;
        final totalPairs = data['totalPairs'] as int;

        List<_MemoryCard> cards = [];
        for (int r = 0; r < gridRaw.length; r++) {
          for (int c = 0; c < (gridRaw[r] as List).length; c++) {
            final letter = gridRaw[r][c] as String;
            // Convert letter to number: a=1, b=2, ...z=26, A=27...
            final value = letter.codeUnitAt(0) < 97
                ? letter.codeUnitAt(0) - 65 + 27  // uppercase A=27
                : letter.codeUnitAt(0) - 96;       // lowercase a=1
            cards.add(_MemoryCard(value: value, letter: letter));
          }
        }
        setState(() { _cards = cards; _totalPairs = totalPairs; _isLoading = false; });
      } else {
        setState(() { _hasError = true; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _hasError = true; _isLoading = false; });
    }
  }

  void _onCardTap(int index) {
    if (_isChecking || _cards[index].isMatched || _cards[index].isFlipped || _firstIndex == index) return;
    setState(() { _cards[index].isFlipped = true; });
    if (_firstIndex == -1) {
      _firstIndex = index;
    } else {
      _secondIndex = index;
      _moves++;
      _isChecking = true;
      if (_cards[_firstIndex].value == _cards[_secondIndex].value) {
        setState(() {
          _cards[_firstIndex].isMatched = true;
          _cards[_secondIndex].isMatched = true;
          _matchedPairs++;
          _firstIndex = -1; _secondIndex = -1; _isChecking = false;
          if (_matchedPairs == _totalPairs) _isFinished = true;
        });
      } else {
        Timer(const Duration(milliseconds: 900), () {
          setState(() {
            _cards[_firstIndex].isFlipped = false;
            _cards[_secondIndex].isFlipped = false;
            _firstIndex = -1; _secondIndex = -1; _isChecking = false;
          });
        });
      }
    }
  }

  static const List<Color> _cardColors = [
    Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF9800), Color(0xFF9C27B0),
    Color(0xFFE91E63), Color(0xFF00BCD4), Color(0xFFFF5722), Color(0xFF795548),
  ];

  static const List<IconData> _cardIcons = [
    Icons.star, Icons.favorite, Icons.bolt, Icons.wb_sunny,
    Icons.local_fire_department, Icons.waves, Icons.diamond, Icons.hexagon,
  ];

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
                : _hasError ? _buildError() : _isFinished ? _buildFinishedScreen() : _buildGame(),
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
            IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.of(context).pop()),
            Text('Memory', style: GoogleFonts.iceland(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C1E))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(20)),
              child: Text('Moves: $_moves', style: GoogleFonts.iceland(fontSize: 18, color: const Color(0xFF64B5F6), fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.refresh_rounded, size: 24), onPressed: _fetchPuzzle),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
        const SizedBox(height: 16),
        const Text('Failed to load puzzle'),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _fetchPuzzle, child: const Text('Retry')),
      ]),
    );
  }

  Widget _buildGame() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _totalPairs > 0 ? _matchedPairs / _totalPairs : 0,
            backgroundColor: Colors.grey.shade200,
            color: const Color(0xFF4CAF50),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text('$_matchedPairs / $_totalPairs pairs found', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10,
              ),
              itemCount: _cards.length,
              itemBuilder: (context, index) => _buildCard(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(int index) {
    final card = _cards[index];
    final colorIdx = (card.value - 1) % _cardColors.length;
    final iconIdx = (card.value - 1) % _cardIcons.length;

    return GestureDetector(
      onTap: () => _onCardTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: card.isFlipped || card.isMatched ? _cardColors[colorIdx] : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: card.isMatched || card.isFlipped ? _cardColors[colorIdx] : const Color(0xFF64B5F6),
            width: 2,
          ),
          boxShadow: card.isMatched ? [BoxShadow(color: _cardColors[colorIdx].withOpacity(0.4), blurRadius: 8)] : null,
        ),
        child: Center(
          child: card.isFlipped || card.isMatched
              ? Icon(_cardIcons[iconIdx], color: Colors.white, size: 36)
              : Text('?', style: GoogleFonts.iceland(fontSize: 32, color: const Color(0xFF64B5F6), fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏆', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 16),
          Text('You Win!', style: GoogleFonts.iceland(fontSize: 40, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C1E))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16)),
            child: Text('$_moves moves', style: GoogleFonts.iceland(fontSize: 48, color: const Color(0xFF64B5F6), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 220, height: 52,
            child: ElevatedButton(
              onPressed: _fetchPuzzle,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF64B5F6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text('PLAY AGAIN', style: GoogleFonts.iceland(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MemoryCard {
  final int value;
  final String letter;
  bool isFlipped;
  bool isMatched;
  _MemoryCard({required this.value, required this.letter, this.isFlipped = false, this.isMatched = false});
}