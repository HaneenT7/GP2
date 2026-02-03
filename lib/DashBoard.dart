import 'package:flutter/material.dart';
import 'widgets/custom_sidebar.dart';
import 'pages/course_folders_page.dart';
import 'RevPlanPage.dart';

class DashBoard extends StatefulWidget {
  const DashBoard({super.key});

  @override
  State<StatefulWidget> createState() => _DashBoardState();
}

class _DashBoardState extends State<DashBoard> {
  int _selectedIndex = 0;
  int _selectedDayIndex = 3; // Thu Nov 27

  static const List<Map<String, String>> _weekDays = [
    {'label': 'Mon Nov 24', 'date': '24'},
    {'label': 'Tue Nov 25', 'date': '25'},
    {'label': 'Wed Nov 26', 'date': '26'},
    {'label': 'Thu Nov 27', 'date': '27'},
    {'label': 'Fri Nov 28', 'date': '28'},
    {'label': 'Sat Nov 29', 'date': '29'},
    {'label': 'Sun Nov 30*', 'date': '30'},
  ];

  Widget _getPageForIndex(int index) {
    switch (index) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return const RevPlanPage();
      case 2:
        return const Center(child: Text("Snaps Board Content"));
      case 3:
        return const CourseFoldersPage();
      case 4:
        return const Center(child: Text("Brain Games Content"));
      case 5:
        return const Center(child: Text("Quiz Content"));
      case 6:
        return const Center(child: Text("Profile Content"));
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
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
    return const Text(
      'Hello, Noura',
      style: TextStyle(
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
                  const Text(
                    'Upcoming Exams ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    '*',
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
          Text(date, style: TextStyle(fontSize: 14, color: Colors.grey[800])),
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
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 8, left: 8),
                  child: Text(
                    'Follow your plan, not your mood',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daily Tasks',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
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
                TextButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.refresh, size: 18, color: Colors.grey[700]),
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
        const SizedBox(height: 16),
        _buildDaysBar(),
        const SizedBox(height: 20),
        _buildTaskCards(),
      ],
    );
  }

  Widget _buildDaysBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_weekDays.length, (index) {
          final day = _weekDays[index];
          final isSelected = index == _selectedDayIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedDayIndex = index),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.grey[200] : Colors.white,
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
                  child: Text(
                    day['label']!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected ? Colors.black87 : Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
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

    const spacing = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: allCards
              .map((card) => SizedBox(width: cardWidth, child: card))
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
      padding: const EdgeInsets.only(bottom: 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, 14, isRescheduled ? 72 : 16, 14),
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
            child: Row(
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
                          color: isCompleted ? Colors.white : Colors.grey[800],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isRescheduled) _buildRescheduledBanner(),
        ],
      ),
    );
  }

  Widget _buildRescheduledBanner() {
    return Positioned(
      top: 8,
      right: 8,
      child: Transform.rotate(
        angle: 0.785398,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF38BDF8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 4,
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
