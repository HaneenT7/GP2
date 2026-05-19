import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:health/health.dart' show HealthConnectSdkStatus;
import 'package:gp2_watad/services/health_connect_service.dart';
import 'package:gp2_watad/services/heart_rate_alert_service.dart';
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

  final HealthConnectService _healthConnectService = HealthConnectService();
  bool _healthBusy = false;
  bool _vitalsRefreshing = false;
  bool _healthFetchInProgress = false;
  String? _healthStatus;
  List<HeartRateReading> _heartRateReadings = [];
  List<BloodPressureReading> _bloodPressureReadings = [];
  HeartRateReading? _vitalsHeartRate;
  BloodPressureReading? _vitalsBloodPressure;
  String? _vitalsRefreshError;

  @override
  void initState() {
    super.initState();
    _loadUser();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshVitals());
    }
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
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 24),
                  _buildWeeklyActivityCard(),
                  const SizedBox(height: 16),
                  _buildSummaryCards(),
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 16),
                    _buildHealthConnectCard(),
                  ],
                  const SizedBox(height: 24),
                  _buildLogOutButton(),
                  const SizedBox(height: 16),
                ],
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
              color: Color(0xFFDFA4C0),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackCards = constraints.maxWidth < 520;

        final completedPlansCard = _buildSummaryCard(
          color: const Color(0xFF7C4DFF),
          icon: Icons.assignment_outlined,
          label: 'Completed Plans',
          value: '$_completedPlans',
        );
        final successRateCard = _buildSummaryCard(
          color: const Color(0xFF2196F3),
          icon: Icons.rocket_launch_outlined,
          label: 'Quiz Success Rate',
          value: _successRate > 0
              ? '${_successRate.toStringAsFixed(0)}%'
              : 'No data yet',
        );

        if (stackCards) {
          return Column(
            children: [
              completedPlansCard,
              const SizedBox(height: 16),
              successRateCard,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: completedPlansCard),
            const SizedBox(width: 16),
            Expanded(child: successRateCard),
          ],
        );
      },
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

  Widget _buildHealthConnectCard() {
    return Container(
      width: double.infinity,
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
            'Health Connect',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'WATAD reads heart rate and blood pressure from Health Connect (including data shared by Samsung Health or Google Fit). '
            'If your fitness app has data but WATAD does not, enable sharing in Health Connect → App permissions for that app.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          if (_healthStatus != null) ...[
            const SizedBox(height: 12),
            Text(
              _healthStatus!,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
          ],
          const SizedBox(height: 16),
          _buildGoogleFitStatsPanel(),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackButtons = constraints.maxWidth < 520;
              final grantAccessButton = FilledButton.icon(
                onPressed: _healthBusy ? null : _connectHealthConnect,
                icon: const Icon(Icons.link),
                label: const Text('Grant access'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C4DFF),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              );
              final loadHealthDataButton = OutlinedButton.icon(
                onPressed: _healthBusy ? null : _loadHealthData,
                icon: const Icon(Icons.monitor_heart_outlined),
                label: const Text('Load health data'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C4DFF),
                  side: const BorderSide(color: Color(0xFF7C4DFF)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              );
              final openSettingsButton = OutlinedButton.icon(
                onPressed: _healthBusy ? null : _openHealthConnectSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open Health Connect'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C4DFF),
                  side: const BorderSide(color: Color(0xFF7C4DFF)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              );
              final openSamsungHealthButton = OutlinedButton.icon(
                onPressed: _healthBusy ? null : _openSamsungHealth,
                icon: const Icon(Icons.health_and_safety_outlined),
                label: const Text('Open Samsung Health'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C4DFF),
                  side: const BorderSide(color: Color(0xFF7C4DFF)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              );
              final openGoogleFitButton = OutlinedButton.icon(
                onPressed: _healthBusy ? null : _openGoogleFit,
                icon: const Icon(Icons.directions_run_outlined),
                label: const Text('Open Google Fit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C4DFF),
                  side: const BorderSide(color: Color(0xFF7C4DFF)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              );
              if (stackButtons) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    grantAccessButton,
                    const SizedBox(height: 12),
                    loadHealthDataButton,
                    const SizedBox(height: 12),
                    openSettingsButton,
                    const SizedBox(height: 12),
                    openSamsungHealthButton,
                    const SizedBox(height: 12),
                    openGoogleFitButton,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: grantAccessButton),
                      const SizedBox(width: 12),
                      Expanded(child: loadHealthDataButton),
                    ],
                  ),
                  const SizedBox(height: 12),
                  openSettingsButton,
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: openSamsungHealthButton),
                      const SizedBox(width: 12),
                      Expanded(child: openGoogleFitButton),
                    ],
                  ),
                ],
              );
            },
          ),
          if (_healthBusy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_heartRateReadings.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Heart rate',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 8),
            ..._heartRateReadings.take(10).map(_buildHeartRateRow),
          ],
          if (_bloodPressureReadings.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Blood pressure',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 8),
            ..._bloodPressureReadings.take(10).map(_buildBloodPressureRow),
          ],
        ],
      ),
    );
  }

  Widget _buildBloodPressureRow(BloodPressureReading reading) {
    final time =
        MaterialLocalizations.of(context).formatFullDate(reading.recordedAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bloodtype, color: Color(0xFF7C4DFF), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _healthConnectService.formatBloodPressure(reading),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                time,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _healthConnectService.formatSourceLabel(reading.source),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartRateRow(HeartRateReading reading) {
    final time = MaterialLocalizations.of(context).formatFullDate(reading.recordedAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: Color(0xFFE91E63), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _healthConnectService.formatHeartRate(reading),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                time,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${reading.type} • ${_healthConnectService.formatSourceLabel(reading.source)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Future<void> _connectHealthConnect() async {
    setState(() {
      _healthBusy = true;
      _healthStatus = null;
    });

    try {
      final status = await _healthConnectService.getSdkStatus();
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        await _healthConnectService.openHealthConnectInstall();
        setState(() {
          _healthStatus =
              'Install or update Health Connect, then tap Grant access again.';
        });
        return;
      }

      final granted = await _healthConnectService.requestHealthAccess();
      setState(() {
        _healthStatus = granted
            ? 'Health Connect read access is enabled for WATAD (heart rate & blood pressure).'
            : 'Permission was not granted. Open Health Connect and allow heart rate and blood pressure for WATAD.';
      });
      if (granted) {
        await _loadHealthData();
      }
    } catch (e) {
      setState(() {
        _healthStatus = 'Could not connect to Health Connect: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _healthBusy = false);
      }
    }
  }

  Future<void> _refreshVitals() async {
    if (_healthFetchInProgress) return;
    _healthFetchInProgress = true;

    setState(() {
      _vitalsRefreshing = true;
      _vitalsRefreshError = null;
    });

    try {
      final snapshot = await _healthConnectService.fetchLatestVitals(
        lookback: const Duration(hours: 48),
      );

      if (!mounted) return;

      setState(() {
        _vitalsHeartRate = snapshot.heartRate;
        _vitalsBloodPressure = snapshot.bloodPressure;
        if (snapshot.recentHeartRates.isNotEmpty) {
          _heartRateReadings = snapshot.recentHeartRates;
        }
        if (snapshot.recentBloodPressures.isNotEmpty) {
          _bloodPressureReadings = snapshot.recentBloodPressures;
        }
        _vitalsRefreshError = snapshot.errorMessage;
      });

      if (snapshot.recentHeartRates.isNotEmpty) {
        _checkHeartRateAlert(snapshot.recentHeartRates);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _vitalsRefreshError = 'Could not refresh vitals: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _healthFetchInProgress = false;
          _vitalsRefreshing = false;
        });
      }
    }
  }

  Future<void> _loadHealthData() => _fetchHealthData(
        lookback: const Duration(days: 365),
        fromVitalsPanel: false,
      );

  Future<void> _fetchHealthData({
    required Duration lookback,
    required bool fromVitalsPanel,
  }) async {
    if (_healthFetchInProgress) return;
    _healthFetchInProgress = true;

    setState(() {
      if (fromVitalsPanel) {
        _vitalsRefreshing = true;
      } else {
        _healthBusy = true;
        _healthStatus = null;
      }
    });

    try {
      final results = await Future.wait([
        _healthConnectService.fetchHeartRate(lookback: lookback),
        _healthConnectService.fetchBloodPressure(lookback: lookback),
      ]);
      final hrResult = results[0] as HealthHeartRateFetchResult;
      final bpResult = results[1] as HealthBloodPressureFetchResult;

      if (!mounted) return;

      setState(() {
        _heartRateReadings = hrResult.readings;
        _bloodPressureReadings = bpResult.readings;
        _vitalsHeartRate =
            hrResult.readings.isNotEmpty ? hrResult.readings.first : null;
        _vitalsBloodPressure =
            bpResult.readings.isNotEmpty ? bpResult.readings.first : null;
        if (!fromVitalsPanel) {
          _healthStatus = '${hrResult.statusMessage} ${bpResult.statusMessage}';
        }
      });

      _checkHeartRateAlert(hrResult.readings);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!fromVitalsPanel) {
          _heartRateReadings = [];
          _bloodPressureReadings = [];
          _healthStatus = 'Could not load health data: $e';
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _healthFetchInProgress = false;
          _healthBusy = false;
          _vitalsRefreshing = false;
        });
      }
    }
  }

  void _checkHeartRateAlert(List<HeartRateReading> readings) {
    if (!mounted || readings.isEmpty) return;
    HeartRateAlertService.evaluateReadings(readings, context: context);
  }

  Future<void> _openHealthConnectSettings() async {
    try {
      await _healthConnectService.openHealthConnectPermissions();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _healthStatus = 'Could not open Health Connect settings: $e';
      });
    }
  }

  Future<void> _openSamsungHealth() async {
    try {
      await _healthConnectService.openSamsungHealth();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _healthStatus = 'Could not open Samsung Health: $e';
      });
    }
  }

  Future<void> _openGoogleFit() async {
    try {
      await _healthConnectService.openGoogleFit();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _healthStatus = 'Could not open Google Fit: $e';
      });
    }
  }

  HeartRateReading? get _displayHeartRate =>
      _vitalsHeartRate ??
      (_heartRateReadings.isNotEmpty ? _heartRateReadings.first : null);

  BloodPressureReading? get _displayBloodPressure =>
      _vitalsBloodPressure ??
      (_bloodPressureReadings.isNotEmpty ? _bloodPressureReadings.first : null);

  Widget _buildGoogleFitStatsPanel() {
    final latestHr = _displayHeartRate;
    final latestBp = _displayBloodPressure;
    final hasData = latestHr != null || latestBp != null;
    final isRefreshing = _vitalsRefreshing || _healthFetchInProgress;

    return Material(
      color: const Color(0xFF4285F4).withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_run, color: Color(0xFF4285F4)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Google Fit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh vitals',
                      onPressed: isRefreshing ? null : _refreshVitals,
                      icon: isRefreshing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.refresh,
                              size: 22,
                              color: Colors.grey.shade700,
                            ),
                    ),
                  ],
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildGoogleFitStatTile(
                      icon: Icons.favorite,
                      iconColor: const Color(0xFFE91E63),
                      label: 'Heart rate',
                      value: latestHr != null
                          ? latestHr.bpm.toStringAsFixed(0)
                          : '—',
                      unit: latestHr != null ? 'bpm' : null,
                      sourceLabel: latestHr != null
                          ? _healthConnectService.formatSourceLabel(
                              latestHr.source,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildGoogleFitStatTile(
                      icon: Icons.bloodtype,
                      iconColor: const Color(0xFF7C4DFF),
                      label: 'Blood pressure',
                      value: latestBp != null
                          ? '${latestBp.systolic.toStringAsFixed(0)}/${latestBp.diastolic.toStringAsFixed(0)}'
                          : '—',
                      unit: latestBp != null ? 'mmHg' : null,
                      sourceLabel: latestBp != null
                          ? _healthConnectService.formatSourceLabel(
                              latestBp.source,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
                Text(
                  _googleFitPanelStatusText(
                    latestHr: latestHr,
                    latestBp: latestBp,
                    hasData: hasData,
                    isRefreshing: isRefreshing,
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (isRefreshing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'Updating vitals…',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4285F4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _googleFitPanelStatusText({
    required HeartRateReading? latestHr,
    required BloodPressureReading? latestBp,
    required bool hasData,
    required bool isRefreshing,
  }) {
    if (isRefreshing) {
      return 'Reading latest data from Health Connect…';
    }
    if (_vitalsRefreshError != null) {
      return _vitalsRefreshError!;
    }
    if (hasData) {
      final parts = <String>[];
      if (latestHr != null) {
        parts.add(
          'HR ${latestHr.bpm.round()} bpm · '
          '${_healthConnectService.formatSourceLabel(latestHr.source)} · '
          '${_formatReadingAge(latestHr.recordedAt)}',
        );
      }
      if (latestBp != null) {
        parts.add(
          'BP ${_healthConnectService.formatBloodPressure(latestBp)} · '
          '${_formatReadingAge(latestBp.recordedAt)}',
        );
      }
      return '${parts.join(' · ')}. '
          'WATAD reads Health Connect (synced from Google Fit). '
          'Open Google Fit first if numbers look old.';
    }
    return 'No vitals in Health Connect yet. Open Google Fit, sync to Health Connect, then refresh.';
  }

  String _formatReadingAge(DateTime recordedAt) {
    final diff = DateTime.now().difference(recordedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  Widget _buildGoogleFitStatTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? unit,
    String? sourceLabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: value == '—' ? 22 : 26,
                        fontWeight: FontWeight.bold,
                        color: value == '—'
                            ? Colors.grey.shade400
                            : const Color(0xFF1C1C1E),
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        unit,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (sourceLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sourceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
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

  Widget _buildLogOutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _logOut,
        icon: const Icon(Icons.logout, size: 20),
        label: const Text('Log out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF4D4D),
          side: const BorderSide(color: Color.fromARGB(255, 222, 67, 67)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
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
