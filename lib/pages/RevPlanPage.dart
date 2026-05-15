import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'SetUpRevPlan.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'availability_calendar_dialog.dart';
import 'package:gp2_watad/widgets/app_header.dart';
import 'package:gp2_watad/services/revision_plan_service.dart';
import '../utils/revision_plan_overdue.dart';
import '../services/revision_plan_regenerate_client.dart';

const Color _planPurple = Color(0xFF4B3D8E);

// ─────────────────────────────────────────
// RevPlanPage
// ─────────────────────────────────────────

class RevPlanPage extends StatefulWidget {
  const RevPlanPage({super.key});

  @override
  State<RevPlanPage> createState() => _RevPlanPageState();
}

class _RevPlanPageState extends State<RevPlanPage> {
  bool _isSetupMode = false;
  final RevisionPlanService _revisionPlanService = RevisionPlanService();

  String? _generatingFolderName;

  // Inline detail state
  String? _selectedPlanId;
  Map<String, dynamic>? _selectedPlanData;

  OverlayEntry? _toastEntry;

  void _showToast(String folderName) {
    _toastEntry?.remove();
    _toastEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 24,
        right: 24,
        child: _ToastNotification(
          folderName: folderName,
          onDismiss: () {
            _toastEntry?.remove();
            _toastEntry = null;
          },
        ),
      ),
    );
    Overlay.of(context).insert(_toastEntry!);
  }

  void _openPlanDetail(String planId, Map<String, dynamic> planData) {
    setState(() {
      _selectedPlanId = planId;
      _selectedPlanData = planData;
    });
  }

  void _closePlanDetail() {
    setState(() {
      _selectedPlanId = null;
      _selectedPlanData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // ── Setup form ──────────────────────────
    if (_isSetupMode) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SetUpRevPlan(
          onClose: () => setState(() => _isSetupMode = false),
          onPlanGenerated: (folderName, requestId) {
            setState(() {
              _isSetupMode = false;
              _generatingFolderName = folderName;
            });
            _revisionPlanService.listenForPlan(
              requestId: requestId,
              onCompleted: (result) {
                if (!mounted) return;
                if (result.status == 'completed') {
                  _showToast(folderName);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() => _generatingFolderName = null);
            _showToast(folderName);
          }
        }); }else{
                  setState(() => _generatingFolderName = null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result.errorMessage ?? 'Something went wrong.'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              },
            );
          },
        ),
      );
    }

    // ── Inline plan detail ──────────────────
    if (_selectedPlanId != null) {
      return _InlinePlanDetailView(
        planId: _selectedPlanId!,
        onBack: _closePlanDetail,
      );
    }

    // ── Main list ───────────────────────────
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _ConfigureButton(),
                const SizedBox(width: 8),
                _buildCreateButton(),
              ],
            ),
          ),
          Expanded(
            child: user == null
                ? const Center(child: Text('Please sign in'))
                : RevisionPlansListStream(
                    userId: user.uid,
                    generatingFolderName: _generatingFolderName,
                    onPlanTapped: _openPlanDetail,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return ElevatedButton.icon(
      onPressed: () => setState(() => _isSetupMode = true),
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('Create new Plan', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _planPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─────────────────────────────────────────
// INLINE PLAN DETAIL VIEW
// ─────────────────────────────────────────

class _InlinePlanDetailView extends StatefulWidget {
  final String planId;
  final VoidCallback onBack;

  const _InlinePlanDetailView({required this.planId, required this.onBack});

  @override
  State<_InlinePlanDetailView> createState() => _InlinePlanDetailViewState();
}

class _InlinePlanDetailViewState extends State<_InlinePlanDetailView> {
  DateTime _currentWeekMonday = DateTime.now();
  List<DateTime> _weekDates = [];
  int _selectedDayIndex = 0;

  bool _regeneratingPlan = false;
  String _regenerateStatus = '';

  final RevisionPlanRegenerateClient _regenerateClient =
      RevisionPlanRegenerateClient();

  Stream<DocumentSnapshot>? _planStream;

  @override
  void initState() {
    super.initState();
    _initializeCalendar();

    _planStream = FirebaseFirestore.instance
        .collection('revisionPlans')
        .doc(widget.planId)
        .snapshots();
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
    _weekDates =
        List.generate(7, (i) => _currentWeekMonday.add(Duration(days: i)));
  }

  bool _isDateBeforeToday(DateTime date) {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final d = DateTime(date.year, date.month, date.day);
    return d.isBefore(today);
  }

  String _toDateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  Widget build(BuildContext context) {
    if (_planStream == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _planStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text('Plan not found')));
        }

        final planData = snapshot.data!.data() as Map<String, dynamic>;
        final rawTasks = planData['dailyTasks'];
        List<dynamic> dailyTasks = [];
        if (rawTasks is String) {
          try {
final List dailyTasks = rawTasks is String 
        ? jsonDecode(rawTasks) 
        : (rawTasks as List);
            } catch (e) {print("Error decoding tasks: $e");}
        } else if (rawTasks is List) {
          dailyTasks = rawTasks;
        }

        final selectedDate = _weekDates[_selectedDayIndex];
        final dateKey = _toDateKey(selectedDate);

        return Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(planData),
                        _buildInfoCard(planData, dailyTasks),
                        _buildActionToolbar(planData, dailyTasks),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('EEEE, MMMM d').format(selectedDate),
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600),
                              ),
                              _buildWeekNavButtons(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDaysBar(dailyTasks),
                        const SizedBox(height: 16),
                        _buildOverdueInfoBar(dailyTasks, dateKey),
                      ],
                    ),
                  ),
                  _buildTasksSliver(dailyTasks, dateKey, planData),
                ],
              ),
              if (_regeneratingPlan) ...[
                const Positioned.fill(
                  child: ModalBarrier(color: Colors.black26, dismissible: false),
                ),
                Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(_regenerateStatus),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(Map<String, dynamic> planData) {
    final folderName = planData['folderName'] ?? 'Revision Plan';
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 16,
        bottom: 8,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Text(
              folderName,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Info Card ────────────────────────────────────────────────────────────

  Widget _buildInfoCard(
      Map<String, dynamic> planData, List<dynamic> dailyTasks) {
    final rawDate = planData['examDate'];
    final DateTime examDate = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.parse(rawDate ?? DateTime.now().toString());
    final daysLeft = examDate.difference(DateTime.now()).inDays;

    int total = 0, completed = 0, overdue = 0;
    for (var day in dailyTasks) {
      final tasks = day['tasks'] as List<dynamic>? ?? [];
      final dayDate =
          DateTime.tryParse(day['date']?.toString() ?? '') ?? DateTime.now();
      total += tasks.length;
      for (var t in tasks) {
        if (t['completed'] == true) completed++;
        if (_isDateBeforeToday(dayDate) && t['completed'] != true) overdue++;
      }
    }
    final pct = total > 0 ? ((completed / total) * 100).round() : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE9FA), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Exam date
              const Icon(Icons.event, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                'Exam: ${DateFormat('MMM dd, yyyy').format(examDate)}',
                style:
                    const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: daysLeft <= 7
                      ? Colors.red.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$daysLeft days left',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: daysLeft <= 7
                        ? Colors.red.shade700
                        : Colors.blue,
                  ),
                ),
              ),
              if (overdue > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 12,
                          color: Colors.deepOrange.shade800),
                      const SizedBox(width: 4),
                      Text(
                        '$overdue overdue',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: Colors.grey.shade200,
                    color: _planPurple,
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$pct%',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _planPurple),
              ),
              const SizedBox(width: 4),
              Text(
                '$completed/$total tasks',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Action Toolbar ───────────────────────────────────────────────────────

  Widget _buildActionToolbar(Map<String, dynamic> planData, List<dynamic> dailyTasks) {
    final overdueCount = countOverdueTasks(dailyTasks);
    final folderName = planData['folderName'] ?? 'Revision Plan';

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Reschedule with AI
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _regeneratingPlan
                  ? null
                  : () => _openRegenerateOptions(planData, dailyTasks),
              icon: const Icon(Icons.auto_fix_high_outlined, size: 16),
              label: const Text('Reschedule AI',
                  style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _planPurple,
                side: const BorderSide(color: Color(0xFFD1C4E9)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _deletePlan(folderName),              
              icon: const Icon(Icons.delete_outline, size: 16),
              label:
                  const Text('Delete Plan', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
// ── delete Plan ─────────────────────────────────────────────────────
  Future<void> _deletePlan(String folderName) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Revision Plan?'),
        content: Text('Are you sure you want to delete "$folderName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete != true || !mounted) return;

    // 1. Capture the immediate Overlay state before changing the screen view state
    final OverlayState overlayState = Overlay.of(context);

    // 2. Pop back instantly to prevent the document stream deletion glitch
    widget.onBack();

    try {
      // 3. Remove the plan from Firebase asynchronously
      await FirebaseFirestore.instance
          .collection('revisionPlans')
          .doc(widget.planId)
          .delete();
      
      // 4. Trigger our responsive, custom-fading micro pill
      _showFadingPill(overlayState);

    } catch (e) {
      // Fallback safe logger if background threads get interrupted
      debugPrint("Error deleting document: $e");
    }
  }

  // ── Custom Fading Pill Animation Handler ──────────────────────────────
  void _showFadingPill(OverlayState overlayState) {
    late OverlayEntry entry;
    final ValueNotifier<double> opacityNotifier = ValueNotifier<double>(0.0);

    entry = OverlayEntry(
      builder: (BuildContext context) => Positioned(
        bottom: MediaQuery.of(context).size.height * 0.12, // Perfectly responsive lower third
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ValueListenableBuilder<double>(
              valueListenable: opacityNotifier,
              builder: (BuildContext context, double opacityValue, Widget? child) {
                return AnimatedOpacity(
                  opacity: opacityValue,
                  duration: const Duration(milliseconds: 300), // Clean fade transition
                  curve: Curves.easeInOut,
                  child: child,
                );
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), // Small compact size
                  decoration: BoxDecoration(
                    color: Colors.white, // Pure white base
                    borderRadius: BorderRadius.circular(100), // Sleek pill styling
                    border: Border.all(color: const Color(0xFFEDE9FA), width: 1.5), // Soft lavender outline
                    boxShadow: [
                      BoxShadow(
                        color: _planPurple.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min, // Hugs the elements tightly
                    children: [
                      Icon(Icons.delete_outline, color: _planPurple, size: 15), // Smaller custom colored icon
                      SizedBox(width: 6),
                      Text(
                        'Plan deleted',
                        style: TextStyle(
                          color: _planPurple, // Pure purple typography text
                          fontWeight: FontWeight.w600,
                          fontSize: 13, // Minimal text footprint
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Safely insert into the view hierarchy tree
    overlayState.insert(entry);
    
    // Smoothly kick off the fade-in animation loop
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (opacityNotifier.hashCode != 0) {
        opacityNotifier.value = 1.0;
      }
    });

    // Handle automated fade-out step and memory disposal window 
    Future.delayed(const Duration(milliseconds: 1800), () {
      opacityNotifier.value = 0.0;
      Future.delayed(const Duration(milliseconds: 300), () {
        entry.remove();
        opacityNotifier.dispose();
      });
    });
  }
  // ── Week nav buttons ─────────────────────────────────────────────────────

  Widget _buildWeekNavButtons() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              _currentWeekMonday =
                  _currentWeekMonday.subtract(const Duration(days: 7));
              _generateWeekDates();
              _selectedDayIndex = 0;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() {
              _currentWeekMonday =
                  _currentWeekMonday.add(const Duration(days: 7));
              _generateWeekDates();
              _selectedDayIndex = 0;
            });
          },
        ),
      ],
    );
  }

  // ── Days bar — matches DailyTasksSection style exactly ───────────────────

  Widget _buildDaysBar(List<dynamic> dailyTasks) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: List.generate(_weekDates.length, (index) {
        final date = _weekDates[index];
        final isSelected = index == _selectedDayIndex;
        final dateKey = _toDateKey(date);

        // Count tasks for dot indicator
        dynamic dayData;
        for (final day in dailyTasks) {
          if (day['date']?.toString().startsWith(dateKey) == true) {
            dayData = day;
            break;
          }
        }
        final tasks = dayData?['tasks'] as List<dynamic>? ?? [];
        final hasOverdue = _isDateBeforeToday(date) &&
            tasks.any((t) => t['completed'] != true);
        final hasTasks = tasks.isNotEmpty;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => setState(() => _selectedDayIndex = index),
              child: Stack(
                alignment: Alignment.topCenter, // Ensures dots stay at top
                children: [
                  Container(
                    // width: double.infinity makes the pill take all space provided by Expanded
                    width: double.infinity, 
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(date),
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF7C3AED)
                                : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4), // Added a tiny bit of breathing room
                        Text(
                          DateFormat('d').format(date),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dot indicator positioned relative to the expanded container
                  if (hasTasks)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: hasOverdue
                              ? Colors.deepOrange
                              : const Color(0xFF9333EA),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    ),
  );
}
  // ── Overdue info bar ─────────────────────────────────────────────────────

  Widget _buildOverdueInfoBar(List<dynamic> dailyTasks, String dateKey) {
    int overdueOnSelectedDay = 0;
    int totalOverdue = 0;

    for (final day in dailyTasks) {
      final dayDateKey = day['date']?.toString();
      if (dayDateKey == null) continue;
      final dayDate = DateTime.tryParse(dayDateKey);
      if (dayDate == null || !_isDateBeforeToday(dayDate)) continue;
      final tasks = day['tasks'] as List<dynamic>? ?? [];
      for (final task in tasks) {
        if (task['completed'] != true) {
          totalOverdue++;
          if (dayDateKey.startsWith(dateKey)) overdueOnSelectedDay++;
        }
      }
    }

    if (totalOverdue == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tasks sliver ─────────────────────────────────────────────────────────

  Widget _buildTasksSliver(
    List<dynamic> dailyTasks,
    String dateKey,
    Map<String, dynamic> planData,
  ) {
    // Find day data
    dynamic dayData;
    for (final day in dailyTasks) {
      if (day['date']?.toString().startsWith(dateKey) == true) {
        dayData = day;
        break;
      }
    }

    final tasks = dayData?['tasks'] as List<dynamic>? ?? [];

    if (tasks.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.free_breakfast,
                  size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                dayData == null
                    ? 'No tasks scheduled for this day'
                    : 'Rest day — no study time',
                style: TextStyle(
                    fontSize: 15, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    final selectedDate = _weekDates[_selectedDayIndex];

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final task = tasks[index] as Map<dynamic, dynamic>;
            final isCompleted = task['completed'] == true;
            final isOverdue = _isDateBeforeToday(selectedDate) &&
                !isCompleted;
            final isRescheduled = task['rescheduled'] == true;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TaskCard(
                task: task,
                taskIndex: index,
                isCompleted: isCompleted,
                isOverdue: isOverdue,
                isRescheduled: isRescheduled,
                planId: widget.planId,
                selectedDate: selectedDate,
                dailyTasks: dailyTasks,
                planData: planData,
                onMoved: (toDate) {
                  // Jump calendar to target date if in same week
                  final newKey = _toDateKey(toDate);
                  for (var i = 0; i < _weekDates.length; i++) {
                    if (_toDateKey(_weekDates[i]) == newKey) {
                      setState(() => _selectedDayIndex = i);
                      return;
                    }
                  }
                },
              ),
            );
          },
          childCount: tasks.length,
        ),
      ),
    );
  }

  // ── Regenerate helpers ───────────────────────────────────────────────────

  Future<void> _openRegenerateOptions(
      Map<String, dynamic> planData, List<dynamic> dailyTasks) async {
    final overdueCount = countOverdueTasks(dailyTasks);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Regenerate with AI',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose what to rebuild. Completed tasks stay unchanged.',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.event_busy,
                    color: Colors.deepOrange.shade800),
                title: const Text('Reschedule overdue tasks only'),
                subtitle: Text(
                  overdueCount > 0
                      ? 'Moves incomplete past tasks into upcoming days.'
                      : 'No overdue tasks right now.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                enabled: overdueCount > 0,
                onTap: overdueCount == 0
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _rescheduleOverdue(planData, dailyTasks);
                      },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month,
                    color: _planPurple),
                title: const Text('Regenerate full plan'),
                subtitle: Text(
                  'Rebuilds all incomplete work to fit availability and exam date.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmRegenerateFullPlan(planData);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRegenerateFullPlan(
      Map<String, dynamic> planData) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate full plan?'),
        content: const Text(
          'All incomplete tasks will be rescheduled from scratch while keeping completed tasks.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Regenerate')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runRegenerate(
      status: 'Regenerating full plan…',
      action: () => _regenerateClient.regenerateFullPlan(
          planId: widget.planId, planData: planData),
      successMessage: 'Full plan updated.',
    );
  }

  Future<void> _rescheduleOverdue(
      Map<String, dynamic> planData, List<dynamic> dailyTasks) async {
    await _runRegenerate(
      status: 'Rescheduling overdue tasks…',
      action: () => _regenerateClient.rescheduleOverdueTasks(
          planId: widget.planId, planData: planData),
      successMessage: 'Overdue tasks rescheduled.',
    );
  }

  Future<void> _runRegenerate({
    required String status,
    required Future<RevisionPlanResult> Function() action,
    required String successMessage,
  }) async {
    setState(() {
      _regeneratingPlan = true;
      _regenerateStatus = status;
    });
    try {
      final result = await action();
      if (!mounted) return;
      if (result.status == 'completed') {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMessage)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.errorMessage ?? 'Regeneration failed'),
          backgroundColor: Colors.red.shade700,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')),
        backgroundColor: Colors.red.shade700,
      ));
    } finally {
      if (mounted) {
        setState(() {
          _regeneratingPlan = false;
          _regenerateStatus = '';
        });
      }
    }
  }
}

// ─────────────────────────────────────────
// Task Card widget
// ─────────────────────────────────────────
 
class _TaskCard extends StatelessWidget {
  final Map<dynamic, dynamic> task;
  final int taskIndex;
  final bool isCompleted;
  final bool isOverdue;
  final bool isRescheduled;
  final String planId;
  final DateTime selectedDate;
  final List<dynamic> dailyTasks;
  final Map<String, dynamic> planData;
  final void Function(DateTime toDate) onMoved;
 
  const _TaskCard({
    required this.task,
    required this.taskIndex,
    required this.isCompleted,
    required this.isOverdue,
    required this.isRescheduled,
    required this.planId,
    required this.selectedDate,
    required this.dailyTasks,
    required this.planData,
    required this.onMoved,
  });
 
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
 
  String _toIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
 
  Future<void> _toggleCompletion(BuildContext context) async {
    try {
      final planRef = FirebaseFirestore.instance
          .collection('revisionPlans')
          .doc(planId);
      final snap = await planRef.get();
      if (!snap.exists) return;
      final data = snap.data()!;
      final raw = data['dailyTasks'];
      final wasString = raw is String;
      List<dynamic> tasks =
          wasString ? jsonDecode(raw) : List<dynamic>.from(raw ?? []);
 
      for (var i = 0; i < tasks.length; i++) {
        final day = tasks[i];
        final dayDate = DateTime.tryParse(day['date']?.toString() ?? '');
        if (dayDate != null && _isSameDay(dayDate, selectedDate)) {
          final dayTasks = List<dynamic>.from(day['tasks']);
          if (taskIndex < dayTasks.length) {
            dayTasks[taskIndex]['completed'] = !isCompleted;
            tasks[i]['tasks'] = dayTasks;
            break;
          }
        }
      }
 
      await planRef.update({
        'dailyTasks': wasString ? jsonEncode(tasks) : tasks,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update task: $e')));
    }
  }
 
  Future<void> _pickAndMove(BuildContext context) async {
    final targetDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: 'Move task to date',
    );
    if (targetDate == null) return;
    if (_isSameDay(targetDate, selectedDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task is already on this date.')));
      return;
    }
 
    final planRef = FirebaseFirestore.instance
        .collection('revisionPlans')
        .doc(planId);
    final snap = await planRef.get();
    if (!snap.exists) return;
    final data = snap.data()!;
    final raw = data['dailyTasks'];
    final wasString = raw is String;
    List<dynamic> allDays =
        wasString ? jsonDecode(raw) : List<dynamic>.from(raw ?? []);
 
    // Remove from source day
    int srcIdx = -1;
    for (var i = 0; i < allDays.length; i++) {
      final d = DateTime.tryParse(allDays[i]['date']?.toString() ?? '');
      if (d != null && _isSameDay(d, selectedDate)) {
        srcIdx = i;
        break;
      }
    }
    if (srcIdx == -1) return;
    final srcDay = Map<String, dynamic>.from(allDays[srcIdx]);
    final srcTasks = List<dynamic>.from(srcDay['tasks'] ?? []);
    if (taskIndex >= srcTasks.length) return;
    final movedTask =
        Map<String, dynamic>.from(srcTasks.removeAt(taskIndex));
    srcDay['tasks'] = srcTasks;
    allDays[srcIdx] = srcDay;
 
    // Add to target day
    int tgtIdx = -1;
    for (var i = 0; i < allDays.length; i++) {
      final d = DateTime.tryParse(allDays[i]['date']?.toString() ?? '');
      if (d != null && _isSameDay(d, targetDate)) {
        tgtIdx = i;
        break;
      }
    }
    if (tgtIdx == -1) {
      allDays.add({
        'date': _toIsoDate(targetDate),
        'day': DateFormat('EEEE').format(targetDate),
        'availableMinutes': 0,
        'tasks': [movedTask],
      });
    } else {
      final tgtDay = Map<String, dynamic>.from(allDays[tgtIdx]);
      final tgtTasks = List<dynamic>.from(tgtDay['tasks'] ?? []);
      tgtTasks.add(movedTask);
      tgtDay['tasks'] = tgtTasks;
      allDays[tgtIdx] = tgtDay;
    }
 
    allDays.sort((a, b) {
      final ad = DateTime.tryParse(
          (a as Map<dynamic, dynamic>)['date']?.toString() ?? '');
      final bd = DateTime.tryParse(
          (b as Map<dynamic, dynamic>)['date']?.toString() ?? '');
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
 
    await planRef.update({
      'dailyTasks': wasString ? jsonEncode(allDays) : allDays,
    });
 
    onMoved(targetDate);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Moved to ${DateFormat('MMM d').format(targetDate)}.'),
    ));
  }
 
  @override
  Widget build(BuildContext context) {
    final title = task['title']?.toString() ?? '';
    final course = task['course']?.toString() ?? '';
    final fileName = task['fileName']?.toString() ?? '';
    final pages = task['pages']?.toString() ?? '';
 
    const greenCheck = Color(0xFF52C41A);
    const greenBg = Color(0xFFE6F7E9);
 
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: isCompleted ? greenBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? Colors.transparent
              : isOverdue
                  ? Colors.deepOrange.shade300
                  : isRescheduled
                      ? Colors.indigo.shade200
                      : const Color(0xFFE8E8E8),
          width: (isOverdue || isRescheduled) && !isCompleted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox
          GestureDetector(
            onTap: () => _toggleCompletion(context),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color:
                        isCompleted ? greenCheck : Colors.black87,
                    width: isCompleted ? 2 : 1,
                  ),
                ),
                child: isCompleted
                    ? const Center(
                        child: Icon(Icons.check,
                            size: 16, color: greenCheck),
                      )
                    : null,
              ),
            ),
          ),
 
          const SizedBox(width: 14),
 
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isCompleted
                              ? Colors.grey
                              : isOverdue
                                  ? Colors.deepOrange.shade900
                                  : isRescheduled
                                      ? Colors.indigo.shade700
                                      : Colors.black87,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    // Status badges
                    if (isOverdue && !isCompleted) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Overdue',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.deepOrange.shade900)),
                      ),
                    ],
                    if (isRescheduled && !isCompleted) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Rescheduled',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.indigo.shade700)),
                      ),
                    ],
                  ],
                ),
 
                const SizedBox(height: 4),
 
                // Course / file name
                Text(
                  [course, if (fileName.isNotEmpty) fileName]
                      .where((s) => s.isNotEmpty)
                      .join(' • '),
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
 
                const SizedBox(height: 6),
 
                // Pages + Move button row
                Row(
                  children: [
                    if (pages.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'pp. $pages',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    // Move task button
                    InkWell(
                      onTap: () => _pickAndMove(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.drive_file_move_outline,
                                size: 14,
                                color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Move',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Take Quiz button
                    Material(
                      color: isCompleted
                          ? const Color(0xFF52C41A)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () {
                          // TODO: connect quiz page
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: Text(
                            'Take Quiz',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isCompleted
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Configure button
// ─────────────────────────────────────────

class _ConfigureButton extends StatelessWidget {
  const _ConfigureButton();

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => showDialog(
        context: context,
        builder: (context) => AvailabilityCalendarDialog(),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF9333EA),
        side: const BorderSide(color: Color(0xFFE9D5FF), width: 2),
        backgroundColor: const Color(0xFFFAF5FF),
      ),
      icon: const Icon(Icons.calendar_today, size: 18),
      label: const Text('Configure Availability'),
    );
  }
}

// ─────────────────────────────────────────
// Plans list stream
// ─────────────────────────────────────────

class RevisionPlansListStream extends StatelessWidget {
  final String userId;
  final String? generatingFolderName;
  final void Function(String planId, Map<String, dynamic> planData) onPlanTapped;

  const RevisionPlansListStream({
    required this.userId,
    required this.onPlanTapped,
    this.generatingFolderName,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey('rev_plan_stream_$userId'),
      stream: FirebaseFirestore.instance
          .collection('revisionPlans')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final now = DateTime.now();
        final allDocs = snapshot.data?.docs ?? [];
        final activePlans = <QueryDocumentSnapshot>[];
        final passedPlans = <QueryDocumentSnapshot>[];

        for (var doc in allDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final raw = data['examDate'];
          final date = raw is Timestamp
              ? raw.toDate()
              : DateTime.parse(raw.toString());
          if (date.isAfter(now)) {
            activePlans.add(doc);
          } else {
            passedPlans.add(doc);
          }
        }

        if (allDocs.isEmpty && generatingFolderName == null) {
          return const _EmptyState();
        }

        return _PlansListContainer(
          activePlans: activePlans,
          passedPlans: passedPlans,
          generatingFolderName: generatingFolderName,
          onPlanTapped: onPlanTapped,
        );
      },
    );
  }
}

// ─────────────────────────────────────────
// Plans list container
// ─────────────────────────────────────────

class _PlansListContainer extends StatefulWidget {
  final List<QueryDocumentSnapshot> activePlans;
  final List<QueryDocumentSnapshot> passedPlans;
  final String? generatingFolderName;
  final void Function(String planId, Map<String, dynamic> planData) onPlanTapped;

  const _PlansListContainer({
    required this.activePlans,
    required this.passedPlans,
    required this.onPlanTapped,
    this.generatingFolderName,
  });

  @override
  State<_PlansListContainer> createState() => _PlansListContainerState();
}

class _PlansListContainerState extends State<_PlansListContainer> {
  bool _passedExpanded = false;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (widget.generatingFolderName != null) ...[
            _GeneratingPlanCard(folderName: widget.generatingFolderName!),
            const SizedBox(height: 8),
          ],
          ...widget.activePlans.map((doc) => RevisionPlanCard(
                planId: doc.id,
                planData: doc.data() as Map<String, dynamic>,
                onTap: widget.onPlanTapped,
              )),
          if (widget.passedPlans.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildPassedHeader(),
            if (_passedExpanded) ...[
              const SizedBox(height: 16),
              ...widget.passedPlans.map((doc) => Opacity(
                    opacity: 0.6,
                    child: RevisionPlanCard(
                      planId: doc.id,
                      planData: doc.data() as Map<String, dynamic>,
                      onTap: widget.onPlanTapped,
                    ),
                  )),
            ],
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  Widget _buildPassedHeader() {
    return InkWell(
      onTap: () =>
          setState(() => _passedExpanded = !_passedExpanded),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.history, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              'Passed plans (${widget.passedPlans.length})',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey),
            ),
            const Spacer(),
            Icon(
              _passedExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Revision plan card  (now calls onTap instead of Navigator.push)
// ─────────────────────────────────────────

class RevisionPlanCard extends StatelessWidget {
  final String planId;
  final Map<String, dynamic> planData;
  final void Function(String planId, Map<String, dynamic> planData) onTap;

  const RevisionPlanCard({
    required this.planId,
    required this.planData,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final folderName = planData['folderName'] ?? 'Study Material';
    final rawDate = planData['examDate'];
    final DateTime examDate = rawDate is Timestamp
        ? rawDate.toDate()
        : DateTime.parse(rawDate ?? DateTime.now().toString());
    final daysLeft = examDate.difference(DateTime.now()).inDays;

    int progress = 0;
    final rawTasks = planData['dailyTasks'];
    if (rawTasks != null) {
      try {
        final List dailyTasks = rawTasks is String
            ? jsonDecode(rawTasks)
            : (rawTasks as List);
        int total = 0, completed = 0;
        for (var day in dailyTasks) {
          final tasks = day['tasks'] as List? ?? [];
          total += tasks.length;
          completed +=
              tasks.where((t) => t['completed'] == true).length;
        }
        progress =
            total > 0 ? ((completed / total) * 100).round() : 0;
      } catch (_) {}
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(planId, planData),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(folderName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    _buildDateInfo(examDate, daysLeft),
                    const SizedBox(height: 10),
                    _buildProgressRow(progress),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 20, color: Colors.black12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _planPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.folder, color: _planPurple, size: 32),
    );
  }

  Widget _buildDateInfo(DateTime date, int left) {
    return Row(
      children: [
        const Icon(Icons.event, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Text('Exam: ${DateFormat('MMM dd, yyyy').format(date)}',
            style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(width: 12),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12)),
          child: Text('$left days left',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue)),
        ),
      ],
    );
  }

  Widget _buildProgressRow(int pct) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: Colors.grey.shade100,
              color: const Color.fromARGB(255, 208, 173, 218),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text('$pct%',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _planPurple)),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Generating plan card (shimmer loading)
// ─────────────────────────────────────────

class _GeneratingPlanCard extends StatefulWidget {
  final String folderName;
  const _GeneratingPlanCard({required this.folderName});

  @override
  State<_GeneratingPlanCard> createState() => _GeneratingPlanCardState();
}

class _GeneratingPlanCardState extends State<_GeneratingPlanCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmerAnim =
        Tween<double>(begin: -1.5, end: 1.5).animate(_shimmerController);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFEDE9FA), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PulsingSpinner(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(widget.folderName,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FA),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Generating…',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _planPurple)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AnimatedBuilder(
                        animation: _shimmerAnim,
                        builder: (context, child) => _shimmerBox(130, 13),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedBuilder(
                              animation: _shimmerAnim,
                              builder: (context, child) =>
                                  _shimmerBox(double.infinity, 8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('—%',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB0A0D8))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFFF0EEFA), height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.schedule,
                    size: 14, color: Color(0xFF9585C8)),
                const SizedBox(width: 6),
                Text(
                  'Building your study schedule — this may take a moment',
                  style: TextStyle(
                      fontSize: 12, color: Colors.purple.shade300),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox(double width, double height) {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, _) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: LinearGradient(
            begin: Alignment(_shimmerAnim.value - 1, 0),
            end: Alignment(_shimmerAnim.value + 1, 0),
            colors: const [
              Color(0xFFF0EEF8),
              Color(0xFFE0D8F0),
              Color(0xFFF0EEF8),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingSpinner extends StatefulWidget {
  @override
  State<_PulsingSpinner> createState() => _PulsingSpinnerState();
}

class _PulsingSpinnerState extends State<_PulsingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) => Opacity(
        opacity: _pulseAnim.value,
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: Color(0xFFEDE9FA),
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: CircularProgressIndicator(
              color: _planPurple,
              strokeWidth: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No revision plans yet',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Toast notification
// ─────────────────────────────────────────

class _ToastNotification extends StatefulWidget {
  final String folderName;
  final VoidCallback onDismiss;

  const _ToastNotification(
      {required this.folderName, required this.onDismiss});

  @override
  State<_ToastNotification> createState() => _ToastNotificationState();
}

class _ToastNotificationState extends State<_ToastNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _opacity =
        CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0.3, 0), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted)
        _controller.reverse().then((_) => widget.onDismiss());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _opacity,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFEDE9FA), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                      color: Color(0xFFEDE9FA),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded,
                      color: Color(0xFF423066), size: 20),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Plan ready!',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.black87)),
                      const SizedBox(height: 2),
                      Text(
                          '${widget.folderName} revision plan has been created.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600])),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _controller
                      .reverse()
                      .then((_) => widget.onDismiss()),
                  child: Icon(Icons.close,
                      size: 16, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}