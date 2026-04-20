import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'SetUpRevPlan.dart';
import 'pages/RevisionPlanCalendarPage.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'pages/availability_calendar_dialog.dart';
import 'package:gp2_watad/widgets/app_header.dart';

class RevPlanPage extends StatefulWidget {
  // Keeping the const constructor is VITAL for IndexedStack performance
  const RevPlanPage({super.key});

  @override
  State<RevPlanPage> createState() => _RevPlanPageState();
}

class _RevPlanPageState extends State<RevPlanPage> {
  bool _isSetupMode = false;

  @override
  Widget build(BuildContext context) {
    // We move the userId out of the build loop if possible, 
    // but here we ensure the UI tree is stable.
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isSetupMode
          ? SetUpRevPlan(onClose: () => setState(() => _isSetupMode = false))
          : Column(
              children: [
                const AppHeader(title: 'Revision plans'),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _ConfigureButton(), // Moved to const widget below
                      const SizedBox(width: 8),
                      _buildCreateButton(),
                    ],
                  ),
                ),
                Expanded(
                  child: user == null
                      ? const Center(child: Text('Please sign in'))
                      : RevisionPlansListStream(userId: user.uid),
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
        backgroundColor: const Color(0xFF4B3D8E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// --- ISOLATED CONFIGURE BUTTON ---
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

class RevisionPlansListStream extends StatelessWidget {
  final String userId;
  const RevisionPlansListStream({required this.userId, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Using a key here helps IndexedStack realize this stream is "Static"
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
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _EmptyState();
        }

        final now = DateTime.now();
        final allDocs = snapshot.data!.docs;

        // Use a single loop to filter for performance
        final activePlans = <QueryDocumentSnapshot>[];
        final passedPlans = <QueryDocumentSnapshot>[];

        for (var doc in allDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final raw = data['examDate'];
          final date = raw is Timestamp ? raw.toDate() : DateTime.parse(raw.toString());
          if (date.isAfter(now)) {
            activePlans.add(doc);
          } else {
            passedPlans.add(doc);
          }
        }

        return _PlansListContainer(activePlans: activePlans, passedPlans: passedPlans);
      },
    );
  }
}

class _PlansListContainer extends StatefulWidget {
  final List<QueryDocumentSnapshot> activePlans;
  final List<QueryDocumentSnapshot> passedPlans;

  const _PlansListContainer({required this.activePlans, required this.passedPlans});

  @override
  State<_PlansListContainer> createState() => _PlansListContainerState();
}

class _PlansListContainerState extends State<_PlansListContainer> {
  bool _passedExpanded = false;

  @override
  Widget build(BuildContext context) {
    // AutomaticKeepAliveClientMixin isn't strictly needed with IndexedStack, 
    // but the RepaintBoundary is.
    return RepaintBoundary(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...widget.activePlans.map((doc) => RevisionPlanCard(
                planId: doc.id,
                planData: doc.data() as Map<String, dynamic>,
              )),
          if (widget.passedPlans.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPassedHeader(),
            if (_passedExpanded)
              ...widget.passedPlans.map((doc) => Opacity(
                    opacity: 0.6,
                    child: RevisionPlanCard(
                      planId: doc.id,
                      planData: doc.data() as Map<String, dynamic>,
                    ),
                  )),
          ],
        ],
      ),
    );
  }

  Widget _buildPassedHeader() {
    return GestureDetector(
      onTap: () => setState(() => _passedExpanded = !_passedExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            const Icon(Icons.history, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Text('Passed plans (${widget.passedPlans.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
            const Spacer(),
            Icon(_passedExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class RevisionPlanCard extends StatelessWidget {
  final String planId;
  final Map<String, dynamic> planData;

  const RevisionPlanCard({required this.planId, required this.planData, super.key});

  @override
  Widget build(BuildContext context) {
    // Logic extracted to constants at start of build
    final folderName = planData['folderName'] ?? 'Study Material';
    final rawDate = planData['examDate'];
    final DateTime examDate = rawDate is Timestamp ? rawDate.toDate() : DateTime.parse(rawDate ?? DateTime.now().toString());
    final daysLeft = examDate.difference(DateTime.now()).inDays;

    int progress = 0;
    final rawTasks = planData['dailyTasks'];
    if (rawTasks != null) {
      try {
        final List dailyTasks = rawTasks is String ? jsonDecode(rawTasks) : (rawTasks as List);
        int total = 0;
        int completed = 0;
        for (var day in dailyTasks) {
          final tasks = day['tasks'] as List? ?? [];
          total += tasks.length;
          completed += tasks.where((t) => t['completed'] == true).length;
        }
        progress = total > 0 ? ((completed / total) * 100).round() : 0;
      } catch (_) {}
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RevisionPlanCalendarPage(planId: planId)),
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
                    Text(folderName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    _buildDateInfo(examDate, daysLeft),
                    const SizedBox(height: 10),
                    _buildProgressRow(progress),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.black12),
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
        color: const Color(0xFF4B3D8E).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.folder, color: Color(0xFF4B3D8E), size: 32),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
          child: Text('$left days left',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
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
        Text('$pct%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4B3D8E))),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No revision plans yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }
}