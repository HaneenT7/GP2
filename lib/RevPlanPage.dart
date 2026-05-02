import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'SetUpRevPlan.dart';
import 'pages/RevisionPlanCalendarPage.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'pages/availability_calendar_dialog.dart';
import 'package:gp2_watad/widgets/app_header.dart';
import 'package:gp2_watad/services/revision_plan_service.dart';

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
  final RevisionPlanService _revisionPlanService = RevisionPlanService(); // ADD THIS

  /// Non-null while a plan is being generated in the background.
  /// Holds the folder name so we can show it on the loading card.
  String? _generatingFolderName;

  /// Flip to true when generation completes — triggers success screen.
  bool _showSuccess = false;
  String _successFolderName = '';

  void _onPlanGenerated(String folderName, String requestId) {
    if (!mounted) return;
    setState(() {
      _generatingFolderName = null;
      _showSuccess = true;
      _successFolderName = folderName;
    });
  }
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // ── Success screen ──────────────────────
    if (_showSuccess) return _buildSuccessScreen();

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

            // Listen in background for n8n to finish
            _revisionPlanService.listenForPlan(
              requestId: requestId,
              onCompleted: (result) {
                if (!mounted) return;
                if (result.status == 'completed') {
                  setState(() => _generatingFolderName = null);
                  _showToast(folderName);
                } else {
                  setState(() => _generatingFolderName = null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        result.errorMessage ?? 'Something went wrong. Please try again.',
                      ),
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
      label: const Text('Create new Plan',
          style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _planPurple,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ─────────────────────────────────────────
  // SUCCESS SCREEN
  // ─────────────────────────────────────────

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: child,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEDE9FA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: _planPurple, size: 40),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Plan ready!',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your revision plan for $_successFolderName has been created with study sessions up to your exam date.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.6),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        setState(() => _showSuccess = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _planPurple,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('View my plan',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _showSuccess = false;
                      _isSetupMode = true;
                    }),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(
                          color: _planPurple, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Create another plan',
                        style: TextStyle(
                            color: _planPurple,
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          ),
        ),
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

  const RevisionPlansListStream({
    required this.userId,
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

        // Show empty state only when nothing is generating and no plans exist
        if (allDocs.isEmpty && generatingFolderName == null) {
          return const _EmptyState();
        }

        return _PlansListContainer(
          activePlans: activePlans,
          passedPlans: passedPlans,
          generatingFolderName: generatingFolderName,
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

  const _PlansListContainer({
    required this.activePlans,
    required this.passedPlans,
    this.generatingFolderName,
  });

  @override
  State<_PlansListContainer> createState() =>
      _PlansListContainerState();
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
          // Loading card at the top while generating
          if (widget.generatingFolderName != null) ...[
            _GeneratingPlanCard(
                folderName: widget.generatingFolderName!),
            const SizedBox(height: 8),
          ],

          // Active plans
          ...widget.activePlans.map((doc) => RevisionPlanCard(
                planId: doc.id,
                planData: doc.data() as Map<String, dynamic>,
              )),

          // Passed plans
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
              _passedExpanded
                  ? Icons.expand_less
                  : Icons.expand_more,
              color: Colors.grey,
            ),
          ],
        ),
      ),
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
  State<_GeneratingPlanCard> createState() =>
      _GeneratingPlanCardState();
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
    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5)
        .animate(_shimmerController);
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
                // Pulsing spinner icon
                _PulsingSpinner(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.folderName,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FA),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Generating…',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _planPurple),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Shimmer placeholder for date
                      AnimatedBuilder(
                        animation: _shimmerAnim,
                        builder: (context, child) =>
                            _shimmerBox(130, 13),
                      ),
                      const SizedBox(height: 10),
                      // Shimmer placeholder for progress bar
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
      builder: (context, _) {
        return Container(
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
        );
      },
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
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(
            parent: _pulseController, curve: Curves.easeInOut));
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
// Revision plan card (existing, unchanged)
// ─────────────────────────────────────────

class RevisionPlanCard extends StatelessWidget {
  final String planId;
  final Map<String, dynamic> planData;

  const RevisionPlanCard(
      {required this.planId, required this.planData, super.key});

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
        int total = 0;
        int completed = 0;
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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  RevisionPlanCalendarPage(planId: planId)),
        ),
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
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
            style:
                const TextStyle(fontSize: 14, color: Colors.grey)),
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

class _ToastNotification extends StatefulWidget {
  final String folderName;
  final VoidCallback onDismiss;

  const _ToastNotification({
    required this.folderName,
    required this.onDismiss,
  });

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
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Animate in
    _controller.forward();

    // Auto dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEDE9FA), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
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
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF423066),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Plan ready!',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.folderName} revision plan has been created.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () =>
                      _controller.reverse().then((_) => widget.onDismiss()),
                  child: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}