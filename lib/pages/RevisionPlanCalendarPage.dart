import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class RevisionPlanCalendarPage extends StatefulWidget {
  final String planId;

  const RevisionPlanCalendarPage({
    required this.planId,
    super.key,
  });

  @override
  State<RevisionPlanCalendarPage> createState() => _RevisionPlanCalendarPageState();
}

class _RevisionPlanCalendarPageState extends State<RevisionPlanCalendarPage> {
  String _viewMode = 'day'; // 'day' or 'week'
  DateTime _selectedDate = DateTime.now();
  List<DateTime> _getWeekDays() {
  final start = _getWeekStart(_selectedDate);
  return List.generate(7, (i) => start.add(Duration(days: i)));
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Revision Plan'),
        backgroundColor: const Color(0xFF4B3D8E),
        foregroundColor: Colors.white,
        actions: [
          // View mode toggle
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'day',
                label: Text('Day'),
                icon: Icon(Icons.today, size: 16),
              ),
              ButtonSegment(
                value: 'week',
                label: Text('Week'),
                icon: Icon(Icons.view_week, size: 16),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _viewMode = newSelection.first;
              });
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.transparent;
                },
              ),
              foregroundColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF4B3D8E);
                  }
                  return Colors.white;
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('revisionPlans')
            .doc(widget.planId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Plan not found'));
          }

          final planData = snapshot.data!.data() as Map<String, dynamic>;
final rawTasks = planData['dailyTasks'];
List<dynamic> dailyTasks = [];
if (rawTasks is String) {
  try {
    dailyTasks = jsonDecode(rawTasks) as List<dynamic>;
  } catch (e) {
    dailyTasks = [];
  }
} else if (rawTasks is List) {
  dailyTasks = rawTasks;
}
          return Column(
            children: [
                _buildWeekNavigation(),
                
              // Date navigation
              _buildDaysBar(dailyTasks),
              
              const Divider(height: 1),
              
              // Calendar view
              Expanded(
                child: _viewMode == 'day'
                    ? _buildDayView(dailyTasks)
                    : _buildWeekView(dailyTasks),
              ),
            ],
          );
        },
      ),
    );
  }
  Widget _buildWeekNavigation() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [

        /// Left arrow
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              _selectedDate = _selectedDate.subtract(
                const Duration(days: 7),
              );
            });
          },
        ),

        /// Week label
        Text(
          'Week of ${DateFormat('MMM d').format(_getWeekStart(_selectedDate))}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        /// Right arrow
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() {
              _selectedDate = _selectedDate.add(
                const Duration(days: 7),
              );
            });
          },
        ),
      ],
    ),
  );
}
/////////////////////////////////////////////////////////////////////////////////
Widget _buildDaysBar(List<dynamic> dailyTasks) {
  final weekDays = _getWeekDays();

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: List.generate(weekDays.length, (index) {
        final day = weekDays[index];
        final isSelected = _isSameDay(day, _selectedDate);
        final dayData = _findDayData(dailyTasks, day);
        final tasks = dayData?['tasks'] as List<dynamic>? ?? [];

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < 6 ? 10 : 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  _selectedDate = day;
                  _viewMode = 'day';
                });
              },
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.grey[300] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(color: Colors.black87, width: 1.5)
                      : Border.all(color: Colors.grey[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEE').format(day),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMM d').format(day),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),

                    // task indicator
                    if (tasks.isNotEmpty)
                      Positioned(
                        top: 4,
                        right: 4,
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
              ),
            ),
          ),
        );
      }),
    ),
  );
}
  Widget _buildDayView(List<dynamic> dailyTasks) {
    final dayData = _findDayData(dailyTasks, _selectedDate);

    if (dayData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No tasks scheduled for this day',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final tasks = dayData['tasks'] as List<dynamic>? ?? [];
    final availableMinutes = dayData['availableMinutes'] ?? 0;

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.free_breakfast, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No study time available',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Rest day',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Day summary
        Card(
          color: const Color(0xFF4B3D8E).withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Study Time',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '${availableMinutes} minutes',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4B3D8E),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Tasks',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      '${tasks.where((t) => t['completed'] == true).length}/${tasks.length}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4B3D8E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Tasks list
        ...tasks.asMap().entries.map((entry) {
          final index = entry.key;
          final task = entry.value;
          return _buildTaskCard(task, index);
        }).toList(),
      ],
    );
  }

  Widget _buildWeekView(List<dynamic> dailyTasks) {
    final weekStart = _getWeekStart(_selectedDate);
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = weekDays[index];
        final dayData = _findDayData(dailyTasks, day);
        final tasks = dayData?['tasks'] as List<dynamic>? ?? [];
        final isToday = _isSameDay(day, DateTime.now());

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isToday ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isToday
                ? const BorderSide(color: Color(0xFF4B3D8E), width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _selectedDate = day;
                _viewMode = 'day';
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4B3D8E),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'TODAY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (isToday) const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DateFormat('EEEE, MMM d').format(day),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (tasks.isNotEmpty)
                        Text(
                          '${tasks.where((t) => t['completed'] == true).length}/${tasks.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                  
                  if (tasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'No tasks',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    )
                  else
                    ...tasks.take(3).map((task) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            task['completed'] == true
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: task['completed'] == true
                                ? Colors.green
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              task['title'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                decoration: task['completed'] == true
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: task['completed'] == true
                                    ? Colors.grey
                                    : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  
                  if (tasks.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${tasks.length - 3} more',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
Widget _buildTaskCard(Map<dynamic, dynamic> task, int index) {
  final isCompleted = task['completed'] == true;
  final title = task['title'] ?? '';
  final course = task['course'] ?? 'Study Task';
  final type = task['type'] ?? 'study';

  const greenCheck = Color(0xFF52C41A);
  const greenBg = Color(0xFFE6F7E9);
  const greyButtonBg = Color(0xFFF5F5F5);

  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: isCompleted ? greenBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.transparent : const Color(0xFFE8E8E8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          /// Checkbox
          GestureDetector(
            onTap: () async {
              await _toggleTaskCompletion(index, !isCompleted);
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isCompleted ? greenCheck : Colors.black87,
                  width: isCompleted ? 2 : 1,
                ),
              ),
              child: isCompleted
                  ? const Center(
                      child: Icon(Icons.check, size: 16, color: greenCheck),
                    )
                  : null,
            ),
          ),

          const SizedBox(width: 14),

          /// Task title + course
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.grey : Colors.black87,
                    decoration:
                        isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  course,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          /// Take Quiz button
          Material(
            color: isCompleted ? greenCheck : greyButtonBg,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () {
                // TODO connect quiz page later
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(
                  'Take Quiz',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
Future<void> _toggleTaskCompletion(int taskIndex, bool completed) async {
  final planDoc = await FirebaseFirestore.instance
      .collection('revisionPlans')
      .doc(widget.planId)
      .get();

  if (!planDoc.exists) return;

  final planData = planDoc.data()!;
  
  // Safe decoding
  final rawTasks = planData['dailyTasks'];
  List<dynamic> dailyTasks = [];
  bool wasString = rawTasks is String;

  if (wasString) {
    dailyTasks = jsonDecode(rawTasks) as List<dynamic>;
  } else {
    dailyTasks = List<dynamic>.from(rawTasks ?? []);
  }

  // Find the day and update the task
  for (var i = 0; i < dailyTasks.length; i++) {
    final day = dailyTasks[i];
    final dayDate = DateTime.parse(day['date']);
    
    if (_isSameDay(dayDate, _selectedDate)) {
      final tasks = List<dynamic>.from(day['tasks']);
      if (taskIndex < tasks.length) {
        tasks[taskIndex]['completed'] = completed;
        dailyTasks[i]['tasks'] = tasks;
        break;
      }
    }
  }

  // Save back in the same format it was found (String or List)
  dynamic dataToSave = wasString ? jsonEncode(dailyTasks) : dailyTasks;

  await FirebaseFirestore.instance
      .collection('revisionPlans')
      .doc(widget.planId)
      .update({'dailyTasks': dataToSave});

 // ── NEW: check if entire plan is complete for dashboard──────────────────────────────
  final allTasks = dailyTasks
      .expand((day) => (day['tasks'] as List<dynamic>? ?? []))
      .toList();

  final allDone = allTasks.isNotEmpty &&
      allTasks.every((t) => t['completed'] == true);

  if (allDone) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .update({'completedPlans': FieldValue.increment(1)});
    }
  }
  // ───────────────────────────────────────────────────────────────────────

}

  Map<dynamic, dynamic>? _findDayData(List<dynamic> dailyTasks, DateTime date) {
    for (var day in dailyTasks) {
      final dayDate = DateTime.parse(day['date']);
      if (_isSameDay(dayDate, date)) {
        return day;
      }
    }
    return null;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }
}