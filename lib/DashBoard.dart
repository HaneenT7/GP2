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
  
  late List<DateTime> _weekDates;
  late int _selectedDayIndex;
  
  String _firstName = '';

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

  DateTime? _examDateFromPlan(Map<String, dynamic> plan) {
    final raw = plan['examDate'] ?? plan['exam_date'] ?? plan['examDateIso'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _folderNameFromPlan(Map<String, dynamic> plan) {
    return plan['folderName'] as String? ?? plan['folder_name'] as String? ?? 'Course';
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
        return const QuizLandingPage(); 
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
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
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
        ),
      );
    },
  );
}

  Widget _buildGreeting() {
    final name = _firstName.isEmpty ? 'Guest' : _firstName;
    return Text(
      'Hello, $name',
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
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
                  const Text('Upcoming Exams', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black)),
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
                        child: _buildExamCard(
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
        Expanded(flex: 1, child: _buildQuoteCard()),
      ],
    );
  }

Widget _buildExamCard({required String title, required String date, required Color color}) {
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

  Widget _buildQuoteCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFFE9D5FF), const Color(0xFFDDD6FE)]),
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
                  child: Text('Follow your plan, not your mood', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.deepPurple.shade800)),
                ),
              ),
            ],
          ),
          Positioned(right: 0, bottom: -8, child: Icon(Icons.psychology, size: 56, color: const Color(0xFF7C3AED).withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildDailyTasks() {
    final selectedDate = _weekDates[_selectedDayIndex];
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(DateFormat('EEEE, MMMM d').format(selectedDate), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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

  Widget _buildFirestoreTasksList(String dateKey) {
    final user = _auth.currentUser;
    if (user == null) return const Center(child: Text("Please sign in."));
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('revisionPlans').where('userId', isEqualTo: user.uid).snapshots(),
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
                dailyTaskWidgets.add(_buildTaskCard(title: task['title'], folder: data['folderName'], isCompleted: task['completed'], taskId: task['taskId'], docId: doc.id, fullDailyTasks: daysList, dateKey: dateKey));
              }
            }
          } catch (_) {}
        }
        return dailyTaskWidgets.isEmpty ? _buildNoTasksPlaceholder("Relax! No tasks for today.") : Wrap(spacing: 16, runSpacing: 16, children: dailyTaskWidgets);
      },
    );
  }

  Widget _buildTaskCard({required String title, required String folder, required bool isCompleted, required String taskId, required String docId, required List fullDailyTasks, required String dateKey}) {
    return Container(
      width: (MediaQuery.of(context).size.width - 400) / 2, // Approximate for dashboard layout
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isCompleted ? const Color(0xFFE6F7E9) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8E8E8))),
      child: Row(
        children: [
          InkWell(
            onTap: () async {
              for (var day in fullDailyTasks) {
                if (day['date'] == dateKey) {
                  for (var t in day['tasks']) { if (t['taskId'] == taskId) t['completed'] = !(t['completed'] ?? false); }
                }
              }
              await _firestore.collection('revisionPlans').doc(docId).update({'dailyTasks': jsonEncode(fullDailyTasks)});
            },
            child: Icon(isCompleted ? Icons.check_circle : Icons.radio_button_unchecked, color: isCompleted ? Colors.green : Colors.grey),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), Text(folder, style: const TextStyle(fontSize: 12))])),
        ],
      ),
    );
  }

  Widget _buildNoTasksPlaceholder(String message) {
    return Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 40), child: Center(child: Text(message, style: const TextStyle(color: Colors.grey))));
  }

  Widget _buildCalendarNavButtons() {
    return Row(children: [
      IconButton(onPressed: () => setState(() => _selectedDayIndex = (_selectedDayIndex > 0) ? _selectedDayIndex - 1 : 0), icon: const Icon(Icons.chevron_left)),
      IconButton(onPressed: () => setState(() => _selectedDayIndex = (_selectedDayIndex < 6) ? _selectedDayIndex + 1 : 6), icon: const Icon(Icons.chevron_right)),
    ]);
  }

  Widget _buildDaysBar() {
    return Row(children: List.generate(_weekDates.length, (index) {
      final date = _weekDates[index];
      final isSelected = index == _selectedDayIndex;
      return Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: () => setState(() => _selectedDayIndex = index),
          child: Container(
            height: 80,
            decoration: BoxDecoration(color: isSelected ? const Color(0xFFF3E8FF) : Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? const Color(0xFF9333EA) : Colors.grey[300]!)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(DateFormat('E').format(date), style: TextStyle(color: isSelected ? const Color(0xFF7C3AED) : Colors.black87, fontWeight: FontWeight.bold)),
              Text(DateFormat('d').format(date), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ));
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          CustomSidebar(selectedIndex: _selectedIndex, onItemSelected: (index) => setState(() => _selectedIndex = index)),
          Expanded(child: Container(color: Colors.white, child: _getPageForIndex(_selectedIndex))),
        ],
      ),
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