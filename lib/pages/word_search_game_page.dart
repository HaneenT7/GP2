import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class WordSearchGamePage extends StatefulWidget {
  const WordSearchGamePage({super.key});
  @override
  State<WordSearchGamePage> createState() => _WordSearchGamePageState();
}

class _WordSearchGamePageState extends State<WordSearchGamePage> {
  final GlobalKey _gridKey = GlobalKey();

  List<List<String>> _grid = [];
  List<String> _words = [];
  List<String> _foundWords = [];
  bool _isLoading = true;
  bool _hasError = false;
  int? _startRow, _startCol, _endRow, _endCol;
  bool _isDragging = false;
  List<List<List<int>>> _solvedCells = [];

  @override
  void initState() {
    super.initState();
    _fetchPuzzle();
  }

  Future<void> _fetchPuzzle() async {
    setState(() {
      _isLoading = true; _hasError = false;
      _foundWords = []; _solvedCells = [];
      _startRow = null; _startCol = null; _endRow = null; _endCol = null;
    });
    try {
      final response = await http.get(
        Uri.parse('https://shadify.yurace.pro/api/wordsearch/generator?width=10&height=10'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // API returns: "grid" (not "field"), "words" is list of objects {word, position}
        final gridRaw = data['grid'] as List;
        final wordsRaw = data['words'] as List;

        final grid = gridRaw.map<List<String>>((row) =>
            (row as List).map<String>((e) => (e as String).toUpperCase()).toList()).toList();

        // words is a list of objects: {"word": "...", "position": {...}}
        final words = wordsRaw.map<String>((w) {
          if (w is Map) return (w['word'] as String).toUpperCase();
          return (w as String).toUpperCase();
        }).toList();

        setState(() { _grid = grid; _words = words; _isLoading = false; });
      } else {
        setState(() { _hasError = true; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _hasError = true; _isLoading = false; });
    }
  }

  List<List<int>> _getCellsBetween(int r1, int c1, int r2, int c2) {
    final cells = <List<int>>[];
    final dr = r2 == r1 ? 0 : (r2 - r1) ~/ (r2 - r1).abs();
    final dc = c2 == c1 ? 0 : (c2 - c1) ~/ (c2 - c1).abs();
    int r = r1, c = c1;
    while (true) {
      cells.add([r, c]);
      if (r == r2 && c == c2) break;
      r += dr; c += dc;
    }
    return cells;
  }

  String _buildWordFromCells(List<List<int>> cells) =>
      cells.map((cell) => _grid[cell[0]][cell[1]]).join();

  bool _isValidDirection(int r1, int c1, int r2, int c2) {
    final dr = r2 - r1; final dc = c2 - c1;
    return dr == 0 || dc == 0 || dr.abs() == dc.abs();
  }

  void _onPanStart(int row, int col) {
    setState(() { _isDragging = true; _startRow = row; _startCol = col; _endRow = row; _endCol = col; });
  }

  void _onPanUpdate(int row, int col) {
    if (!_isDragging) return;
    setState(() { _endRow = row; _endCol = col; });
  }

  void _onPanEnd(BuildContext context) {
    if (_startRow == null || _startCol == null || _endRow == null || _endCol == null) {
      setState(() { _isDragging = false; _startRow = null; _startCol = null; _endRow = null; _endCol = null; });
      return;
    }
    if (_isValidDirection(_startRow!, _startCol!, _endRow!, _endCol!)) {
      final cells = _getCellsBetween(_startRow!, _startCol!, _endRow!, _endCol!);
      final word = _buildWordFromCells(cells);
      final reversed = word.split('').reversed.join();
      String? matched;
      if (_words.contains(word) && !_foundWords.contains(word)) {
        matched = word;
      } else if (_words.contains(reversed) && !_foundWords.contains(reversed)) {
        matched = reversed;
      }
      if (matched != null) {
        final foundWord = matched;
        setState(() {
          _foundWords.add(foundWord);
          _solvedCells.add(cells);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Correct! Found: $foundWord',
                textAlign: TextAlign.center),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    }
    setState(() { _isDragging = false; _startRow = null; _startCol = null; _endRow = null; _endCol = null; });
  }

  bool _isCellSelected(int row, int col) {
    if (!_isDragging || _startRow == null || _endRow == null) return false;
    if (!_isValidDirection(_startRow!, _startCol!, _endRow!, _endCol!)) return false;
    return _getCellsBetween(_startRow!, _startCol!, _endRow!, _endCol!).any((c) => c[0] == row && c[1] == col);
  }

  int _getSolvedColorIndex(int row, int col) {
    for (int i = 0; i < _solvedCells.length; i++) {
      if (_solvedCells[i].any((c) => c[0] == row && c[1] == col)) return i;
    }
    return -1;
  }

  static const _solvedColors = [
    Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF9800),
    Color(0xFF9C27B0), Color(0xFFE91E63), Color(0xFF00BCD4),
    Color(0xFFFF5722), Color(0xFF795548), Color(0xFF607D8B), Color(0xFF8BC34A),
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
                : _hasError ? _buildError() : _buildGame(),
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
            Text('Search Words', style: GoogleFonts.iceland(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C1E))),
            const Spacer(),
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
    final isComplete = _foundWords.length == _words.length && _words.isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (isComplete) _buildWinBanner(),
          _buildWordList(),
          const SizedBox(height: 20),
          _buildGrid(),
        ],
      ),
    );
  }

  Widget _buildWinBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: BoxDecoration(color: const Color(0xFF4CAF50), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.emoji_events, color: Colors.white),
        const SizedBox(width: 8),
        Text('All Words Found! 🎉', style: GoogleFonts.iceland(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildWordList() {
    return Wrap(
      spacing: 10, runSpacing: 8, alignment: WrapAlignment.center,
      children: _words.map((w) {
        final found = _foundWords.contains(w);
        final colorIdx = _foundWords.indexOf(w);
        final color = found && colorIdx >= 0 ? _solvedColors[colorIdx % _solvedColors.length] : const Color(0xFF1C1C1E);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: found ? color : const Color(0xFF64B5F6), width: 1.5),
          ),
          child: Text(
            found ? '✓ $w' : w,
            style: GoogleFonts.iceland(
              fontSize: 18, color: Colors.white,
              decoration: found ? TextDecoration.lineThrough : null,
              decorationColor: Colors.white,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGrid() {
    if (_grid.isEmpty) return const SizedBox.shrink();
    final rows = _grid.length;
    final cols = _grid[0].length;

    return LayoutBuilder(builder: (context, constraints) {
      const outline = 2.0;
      final availW = constraints.maxWidth;
      // Outer stroke fits inside [availW]; inner cells fill remainder so Row sum never overflows.
      final innerW = availW - 2 * outline;
      final cellSize = innerW / cols;
      final gridH = cellSize * rows;

      void pointerToCell(Offset global, void Function(int r, int c) fn) {
        final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(global);
        // Pointer coords are inside padded inner content (outline inset).
        final ix = (local.dx - outline).clamp(0.0, innerW);
        final iy = (local.dy - outline).clamp(0.0, gridH);
        final c = (ix / cellSize).floor().clamp(0, cols - 1);
        final r = (iy / cellSize).floor().clamp(0, rows - 1);
        fn(r, c);
      }

      return SizedBox(
        width: availW,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            pointerToCell(details.globalPosition, (r, c) => _onPanStart(r, c));
          },
          onPanUpdate: (details) {
            pointerToCell(details.globalPosition, (r, c) => _onPanUpdate(r, c));
          },
          onPanEnd: (_) => _onPanEnd(context),
          onPanCancel: () => _onPanEnd(context),
          child: Container(
            key: _gridKey,
            width: availW,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFF64B5F6), width: outline),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(rows, (row) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(cols, (col) {
                      final selected = _isCellSelected(row, col);
                      final solvedIdx = _getSolvedColorIndex(row, col);
                      final isSolved = solvedIdx >= 0;
                      Color cellColor = Colors.transparent;
                      if (selected) {
                        cellColor =
                            const Color(0xFF64B5F6).withValues(alpha: 0.5);
                      }
                      if (isSolved) {
                        cellColor =
                            _solvedColors[solvedIdx % _solvedColors.length];
                      }

                      return Container(
                        width: cellSize,
                        height: cellSize,
                        decoration: BoxDecoration(
                          color: cellColor,
                          border: Border.all(
                              color: Colors.grey.shade700, width: 0.3),
                        ),
                        child: Center(
                          child: Text(
                            _grid[row][col],
                            style: GoogleFonts.iceland(
                              fontSize: cellSize * 0.55,
                              fontWeight: FontWeight.bold,
                              color: isSolved || selected
                                  ? Colors.white
                                  : const Color(0xFF64B5F6),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
          ),
        ),
      );
    });
  }
}