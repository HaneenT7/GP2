import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../widgets/custom_sidebar.dart';
import 'course_folders_page.dart';
import 'RevPlanPage.dart';
import 'snaps_board_page.dart';
import 'brain_games_page.dart';
import 'profile_page.dart';
import 'quiz_landing_page.dart';
import '../services/exam_notification_scheduler.dart';

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
    ExamNotificationScheduler.scheduleAll();
  }

  // Same order as IndexedStack children
  static const _pageTitles = [
    'Dashboard',
    'Course Folder',
    'Revision Plan',
    'Quiz',
    'Snaps Board',
    'Brain Games',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2F8), // off-white lavender base
      body: Row(
        children: [
          CustomSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) => setState(() => _selectedIndex = index),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transparent topbar — part of the frame layer
                  _buildTopBar(),
                  const SizedBox(height: 16),
                  // The floating white island
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF553C76).withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 2),
                          ),
                          BoxShadow(
                            color: const Color(0xFF553C76).withValues(alpha: 0.05),
                            blurRadius: 0,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: RepaintBoundary(
                          child: IndexedStack(
                            index: _selectedIndex,
                            children: const [
                              DashboardHomeContent(),
                              CourseFoldersPage(),
                              RevPlanPage(),
                              QuizLandingPage(),
                              SnapsBoardPage(),
                              BrainGamesPage(),
                              ProfilePage(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _pageTitles[_selectedIndex], // ← dynamic title
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D1F3D),
              letterSpacing: -0.3,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: const Color(0xFF553C76),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardHomeContent extends StatelessWidget {
  const DashboardHomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GreetingWidget(),
            const SizedBox(height: 28),
            const UpcomingExamsSection(),
            const SizedBox(height: 28),
            const DailyTasksSection(),
          ],
        ),
      ),
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
    final doc = await FirebaseFirestore.instance
        .collection('students')
        .doc(user.uid)
        .get();
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
    return plan['folderName'] as String? ??
        plan['folder_name'] as String? ??
        'Course';
  }

  Stream<List<Map<String, dynamic>>> _revisionPlansStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(const []);
    return FirebaseFirestore.instance
        .collection('revisionPlans')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
            .toList());
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.school_outlined,
                        size: 22, color: Colors.purple.shade300),
                    const SizedBox(width: 8),
                    const Text('Upcoming Exams',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black)),
                    const Text(' *',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _revisionPlansStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final today = DateTime.now();
                      final startToday =
                          DateTime(today.year, today.month, today.day);
                      final plans = (snapshot.data ?? [])
                          .where((p) => _examDateFromPlan(p) != null)
                          .toList()
                        ..sort((a, b) => _examDateFromPlan(a)!
                            .compareTo(_examDateFromPlan(b)!));

                      final upcoming = plans
                          .where((p) =>
                              !_examDateFromPlan(p)!.isBefore(startToday))
                          .take(2)
                          .toList();

                      if (upcoming.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Text('No upcoming exams yet.',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.black54)),
                        );
                      }

                      return Column(
                        children: List.generate(upcoming.length, (index) {
                          final plan = upcoming[index];
                          final examDate = _examDateFromPlan(plan)!;
                          return Padding(
                            padding: EdgeInsets.only(
                                bottom: index == upcoming.length - 1 ? 0 : 12),
                            child: _ExamCardWidget(
                              title:
                                  '${_folderNameFromPlan(plan).toUpperCase()} EXAM',
                              date:
                                  '${examDate.day.toString().padLeft(2, '0')}/${examDate.month.toString().padLeft(2, '0')}/${examDate.year}',
                              color: index.isEven
                                  ? const Color(0xFFFFF3CD)
                                  : const Color(0xFFFFE4CC),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          const Expanded(
            flex: 1,
            child: Padding(
              padding: EdgeInsets.only(top: 34),
              child: QuoteCardWidget(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamCardWidget extends StatelessWidget {
  final String title;
  final String date;
  final Color color;
  const _ExamCardWidget(
      {required this.title, required this.date, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          Text(date, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class QuoteCardWidget extends StatefulWidget {
  const QuoteCardWidget({super.key});

  @override
  State<QuoteCardWidget> createState() => _QuoteCardWidgetState();
}

class _QuoteCardWidgetState extends State<QuoteCardWidget> {
  static const List<String> _quotes = [
    'Follow your plan, not your mood.',
    'Small steps every day beat a perfect plan you never start.',
    "You're closer than you think — keep going.",
    'Focus on progress, not perfection.',
    "Today's effort is tomorrow's confidence.",
    'Discipline is choosing what you want most over what you want now.',
    'One focused session at a time builds real mastery.',
    'Rest is part of the work — come back stronger.',
    'You have overcome hard days before; this one is no different.',
    'Show up for yourself, even when motivation is quiet.',
    'Your future self will thank you for not giving up today.',
    'Consistency beats intensity — stay steady.',
  ];

  late int _index;

  @override
  void initState() {
    super.initState();
    _index = _seedIndexForToday();
  }

  /// Stable pick per calendar day so the “daily” message refreshes naturally each day.
  int _seedIndexForToday() {
    final n = DateTime.now();
    final dayKey = n.year * 10000 + n.month * 100 + n.day;
    return dayKey % _quotes.length;
  }

  void _showNextQuote() {
    setState(() => _index = (_index + 1) % _quotes.length);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Tap for another motivational quote',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _showNextQuote,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withValues(alpha: 0.35),
          highlightColor: Colors.white.withValues(alpha: 0.15),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFE9D5FF), Color(0xFFDDD6FE)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('"',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1)),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, left: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _quotes[_index],
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.deepPurple.shade800),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: Colors.deepPurple.shade600
                                        .withValues(alpha: 0.65),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Tap for another',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.deepPurple.shade600
                                          .withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                      right: -5,
                      bottom: -5,
                      child: Icon(Icons.psychology,
                          size: 40,
                          color: const Color(0xFF7C3AED)
                              .withValues(alpha: 0.3))),
                ],
              ),
            ),
          ),
        ),
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
    _weekDates = List.generate(
        7, (index) => _currentWeekMonday.add(Duration(days: index)));
  }

  bool _isDateBeforeToday(String dateKey) {
    final d = DateTime.tryParse(dateKey);
    if (d == null) return false;
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(d.year, d.month, d.day);
    return day.isBefore(today);
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
        _buildOverdueInfoBar(dateKey), // ADDED FROM TEAMMATE
        const SizedBox(height: 24),
        _buildFirestoreTasksList(dateKey),
      ],
    );
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
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const SizedBox.shrink();

        int overdueOnSelectedDay = 0;
        int totalOverdue = 0;

        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final List<dynamic> daysList =
              jsonDecode(data['dailyTasks'] as String? ?? '[]');

          for (final day in daysList) {
            final dayDateKey = day['date']?.toString();
            if (dayDateKey == null || !_isDateBeforeToday(dayDateKey)) continue;
            final tasks = day['tasks'] as List<dynamic>? ?? [];
            for (final task in tasks) {
              if (task['completed'] != true) {
                totalOverdue++;
                if (dayDateKey == dateKey) overdueOnSelectedDay++;
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
              Icon(Icons.warning_amber_rounded,
                  color: Colors.deepOrange.shade800, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  overdueOnSelectedDay > 0
                      ? 'Overdue on selected day: $overdueOnSelectedDay  •  Total overdue: $totalOverdue'
                      : 'Total overdue tasks: $totalOverdue',
                  style: TextStyle(
                      color: Colors.deepOrange.shade900,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
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
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return _buildNoTasksPlaceholder("No revision plans found.");

        List<Widget> dailyTaskWidgets = [];
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          try {
            final List<dynamic> daysList =
                jsonDecode(data['dailyTasks'] as String? ?? '[]');
            dynamic dayData;
            for (final day in daysList) {
              if (day is Map && day['date'] == dateKey) {
                dayData = day;
                break;
              }
            }
            if (dayData != null && dayData['tasks'] != null) {
              for (var task in dayData['tasks']) {
                dailyTaskWidgets.add(_buildTaskCard(
                  title: task['title'],
                  folder: data['folderName'] ?? 'Course',
                  isCompleted: task['completed'] ?? false,
                  isOverdue: _isDateBeforeToday(dateKey) &&
                      (task['completed'] != true), // ADDED LOGIC
                  taskId: task['taskId'],
                  docId: doc.id,
                  fullDailyTasks: daysList,
                  dateKey: dateKey,
                ));
              }
            }
          } catch (_) {}
        }

        if (dailyTaskWidgets.isEmpty)
          return _buildNoTasksPlaceholder("Relax! No tasks for today.");

        return LayoutBuilder(
          builder: (context, constraints) {
            final double itemWidth = (constraints.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: dailyTaskWidgets
                  .map((widget) => SizedBox(width: itemWidth, child: widget))
                  .toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildTaskCard({
    required String title,
    required String folder,
    required bool isCompleted,
    required bool isOverdue, // ADDED PARAM
    required String taskId,
    required String docId,
    required List fullDailyTasks,
    required String dateKey,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? const Color(0xFFE6F7E9) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? Colors.green.shade100
              : (isOverdue
                  ? Colors.deepOrange.shade300
                  : const Color(0xFFE8E8E8)),
          width: isOverdue && !isCompleted ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () async {
              for (var day in fullDailyTasks) {
                if (day['date'] == dateKey) {
                  for (var t in day['tasks']) {
                    if (t['taskId'] == taskId)
                      t['completed'] = !(t['completed'] ?? false);
                  }
                }
              }
              await FirebaseFirestore.instance
                  .collection('revisionPlans')
                  .doc(docId)
                  .update({'dailyTasks': jsonEncode(fullDailyTasks)});
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
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted
                        ? Colors.green.shade700
                        : (isOverdue
                            ? Colors.deepOrange.shade900
                            : Colors.black87),
                  ),
                ),
                Text(
                  folder,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCompleted ? Colors.green.shade400 : Colors.grey,
                  ),
                ),
                if (isOverdue && !isCompleted) ...[
                  const SizedBox(height: 4),
                  Text('Overdue',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange.shade800)),
                ]
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
      child: Center(
          child: Text(message, style: const TextStyle(color: Colors.grey))),
    );
  }

  Widget _buildCalendarNavButtons() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _currentWeekMonday =
                  _currentWeekMonday.subtract(const Duration(days: 7));
              _generateWeekDates();
              _selectedDayIndex = 0;
            });
          },
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _currentWeekMonday =
                  _currentWeekMonday.add(const Duration(days: 7));
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
        children: List.generate(
      _weekDates.length,
      (index) {
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
                    color: isSelected
                        ? const Color(0xFF9333EA)
                        : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(DateFormat('E').format(date),
                        style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF7C3AED)
                                : Colors.black87,
                            fontWeight: FontWeight.bold)),
                    Text(DateFormat('d').format(date),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ));
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
            Icon(Icons.notifications_none_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No notifications yet',
                style: TextStyle(fontSize: 18, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
