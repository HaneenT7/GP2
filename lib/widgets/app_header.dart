import 'package:flutter/material.dart';
import 'package:gp2_watad/pages/DashBoard.dart';
// file no longer needed !
class AppHeader extends StatelessWidget {
  final String title;

  const AppHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: -0.3,
                ),
              ),
              IconButton(
                icon: Icon(Icons.notifications_outlined,
                    size: 26, color: Colors.grey[700]),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsPage()),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5, color: Color(0xFFE0E0E0)),
      ],
    );
  }
}