import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signIn.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  String? _firstName;
  String? _lastName;
  bool _loading = true;
  String? _error;

  // Stats
  List<int> _weeklyQuizzes = List.filled(7, 0);
  int _completedPlans = 0;
  double _successRate = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _loading = false;
          _error = 'Not signed in';
        });
        return;
      }
      _user = user;

      // Load profile
      final doc = await _firestore.collection('students').doc(user.uid).get();
      if (doc.exists) {
        final d = doc.data();
        _firstName = d?['firstName'] as String?;
        _lastName = d?['lastName'] as String?;
        _completedPlans = (d?['completedPlans'] as num?)?.toInt() ?? 0;
      }

      // Load quiz results
      await _loadQuizData(user.uid);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadQuizData(String uid) async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    final weekEnd = weekStart.add(const Duration(days: 7));

    // Weekly quizzes
    final weekSnap = await _firestore
        .collection('students')
        .doc(uid)
        .collection('quizResults')
        .where(
          'completedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart),
        )
        .where('completedAt', isLessThan: Timestamp.fromDate(weekEnd))
        .get();

    final quizzes = List.filled(7, 0);
    for (final doc in weekSnap.docs) {
      final date = (doc.data()['completedAt'] as Timestamp).toDate();
      final index = date.weekday - 1; // Mon=0 ... Sun=6
      quizzes[index]++;
    }
    _weeklyQuizzes = quizzes;

    // Overall success rate (all time)
    final allSnap = await _firestore
        .collection('students')
        .doc(uid)
        .collection('quizResults')
        .get();

    int totalCorrect = 0;
    int totalQuestions = 0;
    for (final doc in allSnap.docs) {
      final d = doc.data();
      totalCorrect += (d['correct'] as num?)?.toInt() ?? 0;
      totalQuestions += (d['total'] as num?)?.toInt() ?? 0;
    }
    _successRate = totalQuestions > 0
        ? (totalCorrect / totalQuestions) * 100
        : 0;
  }

  String get _displayName {
    if (_firstName != null || _lastName != null) {
      return '${_firstName ?? ''} ${_lastName ?? ''}'.trim();
    }
    return _user?.displayName ?? _user?.email?.split('@').first ?? 'User';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TextButton(onPressed: _loadUser, child: const Text('Retry')),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileHeader(),
                        const SizedBox(height: 24),
                        _buildWeeklyActivityCard(),
                        const SizedBox(height: 16),
                        _buildSummaryCards(),
                        const Spacer(),
                        _buildLogOutButton(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 44,
            backgroundColor: Color.fromARGB(172, 241, 207, 223),
            child: Icon(
              Icons.person,
              size: 44,
              color: Color.fromARGB(255, 223, 164, 192),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
                if (_user?.email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _user!.email!,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyActivityCard() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxQ = _weeklyQuizzes.reduce((a, b) => a > b ? a : b);
    final peakIndex = _weeklyQuizzes.indexOf(maxQ);
    const barColor = Color(0xFFE8E0F0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(7, (i) {
                final q = _weeklyQuizzes[i];
                final isHighlight = i == peakIndex && q > 0;
                final barH = maxQ > 0
                    ? ((q / maxQ) * 100).clamp(4.0, 100.0)
                    : 4.0;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isHighlight)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$q quiz',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Container(
                      width: 28,
                      height: barH,
                      decoration: BoxDecoration(
                        color: isHighlight ? const Color(0xFF7C4DFF) : barColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      days[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            color: const Color(0xFF7C4DFF),
            icon: Icons.assignment_outlined,
            label: 'Completed Plans',
            value: '$_completedPlans',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            color: const Color(0xFF2196F3),
            icon: Icons.rocket_launch_outlined,
            label: 'Quiz Success Rate',
            value: _successRate > 0
                ? '${_successRate.toStringAsFixed(0)}%'
                : 'No data yet',
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required Color color,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _logOut,
        icon: const Icon(Icons.logout, size: 20),
        label: const Text('Log out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF7C4DFF),
          side: const BorderSide(color: Color(0xFF7C4DFF)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _logOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => SignInPage()),
      (route) => false,
    );
  }
}
