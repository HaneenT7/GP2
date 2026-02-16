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
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive sizing based on screen width
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    
    // Sidebar width: Mobile (60px), Tablet (70px), Desktop (80px)
    final sidebarWidth = isMobile ? 60.0 : (isTablet ? 70.0 : 80.0);
    
    // Logo size scales with sidebar width
    final logoSize = sidebarWidth;
    final logoBorderRadius = sidebarWidth * 0.25;
    
    // Icon sizes scale proportionally
    final iconSize = isMobile ? 20.0 : (isTablet ? 22.0 : 24.0);
    final navPadding = isMobile ? 8.0 : (isTablet ? 10.0 : 12.0);
    final navMargin = isMobile ? 12.0 : (isTablet ? 14.0 : 16.0);
    final verticalPadding = isMobile ? 16.0 : (isTablet ? 18.0 : 20.0);
    final spacing = isMobile ? 16.0 : (isTablet ? 18.0 : 20.0);
    
    return Container(
      width: sidebarWidth,
      decoration: const BoxDecoration(
        color: Color(0xFF6A4E88), // Same muted purple as Snaps Board header
      ),
      child: Column(
        children: [
          // WATAD Logo Section
          Container(
            padding: EdgeInsets.symmetric(vertical: verticalPadding),
            child: Column(
              children: [
                // WATAD Logo Image
                Container(
                  width: logoSize,
                  height: logoSize,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(logoBorderRadius),
                    child: Image.asset(
                      'assets/images/watad_logo.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to icon if image not found
                        return Container(
                          width: logoSize,
                          height: logoSize,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6A4E88).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(logoBorderRadius),
                          ),
                          child: Icon(
                            Icons.water_drop_outlined,
                            color: Colors.white,
                            size: logoSize * 0.5,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: spacing),

          // Navigation Items
          _buildNavItem(Icons.dashboard, 0, 'Dashboard', iconSize, navPadding, navMargin),
          _buildNavItem(Icons.checklist, 1, 'Revision Plan', iconSize, navPadding, navMargin),
          _buildSlantedNavItem(Icons.push_pin, 2, 'Snaps Board', iconSize, navPadding, navMargin),
          _buildNavItem(Icons.folder, 3, 'Course Folder', iconSize, navPadding, navMargin),
          _buildNavItem(Icons.psychology, 4, 'Brain Games', iconSize, navPadding, navMargin),
          _buildPenAndBookNavItem(5, 'Quiz', iconSize, navPadding, navMargin),

          const Spacer(),

          // Profile at bottom
          Padding(
            padding: EdgeInsets.only(bottom: verticalPadding),
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
      child: GestureDetector(
        onTap: () => onItemSelected(index),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: margin),
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFF3399FF).withOpacity(0.3) // Light blue when selected (matches header)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(padding),
            border: isSelected 
                ? Border.all(color: const Color(0xFF3399FF), width: 1)
                : null,
          ),
          child: Icon(
            icon,
            color: isSelected ? const Color(0xFF3399FF) : Colors.white70,
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
      child: GestureDetector(
        onTap: () => onItemSelected(index),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: margin),
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFF3399FF).withOpacity(0.3) // Light blue when selected (matches header)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(padding),
            border: isSelected 
                ? Border.all(color: const Color(0xFF3399FF), width: 1)
                : null,
          ),
          child: Transform.rotate(
            angle: 0.9, // Rotate about 17 degrees clockwise to match the photo
            child: Icon(
              icon,
              color: isSelected ? const Color(0xFF3399FF) : Colors.white70,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPenAndBookNavItem(int index, String tooltip, double iconSize, double padding, double margin) {
    final isSelected = selectedIndex == index;
    final color = isSelected ? const Color(0xFF3399FF) : Colors.white70;
    
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => onItemSelected(index),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: margin),
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: isSelected 
                ? const Color(0xFF3399FF).withOpacity(0.3) // Light blue when selected (matches header)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(padding),
            border: isSelected 
                ? Border.all(color: const Color(0xFF3399FF), width: 1)
                : null,
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