import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:intl/intl.dart'; 
import 'widgets/custom_sidebar.dart';
import 'pages/course_folders_page.dart';
import 'RevPlanPage.dart';
import 'pages/snaps_board_page.dart';
import 'pages/brain_games_page.dart';
import 'pages/profile_page.dart';
import 'pages/quiz_landing_page.dart'; // Import the extracted page
import 'package:gp2_watad/widgets/app_header.dart';

class DashBoard extends StatefulWidget {
  const DashBoard({super.key});
  

  @override
  State<StatefulWidget> createState() => _DashBoardState();
}

class _DashBoardState extends State<DashBoard> {
  int _selectedIndex = 0;
  
  @override
    void initState() {
      super.initState();
    }


@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          CustomSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
          Expanded(
            child: RepaintBoundary( // <--- Add this wrapper
            child: Container(
              color: Colors.white,
              // IndexedStack is great here because it keeps the 
              // state of each page alive in the background.
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  // 2. FIXED: We use the Class name instead of the old method call
                  DashboardHomeContent(), // Index 0
                  RevPlanPage(),                // Index 1
                  SnapsBoardPage(),             // Index 2
                  CourseFoldersPage(),          // Index 3
                  BrainGamesPage(),             // Index 4
                  QuizLandingPage(),      // Index 5
                  ProfilePage(),                // Index 6
                ],
              ),
            ),
          ),),
        ],
      ),
    );
  }
}

class DashboardHomeContent extends StatelessWidget {
  const DashboardHomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    // This looks like your old _buildDashboardContent but as a class
    // This "seals" the build context so it doesn't rebuild 
    // just because the Sidebar's index changed.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppHeader(title: 'Dashboard'),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 12, 32, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    const GreetingWidget(), // Extracted greeting
                    const SizedBox(height: 28),
                    const UpcomingExamsSection(), // Extracted exams
                    const SizedBox(height: 28),
                    const DailyTasksSection(), // Extracted tasks
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
class GreetingWidget extends StatefulWidget {
  const GreetingWidget({super.key});

  @override
  State<GreetingWidget> createState() => _GreetingWidgetState();
}

class _GreetingWidgetState extends State<GreetingWidget> {
  String _firstName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('students').doc(user.uid).get();
    if (mounted && doc.exists) {
      setState(() => _firstName = doc.data()?['firstName'] ?? 'Guest');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Hello, ${_firstName.isEmpty ? "Guest" : _firstName}',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class UpcomingExamsSection extends StatelessWidget {
  const UpcomingExamsSection({super.key});

  // Helper methods moved inside the class so it's self-contained
  DateTime? _examDateFromPlan(Map<String, dynamic> plan) {
    final raw = plan['examDate'] ?? plan['exam_date'] ?? plan['examDateIso'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _folderNameFromPlan(Map<String, dynamic> plan) {
    return plan['folderName'] as String? ?? plan['folder_name'] as String? ?? 'Course';
  }

  Stream<List<Map<String, dynamic>>> _revisionPlansStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);
    return FirebaseFirestore.instance
        .collection('revisionPlans')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
              .toList(),
        );
  }
@override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.school_outlined, size: 22, color: Colors.purple.shade300),
                  const SizedBox(width: 8),
                  const Text('Upcoming Exams', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black)),
                  const Text(' *', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.red)),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _revisionPlansStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final today = DateTime.now();
                  final startToday = DateTime(today.year, today.month, today.day);
                  final plans = (snapshot.data ?? [])
                      .where((p) => _examDateFromPlan(p) != null)
                      .toList()
                    ..sort((a, b) => _examDateFromPlan(a)!.compareTo(_examDateFromPlan(b)!));

                  final upcoming = plans.where((p) => !_examDateFromPlan(p)!.isBefore(startToday)).take(2).toList();

                  if (upcoming.isEmpty) {
                    return Container(
                      width: double.infinity, padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
                      child: const Text('No upcoming exams yet.', style: TextStyle(fontSize: 14, color: Colors.black54)),
                    );
                  }

                  return Column(
                    children: List.generate(upcoming.length, (index) {
                      final plan = upcoming[index];
                      final examDate = _examDateFromPlan(plan)!;
                      return Padding(
                        padding: EdgeInsets.only(bottom: index == upcoming.length - 1 ? 0 : 12),
                        child: _ExamCardWidget( // Use a small helper widget below
                          title: '${_folderNameFromPlan(plan).toUpperCase()} EXAM',
                          date: '${examDate.day.toString().padLeft(2, '0')}/${examDate.month.toString().padLeft(2, '0')}/${examDate.year}',
                          color: index.isEven ? const Color(0xFFFFF3CD) : const Color(0xFFFFE4CC),
                        ),
                      );
                    }),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        const Expanded(flex: 1, child: QuoteCardWidget()), // Extracted this too for speed
      ],
    );
  }
}

class _ExamCardWidget extends StatelessWidget {
  final String title;
  final String date;
  final Color color;
  const _ExamCardWidget({required this.title, required this.date, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
          Text(date, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
class QuoteCardWidget extends StatelessWidget {
  const QuoteCardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE9D5FF), Color(0xFFDDD6FE)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('"', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, height: 1)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, left: 8),
                  child: Text('Follow your plan, not your mood', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.deepPurple.shade800)),
                ),
              ),
            ],
          ),
          Positioned(right: 0, bottom: -8, child: Icon(Icons.psychology, size: 56, color: const Color(0xFF7C3AED).withOpacity(0.5))),
        ],
      ),
    );
  }
}

class DailyTasksSection extends StatefulWidget {
  const DailyTasksSection({super.key});

  @override
  State<DailyTasksSection> createState() => _DailyTasksSectionState();
}

class _DailyTasksSectionState extends State<DailyTasksSection> {
  DateTime _currentWeekMonday = DateTime.now();
  List<DateTime> _weekDates = [];
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeCalendar();
  }

  void _initializeCalendar() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int daysSinceSunday = now.weekday % 7;
    _currentWeekMonday = today.subtract(Duration(days: daysSinceSunday));
    _generateWeekDates();
    _selectedDayIndex = now.weekday % 7;
  }

  void _generateWeekDates() {
    _weekDates = List.generate(7, (index) => _currentWeekMonday.add(Duration(days: index)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = _weekDates[_selectedDayIndex];
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('EEEE, MMMM d').format(selectedDate),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            _buildCalendarNavButtons(),
          ],
        ),
        const SizedBox(height: 20),
        _buildDaysBar(),
        const SizedBox(height: 12),
        _buildOverdueInfoBar(dateKey),
        const SizedBox(height: 24),
        _buildFirestoreTasksList(dateKey),
      ],
    );
  }

  bool _isDateBeforeToday(String dateKey) {
    final d = DateTime.tryParse(dateKey);
    if (d == null) return false;
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(d.year, d.month, d.day);
    return day.isBefore(today);
  }

  Widget _buildOverdueInfoBar(String dateKey) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('revisionPlans')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        int overdueOnSelectedDay = 0;
        int totalOverdue = 0;

        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final rawDailyTasks = data['dailyTasks'];
          List<dynamic> daysList = [];

          if (rawDailyTasks is String) {
            try {
              daysList = jsonDecode(rawDailyTasks) as List<dynamic>;
            } catch (_) {
              daysList = [];
            }
          } else if (rawDailyTasks is List) {
            daysList = rawDailyTasks;
          }

          for (final day in daysList) {
            if (day is! Map) continue;
            final dayDateKey = day['date']?.toString();
            if (dayDateKey == null || !_isDateBeforeToday(dayDateKey)) continue;
            final tasks = day['tasks'] as List<dynamic>? ?? [];
            for (final task in tasks) {
              if (task is! Map) continue;
              if (task['completed'] == true) continue;
              totalOverdue++;
              if (dayDateKey == dateKey) {
                overdueOnSelectedDay++;
              }
            }
          }
        }

        if (totalOverdue == 0) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.deepOrange.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.deepOrange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.deepOrange.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  overdueOnSelectedDay > 0
                      ? 'Overdue on selected day: $overdueOnSelectedDay  •  Total overdue: $totalOverdue'
                      : 'Total overdue tasks: $totalOverdue',
                  style: TextStyle(
                    color: Colors.deepOrange.shade900,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFirestoreTasksList(String dateKey) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text("Please sign in."));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('revisionPlans')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildNoTasksPlaceholder("No revision plans found.");
        
        List<Widget> dailyTaskWidgets = [];
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final folderName = data['folderName'] ?? 'Unknown Course';
          final rawDailyTasks = data['dailyTasks'];
          List<dynamic> daysList = [];
          
          try {
            if (rawDailyTasks is String) {
              daysList = jsonDecode(rawDailyTasks) as List<dynamic>;
            } else if (rawDailyTasks is List) {
              daysList = rawDailyTasks;
            }
            
            // Find the day matching our selected date
            final dayData = daysList.firstWhere(
              (day) => day['date'] == dateKey,
              orElse: () => null,
            );

            if (dayData != null && dayData['tasks'] != null) {
              final tasks = dayData['tasks'] as List<dynamic>;
              for (var task in tasks) {
                dailyTaskWidgets.add(
                  _buildTaskCard(
                    title: task['title'] ?? 'Revision Task',
                    folder: folderName,
                    isCompleted: task['completed'] ?? false,
                    isOverdue: _isDateBeforeToday(dateKey) && (task['completed'] != true),
                    taskId: task['taskId'],
                    docId: doc.id,
                    fullDailyTasks: daysList,
                    dateKey: dateKey,
                  ),
                );
              }
            }
          } catch (_) {}
        }
        return dailyTaskWidgets.isEmpty 
            ? _buildNoTasksPlaceholder("Relax! No tasks for today.") 
            : Wrap(spacing: 16, runSpacing: 16, children: dailyTaskWidgets);
      },
    );
  }

  Widget _buildTaskCard({
    required String title,
    required String folder,
    required bool isCompleted,
    required bool isOverdue,
    required String taskId,
    required String docId,
    required List fullDailyTasks,
    required String dateKey,
  }) {
    return Container(
      width: (MediaQuery.of(context).size.width - 400) / 2,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFE6F7E9) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? Colors.transparent
              : isOverdue
                  ? Colors.deepOrange.shade300
                  : const Color(0xFFE8E8E8),
          width: isOverdue && !isCompleted ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () async {
              for (var day in fullDailyTasks) {
                if (day['date'] == dateKey) {
                  for (var t in day['tasks']) {
                    if (t['taskId'] == taskId) t['completed'] = !(t['completed'] ?? false);
                  }
                }
              }
              await FirebaseFirestore.instance.collection('revisionPlans').doc(docId).update({'dailyTasks': jsonEncode(fullDailyTasks)});
            },
            child: Icon(
              isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isCompleted ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, 
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isCompleted
                        ? Colors.black54
                        : isOverdue
                            ? Colors.deepOrange.shade900
                            : Colors.black87,
                  ),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text("$folder ",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                if (isOverdue && !isCompleted) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Overdue',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.deepOrange.shade800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTasksPlaceholder(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(child: Text(message, style: const TextStyle(color: Colors.grey))),
    );
  }

  Widget _buildCalendarNavButtons() {
    return Row(
      children: [
        IconButton(
          onPressed: () => setState(() {
            _weekDates = _weekDates
                .map((d) => d.subtract(const Duration(days: 7)))
                .toList();
          }),
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: () => setState(() {
            _weekDates =
                _weekDates.map((d) => d.add(const Duration(days: 7))).toList();
          }),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildDaysBar() {
    const double horizontalGap = 12.0;
    const double cardHeight = 80.0;

    return Row(
      children: List.generate(_weekDates.length, (index) {
        final date = _weekDates[index];
        final isSelected = index == _selectedDayIndex;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < 6 ? horizontalGap : 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedDayIndex = index),
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      height: cardHeight,
                      decoration: BoxDecoration(
                        color:
                            isSelected ? const Color(0xFFF3E8FF) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF9333EA)
                              : Colors.grey[300]!,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF9333EA)
                                      .withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('EEEE').format(date).substring(0, 3),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xFF7C3AED)
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('d').format(date),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF7C3AED)
                                  : Colors.grey[700],
                            ),
                          ),
                          Text(
                            DateFormat('MMM').format(date),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF9333EA).withOpacity(0.7)
                                  : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}