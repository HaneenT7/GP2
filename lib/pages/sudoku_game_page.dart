import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class SudokuGamePage extends StatefulWidget {
  const SudokuGamePage({super.key});
  @override
  State<SudokuGamePage> createState() => _SudokuGamePageState();
}

class _SudokuGamePageState extends State<SudokuGamePage> {
  List<List<int>> _puzzle = [];
  List<List<int>> _solution = [];
  List<List<int>> _userInput = [];
  List<List<bool>> _isOriginal = [];
  bool _isLoading = true;
  bool _hasError = false;
  int? _selectedRow;
  int? _selectedCol;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _fetchSudoku();
  }

  Future<void> _fetchSudoku() async {
    setState(() { _isLoading = true; _hasError = false; _isComplete = false; });
    try {
      final response = await http.get(
        Uri.parse('https://shadify.yurace.pro/api/sudoku/generator?fill=30'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // API returns: "grid" = solution, "task" = puzzle with zeros
        final taskRaw = data['task'] as List;
        final gridRaw = data['grid'] as List;

        final puzzle = taskRaw.map<List<int>>((row) =>
          (row as List).map<int>((e) => e as int).toList()).toList();
        final solution = gridRaw.map<List<int>>((row) =>
          (row as List).map<int>((e) => e as int).toList()).toList();

        setState(() {
          _puzzle = puzzle;
          _solution = solution;
          _userInput = puzzle.map((row) => List<int>.from(row)).toList();
          _isOriginal = puzzle.map((row) => row.map((e) => e != 0).toList()).toList();
          _isLoading = false;
        });
      } else {
        setState(() { _hasError = true; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _hasError = true; _isLoading = false; });
    }
  }

  void _onCellTap(int row, int col) {
    if (_isOriginal[row][col]) return;
    setState(() { _selectedRow = row; _selectedCol = col; });
  }

  void _onNumberPress(int number) {
    if (_selectedRow == null || _selectedCol == null) return;
    if (_isOriginal[_selectedRow!][_selectedCol!]) return;
    setState(() { _userInput[_selectedRow!][_selectedCol!] = number; });
    _checkComplete();
  }

  void _checkComplete() {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_userInput[r][c] != _solution[r][c]) return;
      }
    }
    setState(() { _isComplete = true; });
  }

  Color _cellColor(int row, int col) {
    if (_selectedRow == row && _selectedCol == col) return const Color(0xFF64B5F6);
    if (_selectedRow != null && _selectedCol != null) {
      if (_selectedRow == row || _selectedCol == col) return const Color(0xFFBBDEFB);
      final boxRow = (_selectedRow! ~/ 3) * 3;
      final boxCol = (_selectedCol! ~/ 3) * 3;
      if (row >= boxRow && row < boxRow + 3 && col >= boxCol && col < boxCol + 3) {
        return const Color(0xFFBBDEFB);
      }
    }
    return (row ~/ 3 + col ~/ 3) % 2 == 0 ? const Color(0xFF1C1C1E) : const Color(0xFF2C2C2E);
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
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Text('Sudoku', style: GoogleFonts.iceland(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C1E))),
            const Spacer(),
            IconButton(icon: const Icon(Icons.refresh_rounded, size: 24), onPressed: _fetchSudoku),
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
        ElevatedButton(onPressed: _fetchSudoku, child: const Text('Retry')),
      ]),
    );
  }

  Widget _buildGame() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (_isComplete) _buildWinBanner(),
          _buildGrid(),
          const SizedBox(height: 24),
          _buildNumberPad(),
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
        Text('Puzzle Complete! 🎉', style: GoogleFonts.iceland(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildGrid() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF64B5F6), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            children: List.generate(9, (row) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(9, (col) {
                  final value = _userInput[row][col];
                  final isWrong = value != 0 && !_isOriginal[row][col] && value != _solution[row][col];
                  return GestureDetector(
                    onTap: () => _onCellTap(row, col),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _cellColor(row, col),
                        border: Border(
                          right: col == 2 || col == 5
                              ? const BorderSide(color: Color(0xFF64B5F6), width: 2)
                              : BorderSide(color: Colors.grey.shade700, width: 0.5),
                          bottom: row == 2 || row == 5
                              ? const BorderSide(color: Color(0xFF64B5F6), width: 2)
                              : BorderSide(color: Colors.grey.shade700, width: 0.5),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          value == 0 ? '' : value.toString(),
                          style: GoogleFonts.iceland(
                            fontSize: 22, fontWeight: FontWeight.bold,
                            color: isWrong ? Colors.red : _isOriginal[row][col] ? const Color(0xFFFF9800) : const Color(0xFF64B5F6),
                          ),
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
    );
  }

  Widget _buildNumberPad() {
    return Wrap(
      spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
      children: [...List.generate(9, (i) => _numButton(i + 1)), _numButton(0, label: '✕')],
    );
  }

  Widget _numButton(int number, {String? label}) {
    return GestureDetector(
      onTap: () => _onNumberPress(number),
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF64B5F6), width: 1.5),
        ),
        child: Center(
          child: Text(
            label ?? number.toString(),
            style: GoogleFonts.iceland(fontSize: 26, fontWeight: FontWeight.bold, color: number == 0 ? Colors.red : Colors.white),
          ),
        ),
      ),
    );
  }
}