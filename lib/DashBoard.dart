import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart'; 
import 'widgets/custom_sidebar.dart';
import 'pages/quiz_page.dart';
import 'services/pdf_text_extractor.dart';
import 'services/gemini_service.dart';
import 'pages/course_folders_page.dart';
import 'RevPlanPage.dart';
import 'pages/snaps_board_page.dart';
import 'pages/brain_games_page.dart';
import 'pages/profile_page.dart';
import 'pages/RevisionPlanCalendarPage.dart';


class DashBoard extends StatefulWidget {
  const DashBoard({super.key});

  @override
  State<StatefulWidget> createState() => _DashBoardState();
}

class _DashBoardState extends State<DashBoard> {
  int _selectedIndex = 0;
  
  // Dynamic Calendar State
  late List<DateTime> _weekDates;
  late int _selectedDayIndex;
  
  String _firstName = '';
  String? _selectedQuizFileName;
  Uint8List? _selectedQuizFileBytes;
  bool _isGeneratingQuiz = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _initializeCalendar();
  }

  void _initializeCalendar() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    _weekDates = List.generate(7, (index) => monday.add(Duration(days: index)));
    _selectedDayIndex = now.weekday - 1;
  }

  Future<void> _loadUserName() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _firstName = 'Guest');
      return;
    }
    try {
      final doc = await _firestore.collection('students').doc(user.uid).get();
      if (doc.exists) {
        final d = doc.data();
        final first = d?['firstName'] as String?;
        if (mounted) setState(() => _firstName = (first != null && first.isNotEmpty) ? first : user.displayName ?? user.email?.split('@').first ?? 'Guest');
      } else {
        if (mounted) setState(() => _firstName = user.displayName ?? user.email?.split('@').first ?? 'Guest');
      }
    } catch (_) {
      if (mounted) setState(() => _firstName = user.displayName ?? user.email?.split('@').first ?? 'Guest');
    }
  }

  List<Map<String, dynamic>> get _weekDays {
    final now = DateTime.now();
    final selected = DateTime(now.year, now.month, now.day)
        .add(Duration(days: _selectedDayIndex - 3));
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    return List.generate(7, (index) {
      final date = monday.add(Duration(days: index));
      return {
        'day': _weekdayShort(date.weekday),
        'date': '${_monthShort(date.month)} ${date.day}',
        'fullDate': DateTime(date.year, date.month, date.day),
      };
    });
  }

  Stream<List<Map<String, dynamic>>> _revisionPlansStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(const []);
    return _firestore
        .collection('revisionPlans')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  DateTime? _tryParseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  /// n8n / Firestore may use different keys than the app webhook payload.
  DateTime? _examDateFromPlan(Map<String, dynamic> plan) {
    return _tryParseDate(plan['examDate']) ??
        _tryParseDate(plan['exam_date']) ??
        _tryParseDate(plan['examDateIso']);
  }

  String _folderNameFromPlan(Map<String, dynamic> plan) {
    return plan['folderName'] as String? ??
        plan['folder_name'] as String? ??
        'Course';
  }

  /// Same shape as [RevisionPlanCalendarPage]: JSON array or list of day maps with `date` + `tasks`.
  List<dynamic> _parseDailyTasksFromPlan(Map<String, dynamic> plan) {
    final raw = plan['dailyTasks'];
    if (raw == null) return [];
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List<dynamic>) return decoded;
      } catch (_) {}
      return [];
    }
    if (raw is List) return raw;
    return [];
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime? _parseTaskScheduleDay(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) {
      final p = DateTime.tryParse(raw);
      if (p != null) return p;
    }
    return null;
  }

  Map<dynamic, dynamic>? _findDayEntryForTasks(
    List<dynamic> dailyTasks,
    DateTime date,
  ) {
    final n = DateTime(date.year, date.month, date.day);
    for (final day in dailyTasks) {
      if (day is! Map) continue;
      final map = Map<dynamic, dynamic>.from(day);
      final dayDate = _parseTaskScheduleDay(map['date']);
      if (dayDate != null && _isSameCalendarDay(dayDate, n)) {
        return map;
      }
    }
    return null;
  }

  String _weekdayShort(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1).clamp(0, 6)];
  }

  String _monthShort(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[(month - 1).clamp(0, 11)];
  }

  String _formatDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return '${_weekdayShort(d.weekday)}, ${_monthShort(d.month)} ${d.day}';
  }

  Widget _getPageForIndex(int index) {
    switch (index) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return RevPlanPage();
      case 2:
        return SnapsBoardPage();
      case 3:
        return CourseFoldersPage();
      case 4:
        return BrainGamesPage();
      case 5:
        return _buildQuizContent();
      case 6:
        return ProfilePage();
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return LayoutBuilder(
  builder: (context, constraints) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(), // Keeps scroll active
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 12, 32, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildHeader(),
                const SizedBox(height: 24),
                _buildGreeting(),
                const SizedBox(height: 28),
                _buildUpcomingExamsAndQuote(),
                const SizedBox(height: 28),
                _buildDailyTasks(),
              ],
            ),
          ),
        ],
      ),
    ),); },);
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.notifications_outlined,
              size: 28,
              color: Colors.grey[700],
            ),
            Positioned(
              top: 0,
              right: 0,
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
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    final name = _firstName.isEmpty ? 'Guest' : _firstName;
    return Text(
      'Hello, $name',
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }

Widget _buildUpcomingExamsAndQuote() {
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
                  const Text(
                    'Upcoming Exams',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
                  ),
                  const Text(
                    ' *',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _revisionPlansStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final today = DateTime.now();
                  final startToday = DateTime(today.year, today.month, today.day);
                  final plans = (snapshot.data ?? [])
                      .where((p) => _examDateFromPlan(p) != null)
                      .toList()
                    ..sort((a, b) => _examDateFromPlan(a)!
                        .compareTo(_examDateFromPlan(b)!));

                  final upcoming = plans
                      .where((p) => !_examDateFromPlan(p)!.isBefore(startToday))
                      .take(2)
                      .toList();

                  if (upcoming.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'No upcoming exams yet. Create a revision plan to get started.',
                        style: TextStyle(fontSize: 14, color: Colors.black54),
                      ),
                    );
                  }

                  return Column(
                    children: List.generate(upcoming.length, (index) {
                      final plan = upcoming[index];
                      final examDate = _examDateFromPlan(plan)!;
                      final title =
                          '${_folderNameFromPlan(plan).toUpperCase()} EXAM';
                      return Padding(
                        padding: EdgeInsets.only(bottom: index == upcoming.length - 1 ? 0 : 12),
                        child: _buildExamCard(
                          title: title,
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
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(flex: 1, child: _buildQuoteCard()),
      ],
    );
  }

Widget _buildExamCard({required String title, required String date, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Text(date, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // Helper to maintain UI consistency during loading/empty states
  Widget _buildExamPlaceholder({required Widget child}) {
    return Container(
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Center(child: child),
    );
  }

  Widget _buildQuoteCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFE9D5FF), const Color(0xFFDDD6FE)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '"',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, left: 8),
                  child: Text(
                    'Follow your plan, not your mood',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepPurple.shade800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: -8,
            child: Icon(
              Icons.psychology,
              size: 56,
              color: const Color(0xFF7C3AED).withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTasks() {
     final selectedDate = _weekDates[_selectedDayIndex];
    final formattedDate = DateFormat('EEEE, MMMM d').format(selectedDate);
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formattedDate, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
    final user = _auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
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
    final user = _auth.currentUser;
    if (user == null) return const Center(child: Text("Please sign in."));

    return StreamBuilder<QuerySnapshot>(
      // Listening to the top-level collection for this specific user
      stream: _firestore
          .collection('revisionPlans')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          ));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoTasksPlaceholder("No revision plans found.");
        }

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
          } catch (e) {
            debugPrint("Error parsing dailyTasks: $e");
          }
        }

        if (dailyTaskWidgets.isEmpty) {
          return _buildNoTasksPlaceholder("Relax! No tasks for today.");
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16, runSpacing: 16,
              children: dailyTaskWidgets.map((card) => SizedBox(width: cardWidth, child: card)).toList(),
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
    required bool isOverdue,
    required String taskId,
    required String docId,
    required List<dynamic> fullDailyTasks,
    required String dateKey,
  }) {
    return Container(
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
          // Completion Toggle
          InkWell(
            onTap: () => _toggleTaskCompletion(docId, taskId, fullDailyTasks, dateKey),
            child: Icon(
              isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isCompleted ? Colors.green : Colors.grey,
              size: 24,
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

  Future<void> _toggleTaskCompletion(String docId, String taskId, List<dynamic> fullDaysList, String dateKey) async {
    // 1. Update the local data structure
    for (var day in fullDaysList) {
      if (day['date'] == dateKey) {
        final tasks = day['tasks'] as List<dynamic>;
        for (var t in tasks) {
          if (t['taskId'] == taskId) {
            t['completed'] = !(t['completed'] ?? false);
          }
        }
      }
    }

    // 2. Re-encode and push to Firestore
    try {
      final updatedJson = jsonEncode(fullDaysList);
      await _firestore.collection('revisionPlans').doc(docId).update({
        'dailyTasks': updatedJson,
      });
    } catch (e) {
      debugPrint("Update failed: $e");
    }
  }

  // --- UI HELPERS ---

  Widget _buildNoTasksPlaceholder(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        children: [
          const Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
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
  // Increased spacing and height for a more "card-like" feel
  const double horizontalGap = 12.0;
  const double cardHeight = 80.0; 

  return Row(
    children: List.generate(_weekDates.length, (index) {
      final date = _weekDates[index];
      final isSelected = index == _selectedDayIndex;

      return Expanded(
        child: Padding(
          // Applies spacing between cards except after the last one
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
                      color: isSelected ? const Color(0xFFF3E8FF) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF9333EA) : Colors.grey[300]!,
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: isSelected 
                        ? [BoxShadow(color: const Color(0xFF9333EA).withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))]
                        : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('EEEE').format(date).substring(0, 3), // e.g., "Mon"
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? const Color(0xFF7C3AED) : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('d').format(date), // Just the number
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            color: isSelected ? const Color(0xFF7C3AED) : Colors.grey[700],
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(date), // e.g., "Apr"
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? const Color(0xFF9333EA).withOpacity(0.7) : Colors.grey[500],
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


  Widget _buildRescheduledBanner() {
    return Positioned(
      top: 0,
      right: 0,
      child: Transform.rotate(
        angle: 0.785398,
        alignment: Alignment.topRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF38BDF8),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Text(
            'Rescheduled',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  
 Future<void> _pickQuizFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes != null && bytes.isNotEmpty) {
        setState(() {
          _selectedQuizFileName = file.name;
          _selectedQuizFileBytes = bytes;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read file. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _startQuizFromPdf() async {
    final bytes = _selectedQuizFileBytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a PDF file first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isGeneratingQuiz = true);
    try {
      final extractedText = extractTextFromPdf(bytes);
      if (extractedText.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not extract text from this PDF.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final shortenedText = extractedText.length > 3000
          ? extractedText.substring(0, 3000)
          : extractedText;
      final quiz = await generateQuiz(shortenedText);
      if (!mounted) return;
      if (quiz.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not generate quiz. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizPage(quiz: quiz),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingQuiz = false);
    }
  }

 Widget _buildQuizContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          // This ensures the page is always scrollable for a better feel
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            // Forces the Column to be at least as tall as the screen
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 6,
                  width: double.infinity,
                  color: const Color(0xFFB3E5FC),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQuizHeader(),
                      const SizedBox(height: 32),
                      _buildQuizUploadZone(),
                      if (_selectedQuizFileName != null) ...[
                        const SizedBox(height: 24),
                        _buildSelectedFileAndStartButton(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuizHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Quiz',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.notifications_outlined,
              size: 28,
              color: Colors.grey[700],
            ),
            Positioned(
              top: 0,
              right: 0,
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
        ),
      ],
    );
  }

  Widget _buildQuizUploadZone() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickQuizFile,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          // Increased vertical padding to make the zone look more "full"
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.grey[50], // Added a slight background color
            border: Border.all(color: Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_outlined, size: 56, color: Colors.purple.shade300),
              const SizedBox(height: 20),
              Text(
                'Select your file or drag and drop',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800]
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Only PDF files are accepted',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9D5FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Browse Files',
                  style: TextStyle(
                    color: Colors.purple.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildSelectedFileAndStartButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedQuizFileName!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: _pickQuizFile,
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Change file',
              ),
              IconButton(
                onPressed: () => setState(() {
                  _selectedQuizFileName = null;
                  _selectedQuizFileBytes = null;
                }),
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Remove',
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isGeneratingQuiz ? null : _startQuizFromPdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9333EA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: _isGeneratingQuiz
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Generate Quiz Now',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Scaffold(
      body: MediaQuery(
        data: media.copyWith(
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.zero,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              child: Container(
                color: Colors.white,
                child: _getPageForIndex(_selectedIndex),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
