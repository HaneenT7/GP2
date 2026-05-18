import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sudoku_game_page.dart';
import 'word_search_game_page.dart';
import 'math_lab_game_page.dart';
import 'memory_game_page.dart';
import 'package:gp2_watad/widgets/app_header.dart';

class BrainGamesPage extends StatefulWidget {
  const BrainGamesPage({super.key});

  @override
  State<BrainGamesPage> createState() => _BrainGamesPageState();
}

class _BrainGamesPageState extends State<BrainGamesPage> {
  static const _navBarHeight = 56.0;
  static const _mutedIconColor = Color(0xFF8B9AAB);

  static const TextStyle _titleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Color(0xFF1C1C1E),
  );

  Widget? _selectedGameWidget;

  @override
  Widget build(BuildContext context) {
    if (_selectedGameWidget != null) {
      return _selectedGameWidget!;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // FIXED: Normal vertical scrolling view to view wrapped dynamic grid layouts cleanly
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGameCards(context),
                      const SizedBox(height: 140), // Slightly minimized vertical space padding safely
                    ],
                  ),
                ),
                Positioned(
                  right: 24,
                  bottom: 24,
                  child: IgnorePointer(child: _buildBrainIllustration(context)), // Added IgnorePointer to prevent background block interaction issues
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: _navBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'brain games',
              style: TextStyle(
                fontSize: 16,
                color: _mutedIconColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.code, size: 24, color: _mutedIconColor),
                const SizedBox(width: 20),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      size: 24,
                      color: _mutedIconColor,
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCards(BuildContext context) {
    final cards = [
      _GameCardData(
        title: 'Search words',
        backgroundImage: 'assets/images/bg_search_words.png',
        cardColor: const Color(0xFFFFF8E1),
        borderColor: const Color(0xFFE6D98A),
        child: _buildPreviewImage('assets/images/search_words_preview.png'),
        onPressed: () => setState(() {
          _selectedGameWidget = WordSearchGamePage(
            onExit: () => setState(() => _selectedGameWidget = null),
          );
        }),
      ),
      _GameCardData(
        title: 'Sudoku',
        backgroundImage: 'assets/images/bg_sudoku.png',
        cardColor: const Color(0xFFE8F5E9),
        borderColor: const Color(0xFFA5D6A7),
        child: _buildPreviewImage('assets/images/sudoku_preview.png'),
        onPressed: () => setState(() {
          _selectedGameWidget = SudokuGamePage(
            onExit: () => setState(() => _selectedGameWidget = null),
          );
        }),
      ),
      _GameCardData(
        title: 'Math lab',
        backgroundImage: 'assets/images/bg_math_lab.png',
        cardColor: const Color(0xFFFFF3E0),
        borderColor: const Color(0xFFFFCC80),
        child: _buildPreviewImageOrWidget(
          'assets/images/math_lab_preview.png',
          _buildMathLabPreview(),
        ),
        onPressed: () => setState(() {
          _selectedGameWidget = MathLabGamePage(
            onExit: () => setState(() => _selectedGameWidget = null),
          );
        }),
      ),
      _GameCardData(
        title: 'Memory',
        backgroundImage: 'assets/images/bg_anagrams.png',
        cardColor: const Color(0xFFF3E5F5),
        borderColor: const Color(0xFFCE93D8),
        child: _buildPreviewImageOrWidget(
          'assets/images/memory_preview.png',
          _buildMemoryPreview(),
        ),
        onPressed: () => setState(() {
          _selectedGameWidget = MemoryGamePage(
            onExit: () => setState(() => _selectedGameWidget = null),
          );
        }),
      ),
    ];

    // FIXED: Removed the Horizontal SingleChildScrollView Row architecture entirely. 
    // Replaced with a GridView setup that automatically shapes column amounts based on screen spaces safely.
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // Disables inner grid scrolling so it scrolls naturally with main view body
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260, // Maximum target width threshold for cards before fracturing rows
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.72, // Balanced vertical layout calculation width vs height proportion alignment
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        return _GameCard(data: cards[index]);
      },
    );
  }

  Widget _buildPreviewImage(String assetPath) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildPreviewImageOrWidget(String assetPath, Widget fallback) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }

  static const double _previewFontSize = 24; // Lowered slightly from 32 to handle squishing responsive behaviors beautifully

  Widget _buildMathLabPreview() {
    const problems = [
      ('26 + 95 =', Color(0xFFFF9800)),
      ('78 - 19 =', Color(0xFFE53935)),
      ('37 * 23 =', Color(0xFF1E88E5)),
      ('95 / 19 =', Colors.white),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: problems
              .map(
                (p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${p.$1} __',
                    style: GoogleFonts.iceland(
                      fontSize: _previewFontSize,
                      fontWeight: FontWeight.w600,
                      color: p.$2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildMemoryPreview() {
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: 8,
        itemBuilder: (context, i) {
          final isFlipped = i < 2;
          return Container(
            decoration: BoxDecoration(
              color: isFlipped ? colors[i % colors.length] : const Color(0xFF2C2C2E),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isFlipped ? colors[i % colors.length] : const Color(0xFF64B5F6),
                width: 1.2,
              ),
            ),
            child: Center(
              child: isFlipped
                  ? const Icon(Icons.star, color: Colors.white, size: 14)
                  : Text(
                      '?',
                      style: GoogleFonts.iceland(
                        fontSize: 14,
                        color: const Color(0xFF64B5F6),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBrainIllustration(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: SizedBox(
        width: 180, // Scaled down slightly to not choke visibility constraints on minor screens
        height: 180,
        child: Image.asset(
          'assets/images/brain_lift.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8BBD9).withOpacity(0.5),
                borderRadius: BorderRadius.circular(120),
              ),
              child: const Icon(
                Icons.psychology,
                size: 100,
                color: Color(0xFFE91E63),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GameCardData {
  final String title;
  final String? backgroundImage;
  final Color cardColor;
  final Color borderColor;
  final Widget child;
  final VoidCallback onPressed;

  const _GameCardData({
    required this.title,
    this.backgroundImage,
    required this.cardColor,
    required this.borderColor,
    required this.child,
    required this.onPressed,
  });
}

class _GameCard extends StatelessWidget {
  final _GameCardData data;

  // FIXED: Removed absolute properties width/height overrides to let GridView control bounds dynamically
  const _GameCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: data.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: data.borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          image: data.backgroundImage != null
              ? DecorationImage(
                  image: AssetImage(data.backgroundImage!),
                  fit: BoxFit.fill,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // FittedBox acts as an emergency stop protection against long card names splitting layouts
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                data.title,
                style: GoogleFonts.iceland(
                  fontSize: 28, // Balanced size target point
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(child: data.child),
            ),
            const SizedBox(height: 12),
            _StartButton(onPressed: data.onPressed),
          ],
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _StartButton({required this.onPressed});

  static const _startButtonAsset = 'assets/images/start_button.png';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Image.asset(
              _startButtonAsset,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64B5F6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Text(
                    'START',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}