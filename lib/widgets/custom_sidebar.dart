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
    const sidebarWidth = 174.0;
    const backgroundColor = Color(0xFFBFDFFF);
    const sidebarRadius = Radius.circular(32);

    // RepaintBoundary isolates the sidebar from the rest of the dashboard
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
            const SidebarLogo(), // Extracted to prevent image reload jank

            const SizedBox(height: 4),

            _buildNavItem(Icons.dashboard, 0, 'Dashboard'),
            _buildNavItem(Icons.checklist, 1, 'Revision Plan'),
            _buildSlantedNavItem(Icons.push_pin, 2, 'Snaps Board'),
            _buildNavItem(Icons.folder, 3, 'Course Folder'),
            _buildNavItem(Icons.psychology, 4, 'Brain Games'),
            _buildPenAndBookNavItem(5, 'Quiz'),

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
      waitDuration: const Duration(milliseconds: 50), // Shorter duration avoids blocking tap logic
      child: GestureDetector(
        onTap: () => onItemSelected(index),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3EC4D9) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 26,
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
          margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3EC4D9) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Transform.rotate(
            angle: 0.9,
            child: Icon(icon, color: Colors.white, size: 26),
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
        margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3EC4D9) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        // REMOVED 'const' from here because Transform.rotate is dynamic
        child: SizedBox(
          width: 26,
          height: 26,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.menu_book, color: Colors.white, size: 22),
              Positioned(
                right: -2,
                top: -4,
                child: Transform.rotate(
                  angle: -0.4,
                  child: const Icon(Icons.edit, color: Colors.white, size: 15),
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
      padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: SizedBox(
        width: 173,
        height: 148,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Image(
            image: AssetImage('assets/images/watad_logo.png'),
            filterQuality: FilterQuality.low, // Optimization for UI assets
          ),
        ),
      ),
    );
  }
}