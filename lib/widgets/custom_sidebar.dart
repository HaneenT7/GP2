import 'package:flutter/material.dart';

class CustomSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const CustomSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Design constants taken from the reference (174 x 1024) nav
    const sidebarWidth = 174.0;
    const backgroundColor = Color(0xFFBFDFFF); // soft light blue similar to screenshot
    const sidebarRadius = Radius.circular(32); // rounded right corners

    const logoWidth = 173.0;
    const logoHeight = 172.0;
    const logoTopPadding = 12.0;
    const iconSize = 26.0;
    const navPadding = 10.0;
    const navMargin = 18.0;

    return Container(
      width: sidebarWidth,
      decoration: const BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.only(
          topRight: sidebarRadius,
          bottomRight: sidebarRadius,
        ),
      ),
      child: Column(
        children: [
          // WATAD Logo Section – 173×172
          Padding(
            padding: const EdgeInsets.only(
              top: logoTopPadding,
              left: 4,
              right: 4,
              bottom: 8,
            ),
            child: SizedBox(
              width: logoWidth,
              height: logoHeight,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Image.asset(
                  'assets/images/watad_logo.png',
                  errorBuilder: (context, error, stackTrace) {
                    return const Text(
                      'WATAD',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Navigation Items – single column of evenly spaced icons
          _buildNavItem(Icons.dashboard, 0, 'Dashboard', iconSize, navPadding, navMargin),
          _buildNavItem(Icons.checklist, 1, 'Revision Plan', iconSize, navPadding, navMargin),
          _buildSlantedNavItem(Icons.push_pin, 2, 'Snaps Board', iconSize, navPadding, navMargin),
          _buildNavItem(Icons.folder, 3, 'Course Folder', iconSize, navPadding, navMargin),
          _buildNavItem(Icons.psychology, 4, 'Brain Games', iconSize, navPadding, navMargin),
          _buildPenAndBookNavItem(5, 'Quiz', iconSize, navPadding, navMargin),

          const Spacer(),

          // Profile at bottom
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: _buildNavItem(Icons.person, 6, 'Profile', iconSize, navPadding, navMargin),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, String tooltip, double iconSize, double padding, double margin) {
    final isSelected = selectedIndex == index;
    
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 150),
      showDuration: const Duration(seconds: 2),
      preferBelow: false,
      child: GestureDetector(
        onTap: () => onItemSelected(index),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 14, horizontal: margin),
          padding: EdgeInsets.all(padding + 2),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF3EC4D9) // teal-ish selected block similar to screenshot
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildSlantedNavItem(IconData icon, int index, String tooltip, double iconSize, double padding, double margin) {
    final isSelected = selectedIndex == index;
    
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 150),
      showDuration: const Duration(seconds: 2),
      preferBelow: false,
      child: GestureDetector(
        onTap: () => onItemSelected(index),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 14, horizontal: margin),
          padding: EdgeInsets.all(padding + 2),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF3EC4D9)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Transform.rotate(
            angle: 0.9, // slight slant to mimic the reference
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPenAndBookNavItem(int index, String tooltip, double iconSize, double padding, double margin) {
    final isSelected = selectedIndex == index;
    final color = Colors.white;
    
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 150),
      showDuration: const Duration(seconds: 2),
      preferBelow: false,
      child: GestureDetector(
        onTap: () => onItemSelected(index),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 14, horizontal: margin),
          padding: EdgeInsets.all(padding + 2),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF3EC4D9)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox(
            width: iconSize,
            height: iconSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Book icon (background)
                Icon(
                  Icons.menu_book,
                  color: color,
                  size: iconSize * 0.83, // ~20/24 ratio
                ),
                // Pen icon (overlapping, top-right)
                Positioned(
                  right: -2,
                  top: -4,
                  child: Transform.rotate(
                    angle: -0.4,
                    child: Icon(
                      Icons.edit,
                      color: color,
                      size: iconSize * 0.58, // ~14/24 ratio
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
}