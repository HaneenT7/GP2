import 'package:flutter/material.dart';
import 'widgets/custom_sidebar.dart';
import 'pages/course_folders_page.dart';

class DashBoard extends StatefulWidget {
  const DashBoard({super.key});

  @override
  State<StatefulWidget> createState() => _DashBoardState();
}

class _DashBoardState extends State<DashBoard> {
  int _selectedIndex = 0;

  Widget _getPageForIndex(int index) {
    switch (index) {
      case 0:
        return const Center(child: Text("Dashboard Content"));
      case 1:
        return const Center(child: Text("Revision Plan Content"));
      case 2:
        return const Center(child: Text("Snaps Board Content"));
      case 3:
        return const CourseFoldersPage();
      case 4:
        return const Center(child: Text("Brain Games Content"));
      case 5:
        return const Center(child: Text("Quiz Content"));
      case 6:
        return const Center(child: Text("Profile Content"));
      default:
        return const Center(child: Text("Dashboard Content"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          CustomSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
          // Main content area
          Expanded(
            child: Container(
              color: Colors.white,
              child: _getPageForIndex(_selectedIndex),
            ),
          ),
        ],
      ),
    );
  }
}
