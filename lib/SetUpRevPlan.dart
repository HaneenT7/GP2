import 'package:flutter/material.dart';

class SetUpRevPlan extends StatefulWidget {
  final VoidCallback onClose;
  const SetUpRevPlan({super.key, required this.onClose});

  @override
  State<StatefulWidget> createState() => _SetUpRevPlanState();
}

class _SetUpRevPlanState extends State<SetUpRevPlan> {
  int _selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- 1st section --
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Create new Revision Plan',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(80.0),
                children: [
                  //  Select course folder
                  const Text(
                    'Select course folder',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  //  Select exam materials
                  const Text(
                    'Select exam materials',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Select exam date
                  const Text(
                    'Select exam date',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 650,
                      height: 350,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color.fromARGB(255, 160, 135, 180),
                            onPrimary: Color.fromARGB(255, 36, 27, 39),  
                            onSurface: Colors.black,  
                          ),
                        ),
                      child: CalendarDatePicker(
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        onDateChanged: (DateTime date) {
                          print("Selected date: $date");
                        },
                      ),
                    ),
                  ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          right: 32,
          bottom: 32,
          child: ElevatedButton.icon(
            onPressed: widget.onClose,
            icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 23),
            label: const Text(
              'Generate Revision Plan',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF423066),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}