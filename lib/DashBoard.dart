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
    // This is the "Island" that keeps the state local
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
        const SizedBox(height: 24),
        _buildFirestoreTasksList(dateKey),
      ],
    );
  }

  Widget _buildCalendarNavButtons() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _currentWeekMonday = _currentWeekMonday.subtract(const Duration(days: 7));
              _generateWeekDates();
              _selectedDayIndex = 0;
            });
          },
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _currentWeekMonday = _currentWeekMonday.add(const Duration(days: 7));
              _generateWeekDates();
              _selectedDayIndex = 0;
            });
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildDaysBar() {
    return Row(
      children: List.generate(_weekDates.length, (index) {
        final date = _weekDates[index];
        final isSelected = index == _selectedDayIndex;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => setState(() => _selectedDayIndex = index),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF3E8FF) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF9333EA) : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('E').format(date),
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF7C3AED) : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('d').format(date),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          try {
            final List<dynamic> daysList = jsonDecode(data['dailyTasks'] as String? ?? '[]');
            final dayData = daysList.firstWhere((day) => day['date'] == dateKey, orElse: () => null);
            if (dayData != null && dayData['tasks'] != null) {
              for (var task in dayData['tasks']) {
                dailyTaskWidgets.add(_buildTaskCard(
                  title: task['title'],
                  folder: data['folderName'] ?? 'Course',
                  isCompleted: task['completed'] ?? false,
                  taskId: task['taskId'],
                  docId: doc.id,
                  fullDailyTasks: daysList,
                  dateKey: dateKey,
                ));
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
        border: Border.all(color: const Color(0xFFE8E8E8)),
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(folder, style: const TextStyle(fontSize: 12)),
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