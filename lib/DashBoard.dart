import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/custom_sidebar.dart';
import 'pages/course_folders_page.dart';
import 'RevPlanPage.dart';
import 'pages/snaps_board_page.dart';
import 'pages/brain_games_page.dart';
import 'pages/profile_page.dart';
import "pages/availability_calendar_dialog.dart";


class DashBoard extends StatefulWidget {
  const DashBoard({super.key});

  @override
  State<StatefulWidget> createState() => _DashBoardState();
}

class _DashBoardState extends State<DashBoard> {
  int _selectedIndex = 0;
  int _selectedDayIndex = 3; // Thu Nov 27
  String _firstName = '';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadUserName();
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

  static const List<Map<String, dynamic>> _weekDays = [
    {'day': 'Mon', 'date': 'Nov 24'},
    {'day': 'Tue', 'date': 'Nov 25'},
    {'day': 'Wed', 'date': 'Nov 26'},
    {'day': 'Thu', 'date': 'Nov 27'},
    {'day': 'Fri', 'date': 'Nov 28'},
    {'day': 'Sat', 'date': 'Nov 29'},
    {'day': 'Sun', 'date': 'Nov 30'},
  ];

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
        return const Center(child: Text("Quiz Content"));
      case 6:
        return ProfilePage();
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
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
    );
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
            children: [
              Row(
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 22,
                    color: Colors.purple.shade300,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Upcoming Exams',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    ' *',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildExamCard(
                title: 'SEW 434 EXAM',
                date: '30/11/2025',
                color: const Color(0xFFFFF3CD),
              ),
              const SizedBox(height: 12),
              _buildExamCard(
                title: 'SEW 343 EXAM',
                date: '05/12/2025',
                color: const Color(0xFFFFE4CC),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(flex: 1, child: _buildQuoteCard()),
      ],
    );
  }

  Widget _buildExamCard({
    required String title,
    required String date,
    required Color color,
  }) {
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
              Image.asset(
                'assets/images/quote_mark.png',
                width: 48,
                height: 48,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Text(
                  '"',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1,
                  ),
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
            child: Image.asset(
              'assets/images/dashboard_brain.png',
              width: 64,
              height: 64,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.psychology,
                size: 56,
                color: const Color(0xFF7C3AED).withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildDailyTasks() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Daily Tasks',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          // 🆕 ADD THIS BUTTON
          OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AvailabilityCalendarDialog(),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF9333EA),
              side: const BorderSide(color: Color(0xFFE9D5FF), width: 2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: const Color(0xFFFAF5FF),
            ),
            icon: const Icon(Icons.calendar_today, size: 18),
            label: const Text(
              'Configure Availability',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Thursday, November 27',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[400]!),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.refresh, size: 16, color: Colors.grey[700]),
                label: Text(
                  'Reschedule Overdue Tasks',
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    if (_selectedDayIndex > 0) _selectedDayIndex--;
                  });
                },
                icon: Icon(Icons.chevron_left, color: Colors.grey[700]),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    if (_selectedDayIndex < _weekDays.length - 1)
                      _selectedDayIndex++;
                  });
                },
                icon: Icon(Icons.chevron_right, color: Colors.grey[700]),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 20),
      _buildDaysBar(),
      const SizedBox(height: 24),
      _buildTaskCards(),
    ],
  );
}


  Widget _buildDaysBar() {
    const spacing = 10.0;
    const boxHeight = 64.0;
    return Row(
      children: List.generate(_weekDays.length, (index) {
        final day = _weekDays[index];
        final isSelected = index == _selectedDayIndex;
        final hasRedDot = index == 6;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < _weekDays.length - 1 ? spacing : 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedDayIndex = index),
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      height: boxHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            day['day'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            day['date'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (hasRedDot)
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
    );
  }

  Widget _buildTaskCards() {
    final completedTasks = [
      {'title': 'Revise Chapter 9', 'course': 'Math 106'},
      {'title': 'Revise Chapter 10', 'course': 'Math 106'},
      {'title': 'Revise Chapter 6', 'course': 'SWE 211'},
    ];
    final pendingTasks = [
      {'title': 'Revise Chapter 7', 'course': 'SWE 211'},
      {'title': 'Revise Chapter 8', 'course': 'SWE 211'},
    ];
    final rescheduledTasks = [
      {'title': 'Revise Chapter 1', 'course': 'SWE 343'},
      {'title': 'Revise Chapter 2', 'course': 'SWE 343'},
    ];

    final allCards = <Widget>[
      ...completedTasks.map(
        (t) => _buildTaskCard(
          title: t['title']!,
          course: t['course']!,
          isCompleted: true,
          isRescheduled: false,
        ),
      ),
      ...pendingTasks.map(
        (t) => _buildTaskCard(
          title: t['title']!,
          course: t['course']!,
          isCompleted: false,
          isRescheduled: false,
        ),
      ),
      ...rescheduledTasks.map(
        (t) => _buildTaskCard(
          title: t['title']!,
          course: t['course']!,
          isCompleted: false,
          isRescheduled: true,
        ),
      ),
    ];

    const spacing = 16.0;
    const runSpacing = 16.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          alignment: WrapAlignment.start,
          children: allCards
              .map((card) => SizedBox(
                    width: cardWidth,
                    child: card,
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildTaskCard({
    required String title,
    required String course,
    required bool isCompleted,
    required bool isRescheduled,
  }) {
    const greenCheck = Color(0xFF52C41A);
    const greenBg = Color(0xFFE6F7E9);
    const greyButtonBg = Color(0xFFF5F5F5);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 14, isRescheduled ? 120 : 16, 14),
        decoration: BoxDecoration(
          color: isCompleted ? greenBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCompleted
                ? Colors.transparent
                : const Color(0xFFE8E8E8),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          course,
                          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: isCompleted ? greenCheck : greyButtonBg,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () {},
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
              if (isRescheduled) _buildRescheduledBanner(),
            ],
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          CustomSidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              const navNames = [
                'Dashboard',
                'Revision Plan',
                'Snaps Board',
                'Course Folder',
                'Brain Games',
                'Quiz',
                'Profile',
              ];
              if (index >= 0 && index < navNames.length) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(navNames[index]),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
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
    );
  }
}
