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
    const sidebarWidth = 88.0; // Smaller than before (was 174)
    const backgroundColor = Color(0xFF2D1B69); // Deep purple
    const sidebarRadius = Radius.circular(0);

    return RepaintBoundary(
      child: Container(
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
            const SidebarLogo(),

            const SizedBox(height: 4),

            _buildNavItem(Icons.dashboard, 0, 'Dashboard'),
            _buildNavItem(Icons.folder, 1, 'Course Folder'),
            _buildNavItem(Icons.checklist, 2, 'Revision Plan'),
            _buildPenAndBookNavItem(3, 'Quiz'),
            _buildSlantedNavItem(Icons.push_pin, 4, 'Snaps Board'),
            _buildNavItem(Icons.psychology, 5, 'Brain Games'),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: _buildNavItem(Icons.person, 6, 'Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index, String tooltip) {
    final isSelected = selectedIndex == index;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 50),
      child: GestureDetector(
        onTap: () => onItemSelected(index),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.2) // Soft white highlight
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildSlantedNavItem(IconData icon, int index, String tooltip) {
    final isSelected = selectedIndex == index;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 50),
      child: GestureDetector(
        onTap: () => onItemSelected(index),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Transform.rotate(
            angle: 0.9,
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPenAndBookNavItem(int index, String tooltip) {
    final isSelected = selectedIndex == index;

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 50),
      child: GestureDetector(
        onTap: () => onItemSelected(index),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            width: 24,
            height: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.menu_book,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.6),
                    size: 20),
                Positioned(
                  right: -2,
                  top: -4,
                  child: Transform.rotate(
                    angle: -0.4,
                    child: Icon(Icons.edit,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.6),
                        size: 13),
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

class SidebarLogo extends StatelessWidget {
  const SidebarLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: SizedBox(
        width: 64,  // Tighter logo for narrow sidebar
        height: 64,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Image(
            image: AssetImage('assets/images/watad_logo.png'),
            filterQuality: FilterQuality.low,
          ),
        ),
      ),
    );
  }
}