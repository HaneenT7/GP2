import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BrainGamesPage extends StatelessWidget {
  const BrainGamesPage({super.key});

  static const _navBarHeight = 56.0;
  static const _mutedIconColor = Color(0xFF8B9AAB);

  static const TextStyle _titleStyle = TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1C1C1E),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildTopBar(),
          Divider(height: 1, color: Colors.grey.shade300),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Brain Games', style: _titleStyle),
                      const SizedBox(height: 24),
                      _buildGameCards(context),
                      const SizedBox(height: 200),
                    ],
                  ),
                ),
                Positioned(
                  right: 24,
                  bottom: 24,
                  child: _buildBrainIllustration(context),
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
            Text(
              '318941',
              style: TextStyle(
                fontSize: 16,
                color: _mutedIconColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.code, size: 24, color: _mutedIconColor),
                const SizedBox(width: 20),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
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
      ),
      _GameCardData(
        title: 'Sudoku',
        backgroundImage: 'assets/images/bg_sudoku.png',
        cardColor: const Color(0xFFE8F5E9),
        borderColor: const Color(0xFFA5D6A7),
        child: _buildPreviewImage('assets/images/sudoku_preview.png'),
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
      ),
      _GameCardData(
        title: 'Anagrams',
        backgroundImage: 'assets/images/bg_anagrams.png',
        cardColor: const Color(0xFFF3E5F5),
        borderColor: const Color(0xFFCE93D8),
        child: _buildPreviewImageOrWidget(
          'assets/images/anagrams_preview.png',
          _buildAnagramsPreview(),
        ),
      ),
    ];

    // Fixed card size for each game background
    const cardWidth = 258.0;
    const cardHeight = 362.0;
    const cardSpacing = 16.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cards
            .map(
              (d) => Padding(
                padding: const EdgeInsets.only(right: cardSpacing),
                child: _GameCard(
                  data: d,
                  width: cardWidth,
                  height: cardHeight,
                ),
              ),
            )
            .toList(),
      ),
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

  static const double _previewFontSize = 32;

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
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${p.$1} __',
                        style: GoogleFonts.iceland(
                          fontSize: _previewFontSize,
                          fontWeight: FontWeight.w600,
                          color: p.$2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildAnagramsPreview() {
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
          children: [
            Text(
              'Possibility',
              style: GoogleFonts.iceland(
                fontSize: _previewFontSize,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64B5F6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              height: 1,
              width: 120,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              'bit bolt boy lip list loss oil\npilot plot toy pot slip soil\nsoy spot spy stop tip top',
              style: GoogleFonts.iceland(
                fontSize: _previewFontSize,
                height: 1.2,
                color: const Color(0xFFFFB74D),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrainIllustration(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: SizedBox(
        width: 220,
        height: 220,
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
                size: 120,
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

  const _GameCardData({
    required this.title,
    this.backgroundImage,
    required this.cardColor,
    required this.borderColor,
    required this.child,
  });
}

class _GameCard extends StatelessWidget {
  final _GameCardData data;
  final double width;
  final double height;

  const _GameCard({
    required this.data,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: width,
          height: height,
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
            mainAxisSize: MainAxisSize.max,
            children: [
              Center(
                child: Text(
                  data.title,
                  style: GoogleFonts.iceland(
                    fontSize: 32,
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
              const SizedBox(height: 16),
              _StartButton(onPressed: () {}),
            ],
          ),
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
          height: 44,
          child: Center(
            child: Image.asset(
              _startButtonAsset,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF64B5F6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Text(
                    'START',
                    style: TextStyle(
                      fontSize: 14,
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
