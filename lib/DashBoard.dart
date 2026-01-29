import 'package:flutter/material.dart';
import 'widgets/custom_sidebar.dart';

class DashBoard extends StatefulWidget {
  const DashBoard({super.key});

  @override
  State<StatefulWidget> createState() => _DashBoardState();
}

class _DashBoardState extends State<DashBoard> {
  int _selectedIndex = 0;

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
              child: const Center(
                child: Text("Dashboard Content"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
