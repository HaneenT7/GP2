import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gp2_watad/services/notification_service.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_sidebar.dart';
import 'course_folders_page.dart';
import 'RevPlanPage.dart';
import 'snaps_board_page.dart';
import 'brain_games_page.dart';
import 'profile_page.dart';
import 'quiz_landing_page.dart';
import 'quiz_page.dart';
import '../services/health_connect_service.dart';
import '../services/heart_rate_alert_service.dart';
import '../theme/revision_task_card_style.dart';
import '../utils/revision_plan_overdue.dart';
import '../services/task_quiz_service.dart';

class DashBoard extends StatefulWidget {
  const DashBoard({super.key});

  @override
  State<StatefulWidget> createState() => _DashBoardState();
}

class _DashBoardState extends State<DashBoard> {
  int _selectedIndex = 0;
  final HealthConnectService _healthConnectService = HealthConnectService();
  Timer? _heartRateMonitorTimer;

  @override
  void initState() {
    super.initState();
    // ── شغلِك: تهيئة الإشعارات السحابية بعد بناء الإطار ──
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      try {
        await NotificationService().initialize(context);
      } catch (e) {
        debugPrint('❌ [DashBoard] Error during notification initialization: $e');
      }
    });

    // مراقبة النبض + تنبيه 100+ والانتقال لـ Brain Games
    HeartRateAlertService.onGoToBrainGames = _openBrainGames;
    NotificationService.onNotificationPayload = _onNotificationPayload;
    _handleLaunchFromHeartRateNotification();
    if (Platform.isAndroid) {
      _startHeartRateMonitoring();
    }
  }

  @override
  void dispose() {
    _heartRateMonitorTimer?.cancel();
    HeartRateAlertService.onGoToBrainGames = null;
    NotificationService.onNotificationPayload = null;
    super.dispose();
  }

  void _openBrainGames() {
    if (!mounted) return;
    setState(() => _selectedIndex = kBrainGamesTabIndex);
  }

  void _onNotificationPayload(String? payload) {
    if (payload == NotificationService.heartRateAlertPayload) {
      _openBrainGames();
    }
  }

  Future<void> _handleLaunchFromHeartRateNotification() async {
    final payload = await NotificationService.getLaunchNotificationPayload();
    if (payload == NotificationService.heartRateAlertPayload && mounted) {
      _openBrainGames();
    }
  }

  void _startHeartRateMonitoring() {
    _checkHeartRateForAlert();
    _heartRateMonitorTimer = Timer.periodic(
      const Duration(minutes: 3),
      (_) => _checkHeartRateForAlert(),
    );
  }

  Future<void> _checkHeartRateForAlert() async {
    try {
      final snapshot = await _healthConnectService.fetchLatestVitals(
        lookback: const Duration(hours: 48),
      );
      if (!mounted) return;

      final readings = snapshot.recentHeartRates.isNotEmpty
          ? snapshot.recentHeartRates
          : [
              if (snapshot.heartRate != null) snapshot.heartRate!,
            ];

      if (readings.isNotEmpty) {
        HeartRateAlertService.evaluateReadings(readings, context: context);
      }
    } catch (_) {
      // Health Connect may be unavailable; skip silently.
    }
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
      resizeToAvoidBottomInset: false,
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

  // ── شغلِك: بناء الـ TopBar مع الـ StreamBuilder لقراءة النقطة الحمراء (Badge) ──
  Widget _buildTopBar() {
    final user = FirebaseAuth.instance.currentUser;

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
          if (user != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: user.uid)
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                final hasUnread =
                    snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      color: const Color(0xFF553C76),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsPage()),
                      ),
                    ),
                    if (hasUnread)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              color: const Color(0xFF553C76),
              onPressed: () {},
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 32,
              compact ? 20 : 28,
              compact ? 16 : 32,
              compact ? 16 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // const GreetingWidget(),
                const SizedBox(height: 28),
                const UpcomingExamsSection(),
                const SizedBox(height: 28),
                const DailyTasksSection(),
              ],
            ),
          ),
        );
      },
    );
  }
}

// class GreetingWidget extends StatefulWidget {
//   const GreetingWidget({super.key});

//   @override
//   State<GreetingWidget> createState() => _GreetingWidgetState();
// }

// class _GreetingWidgetState extends State<GreetingWidget> {
//   String _firstName = '';

//   @override
//   void initState() {
//     super.initState();
//     _loadUserName();
//   }

//   Future<void> _loadUserName() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;
//     final doc = await FirebaseFirestore.instance
//         .collection('students')
//         .doc(user.uid)
//         .get();
//     if (mounted && doc.exists) {
//       setState(() => _firstName = doc.data()?['firstName'] ?? 'Guest');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Align(
//       alignment: Alignment.centerLeft,
//       child: Text(
//         'Hello, ${_firstName.isEmpty ? "Guest" : _firstName}',
//         style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//       ),
//     );
//   }
// }

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackSections = constraints.maxWidth < 720;
        final examsSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
            _buildUpcomingExamsList(),
          ],
        );
        final quoteSection = Padding(
          padding: EdgeInsets.only(top: stackSections ? 16 : 34),
          child: const QuoteCardWidget(),
        );

        if (stackSections) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              examsSection,
              quoteSection,
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 1, child: examsSection),
              const SizedBox(width: 24),
              Expanded(flex: 1, child: quoteSection),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcomingExamsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _revisionPlansStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final today = DateTime.now();
        final startToday = DateTime(today.year, today.month, today.day);
        final plans = (snapshot.data ?? [])
            .where((p) => _examDateFromPlan(p) != null)
            .toList()
          ..sort((a, b) =>
              _examDateFromPlan(a)!.compareTo(_examDateFromPlan(b)!));

        final upcoming = plans
            .where((p) => !_examDateFromPlan(p)!.isBefore(startToday))
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
                style: TextStyle(fontSize: 14, color: Colors.black54)),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(upcoming.length, (index) {
            final plan = upcoming[index];
            final examDate = _examDateFromPlan(plan)!;
            return Padding(
              padding: EdgeInsets.only(
                  bottom: index == upcoming.length - 1 ? 0 : 12),
              child: _ExamCardWidget(
                title: '${_folderNameFromPlan(plan).toUpperCase()} EXAM',
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
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
            ),
          ),
          const SizedBox(width: 12),
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

  // ── نقل دالة المساعدة لمعرفة التواريخ السابقة من الملف الثاني لخدمة حساب الـ Overdue ──
  bool _isDateBeforeToday(String dateKey) {
    final d = DateTime.tryParse(dateKey);
    if (d == null) return false;
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(d.year, d.month, d.day);
    return day.isBefore(today);
  }

  // ── شغلِك: Stream يجيب كل تواريخ الاختبارات للطالب لوضع النجمة الحمراء ──
  Stream<Set<String>> _examDatesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value({});
    return FirebaseFirestore.instance
        .collection('revisionPlans')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final Set<String> examDates = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final raw =
            data['examDate'] ?? data['exam_date'] ?? data['examDateIso'];
        DateTime? date;
        if (raw is Timestamp) date = raw.toDate();
        if (raw is String) date = DateTime.tryParse(raw);
        if (date != null) {
          examDates.add(DateFormat('yyyy-MM-dd').format(date));
        }
      }
      return examDates;
    });
  }

  void _jumpToFirstOverdueDay(Iterable<QueryDocumentSnapshot> planDocs) {
    DateTime? first;
    for (final doc in planDocs) {
      final data = doc.data() as Map<String, dynamic>;
      if (isRevisionPlanExamPassed(data)) continue;
      final day = firstRevisionPlanOverdueDay(parseRevisionPlanDailyTasks(data));
      if (day == null) continue;
      final d = DateTime(day.year, day.month, day.day);
      if (first == null || d.isBefore(first)) first = d;
    }
    if (first == null) return;
    setState(() {
      final daysSinceSunday = first!.weekday % 7;
      _currentWeekMonday = first.subtract(Duration(days: daysSinceSunday));
      _generateWeekDates();
      for (var i = 0; i < _weekDates.length; i++) {
        if (sameRevisionCalendarDay(_weekDates[i], first)) {
          _selectedDayIndex = i;
          break;
        }
      }
    });
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

        var overdueOnSelectedDay = 0;
        var totalOverdue = 0;
        final selectedDate = DateTime.tryParse(dateKey);

        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (isRevisionPlanExamPassed(data)) continue;
          final daysList = parseRevisionPlanDailyTasks(data);
          totalOverdue += countOverdueTasks(daysList);

          if (selectedDate != null) {
            overdueOnSelectedDay += countOverdueTasksOnDate(daysList, selectedDate);
          }
        }

        if (totalOverdue == 0) return const SizedBox.shrink();

        final planDocs = snapshot.data!.docs;

        return Material(
          color: Colors.deepOrange.shade50,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _jumpToFirstOverdueDay(planDocs),
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
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
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: Colors.deepOrange.shade700, size: 22),
                ],
              ),
            ),
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
        List<Widget> examCardWidgets = []; // ── شغلِك: لتخزين بطاقات الـ Good Luck ──

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final examPassed = isRevisionPlanExamPassed(data);
          final materialTitle = data['materialTitle']?.toString();

          // ── شغلِك: تحقق إذا اليوم المحدد فيه اختبار لهذا الكورس لحقن البطاقة الوردية ──
          try {
            final raw = data['examDate'] ?? data['exam_date'] ?? data['examDateIso'];
            DateTime? examDate;
            if (raw is Timestamp) examDate = raw.toDate();
            if (raw is String) examDate = DateTime.tryParse(raw);
            if (examDate != null) {
              final examDateKey = DateFormat('yyyy-MM-dd').format(examDate);
              if (examDateKey == dateKey) {
                final folderName = (data['folderName'] as String? ?? 'Course').toUpperCase();
                examCardWidgets.add(_buildExamCard(folderName));
              }
            }
          } catch (_) {}

          try {
            final daysList = parseRevisionPlanDailyTasks(data);
            final dayDate = DateTime.tryParse(dateKey);
            final tasksForDay = revisionPlanTasksOnDate(daysList, dateKey);
            if (tasksForDay.isNotEmpty) {
              for (var task in tasksForDay) {
                final taskMap = task is Map ? task : <String, dynamic>{};
                dailyTaskWidgets.add(_buildTaskCard(
                  title: task['title'],
                  folder: data['folderName'] ?? 'Course',
                  pdfName: task['fileName'] ??
                      (materialTitle != null && materialTitle.isNotEmpty
                          ? materialTitle
                          : 'General'),
                  pages: task['pages']?.toString() ?? '',
                  isCompleted: task['completed'] ?? false,
                  isOverdue: !examPassed &&
                      dayDate != null &&
                      task is Map &&
                      isRevisionTaskOverdue(dayDate, taskMap),
                  isRescheduled: task['rescheduled'] == true,
                  taskId: task['taskId'],
                  docId: doc.id,
                  fullDailyTasks: daysList,
                  dateKey: dateKey,
                ));
              }
            }
          } catch (_) {}
        }

        if (dailyTaskWidgets.isEmpty && examCardWidgets.isEmpty)
          return _buildNoTasksPlaceholder("Relax! No tasks for today.");

        return LayoutBuilder(
          builder: (context, constraints) {
            final useSingleColumn = constraints.maxWidth < 520;
            final double itemWidth = useSingleColumn
                ? constraints.maxWidth
                : (constraints.maxWidth - 16) / 2;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── شغلِك: حقن بطاقات الاختبار الوردية لتظهر فوق كاملة العرض ──
                ...examCardWidgets.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: w,
                )),
                // باقي المهام في شبكة (شغل زميلتك المتجاوب)
                if (dailyTaskWidgets.isNotEmpty)
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: dailyTaskWidgets
                        .map((widget) => SizedBox(width: itemWidth, child: widget))
                        .toList(),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTaskCard({
    required String title,
    required String folder,
    required String pdfName, 
    required String pages, 
    required bool isCompleted,
    required bool isOverdue,
    required bool isRescheduled,
    required String taskId,
    required String docId,
    required List fullDailyTasks,
    required String dateKey,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RevisionTaskCardStyle.background(
          isCompleted: isCompleted,
          isOverdue: isOverdue,
          isRescheduled: isRescheduled,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: RevisionTaskCardStyle.border(
            isCompleted: isCompleted,
            isOverdue: isOverdue,
            isRescheduled: isRescheduled,
          ),
          width: RevisionTaskCardStyle.borderWidth(
            isCompleted: isCompleted,
            isOverdue: isOverdue,
            isRescheduled: isRescheduled,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Checkbox on left
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle
                        : isRescheduled
                            ? Icons.schedule
                            : Icons.radio_button_unchecked,
                    color: isCompleted
                        ? Colors.green
                        : RevisionTaskCardStyle.iconAccent(
                                isOverdue: isOverdue,
                                isRescheduled: isRescheduled,
                              ) ??
                            Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isCompleted
                                  ? Colors.green.shade700
                                  : RevisionTaskCardStyle.title(
                                      isCompleted: isCompleted,
                                      isOverdue: isOverdue,
                                      isRescheduled: isRescheduled,
                                    ),
                            ),
                          ),
                        ),
                        if (isRescheduled && !isCompleted)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: RevisionTaskCardStyle
                                  .rescheduledBadgeBackground,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Rescheduled',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: RevisionTaskCardStyle.rescheduledTitle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$folder • ${pdfName.isNotEmpty ? pdfName : "Multiple Sources"}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isCompleted
                            ? Colors.green.shade400
                            : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Pages and status row
          Row(
            children: [
              if (pages.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'pp. $pages',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (isOverdue && !isCompleted)
                Text(
                  'Overdue',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange.shade800,
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Bottom row: Take Quiz button on right
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                height: 28,
                child: ElevatedButton(
                  onPressed: isCompleted ? null : () => _takeQuizForTask(
                    title: title,
                    folder: folder,
                    pdfName: pdfName,
                    pages: pages,
                    taskDocId: docId,
                    taskId: taskId,
                    dateKey: dateKey,
                    fullDailyTasks: fullDailyTasks,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text(
                    'Take Quiz',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? Colors.grey : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _takeQuizForTask({
    required String title,
    required String folder,
    required String pdfName,
    required String pages,
    required String taskDocId,
    required String taskId,
    required String dateKey,
    required List fullDailyTasks,
  }) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Generating quiz for "$title"...',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final quiz = await TaskQuizService.generateTaskQuiz(
        taskTitle: title,
        subject: folder,
        topic: pages.isNotEmpty ? 'Pages: $pages' : null,
        materialTitle: pdfName.isNotEmpty ? pdfName : null,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Navigate to QuizPage with generated quiz and task info for auto-completion
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizPage(
            quiz: quiz,
            onExit: () => Navigator.pop(context),
            taskDocId: taskDocId,
            taskId: taskId,
            dateKey: dateKey,
            fullDailyTasks: fullDailyTasks,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating quiz: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // ── شغلِك: تابع لكارت الـ Good luck الوردي المنقول من الملف الثاني ──
  Widget _buildExamCard(String folderName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDFA4C0), width: 1.5),
      ),
      child: Row(
        children: [
          const Text('🍀', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$folderName EXAM',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Good luck!',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
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

  // ── شغلِك: شريط الأيام مع الـ StreamBuilder لوضع النجمة الحمراء عند وجود اختبار ──
  Widget _buildDaysBar() {
    return StreamBuilder<Set<String>>(
      stream: _examDatesStream(),
      builder: (context, snapshot) {
        final examDates = snapshot.data ?? {};
        return Row(
          children: List.generate(_weekDates.length, (index) {
            final date = _weekDates[index];
            final isSelected = index == _selectedDayIndex;
            final dateKey = DateFormat('yyyy-MM-dd').format(date);
            final hasExam = examDates.contains(dateKey);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => setState(() => _selectedDayIndex = index),
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF3E8FF)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF9333EA)
                            : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('E').format(date),
                                style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF7C3AED)
                                        : Colors.black87,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                DateFormat('d').format(date),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        // النجمة الحمراء إذا فيه اختبار في هذا اليوم
                        if (hasExam)
                          const Positioned(
                            top: 4,
                            left: 6,
                            child: Text(
                              '*',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                                height: 1,
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
        );
      },
    );
  }
}

// ── شغلِك: صفحة الإشعارات الكاملة والمتصلة بـ Firestore المنسوخة من الملف الثاني ──
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
      body: user == null
          ? const Center(child: Text('Please sign in.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_outlined,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('No notifications yet',
                            style: TextStyle(
                                fontSize: 18, color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final bool isRead = data['isRead'] ?? false;
                    final Timestamp? ts = data['createdAt'] as Timestamp?;
                    final String timeAgo =
                        ts != null ? _formatTime(ts.toDate()) : '';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isRead
                              ? Colors.grey[100]
                              : const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.school_outlined,
                          color: isRead ? Colors.grey : const Color(0xFF7C3AED),
                          size: 22,
                        ),
                      ),
                      title: Text(
                        data['title'] ?? '',
                        style: TextStyle(
                          fontWeight:
                              isRead ? FontWeight.normal : FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(data['body'] ?? '',
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(timeAgo,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[400])),
                        ],
                      ),
                      onTap: () {
                        if (!isRead) {
                          docs[index].reference.update({'isRead': true});
                        }
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}