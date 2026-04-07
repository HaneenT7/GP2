import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'widgets/custom_sidebar.dart';
import 'pages/quiz_page.dart';
import 'services/pdf_text_extractor.dart';
import 'services/gemini_service.dart';
import 'pages/course_folders_page.dart';
import 'RevPlanPage.dart';
import 'pages/snaps_board_page.dart';
import 'pages/brain_games_page.dart';
import 'pages/profile_page.dart';

class DashBoard extends StatefulWidget {
  const DashBoard({super.key});

  @override
  State<StatefulWidget> createState() => _DashBoardState();
}

class _DashBoardState extends State<DashBoard> {
  int _selectedIndex = 0;
  int _selectedDayIndex = 3;
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
    return SingleChildScrollView(
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
                      .where((p) => _tryParseDate(p['examDate']) != null)
                      .toList()
                    ..sort((a, b) => _tryParseDate(a['examDate'])!
                        .compareTo(_tryParseDate(b['examDate'])!));

                  final upcoming = plans
                      .where((p) => !_tryParseDate(p['examDate'])!.isBefore(startToday))
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
                      final examDate = _tryParseDate(plan['examDate'])!;
                      final title =
                          '${(plan['folderName'] as String? ?? 'Course').toUpperCase()} EXAM';
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
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 12, 32, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
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
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                'select your file or drag and drop',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Text(
                'one pdf file accepted',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 16),
              Material(
                color: const Color(0xFFE9D5FF),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: _pickQuizFile,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text('browse'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _selectedQuizFileName!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: _pickQuizFile,
              icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey[600]),
              tooltip: 'Change file',
            ),
            IconButton(
              onPressed: () => setState(() {
                _selectedQuizFileName = null;
                _selectedQuizFileBytes = null;
              }),
              icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey[600]),
              tooltip: 'Remove file',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Material(
          color: const Color(0xFFE9D5FF),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: _isGeneratingQuiz ? null : _startQuizFromPdf,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _isGeneratingQuiz
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.purple.shade800,
                      ),
                    )
                  : Text(
                      'Start Your Quiz',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple.shade800,
                      ),
                    ),
            ),
          ),
        ),
      ],
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
            Text(
              _formatDate(_weekDays[_selectedDayIndex]['fullDate'] as DateTime),
              style: const TextStyle(
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _revisionPlansStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final selectedDate = _weekDays[_selectedDayIndex]['fullDate'] as DateTime;
        final plansForDate = (snapshot.data ?? []).where((plan) {
          final examDate = _tryParseDate(plan['examDate']);
          if (examDate == null) return false;
          final normalized = DateTime(examDate.year, examDate.month, examDate.day);
          return normalized == selectedDate;
        }).toList();

        if (plansForDate.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEAEAEA)),
            ),
            child: Text(
              'No tasks for ${_formatDate(selectedDate)}.',
              style: TextStyle(color: Colors.grey[700]),
            ),
          );
        }

        final allCards = plansForDate.map((plan) {
          final status = (plan['status'] as String? ?? 'pending').toLowerCase();
          final course = plan['folderName'] as String? ?? 'Course';
          return _buildTaskCard(
            title: 'Revision Plan',
            course: course,
            isCompleted: status == 'completed',
            isRescheduled: status == 'error',
          );
        }).toList();

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
                  .map((card) => SizedBox(width: cardWidth, child: card))
                  .toList(),
            );
          },
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
