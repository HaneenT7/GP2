import 'package:flutter/material.dart';
import 'SetUpRevPlan.dart';

class RevPlanPage extends StatefulWidget {
  const RevPlanPage({super.key});
  @override
  State<StatefulWidget> createState() => _RevPlanPageState();
}

class _RevPlanPageState extends State<StatefulWidget> {
  int _selectedIndex = 1;
  bool _isSetupMode = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: _isSetupMode
          ? SetUpRevPlan(
              onClose: () {
                setState(() => _isSetupMode = false);
              },
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Revision plans',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_none_outlined),
                        onPressed: () {
                          //TODO: alarm feature
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Color.fromARGB(255, 33, 33, 33),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isSetupMode = true;
                        });
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Create new Plan',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4B3D8E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
