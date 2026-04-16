import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'SetUpRevPlan.dart';
import 'pages/RevisionPlanCalendarPage.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'pages/availability_calendar_dialog.dart';

class RevPlanPage extends StatefulWidget {
  const RevPlanPage({super.key});
  
  @override
  State<StatefulWidget> createState() => _RevPlanPageState();
}

class _RevPlanPageState extends State<StatefulWidget> {
  int _selectedIndex = 1;
  bool _isSetupMode = false;

  Widget _buildConfigureButton() {
    return OutlinedButton.icon(
      onPressed: () => showDialog(context: context, builder: (context) =>  AvailabilityCalendarDialog()),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF9333EA),
        side: const BorderSide(color: Color(0xFFE9D5FF), width: 2),
        backgroundColor: const Color(0xFFFAF5FF),
      ),
      icon: const Icon(Icons.calendar_today, size: 18),
      label: const Text('Configure Availability'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isSetupMode
          ? SetUpRevPlan(
              onClose: () {
                setState(() => _isSetupMode = false);
              },
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Revision plans',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_none_outlined),
                        onPressed: () {
                          //TODO: alarm feature
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Color.fromARGB(255, 33, 33, 33),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildConfigureButton(),

                      const SizedBox(width: 8),

                     ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isSetupMode = true;
                        });
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        'Create new Plan',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4B3D8E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
                
                // Revision Plans List
                Expanded(
                  child: userId == null
                      ? const Center(child: Text('Please sign in'))
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('revisionPlans')
                              .where('userId', isEqualTo: userId)
                              .orderBy('createdAt', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }

                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No revision plans yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Create your first plan to get started!',
                                      style: TextStyle(color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final plans = snapshot.data!.docs;

                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: plans.length,
                              itemBuilder: (context, index) {
                                final planDoc = plans[index];
                                final planData = planDoc.data() as Map<String, dynamic>;
                                
                                return RevisionPlanCard(
                                  planId: planDoc.id,
                                  planData: planData,
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// Revision Plan Card Widget
class RevisionPlanCard extends StatelessWidget {
  final String planId;
  final Map<String, dynamic> planData;

  const RevisionPlanCard({
    required this.planId,
    required this.planData,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final folderName = planData['folderName'] ?? 'Study Material';
    DateTime examDate;
  var rawDate = planData['examDate'];
  if (rawDate is Timestamp) {
    examDate = rawDate.toDate();
  } else if (rawDate is String) {
    examDate = DateTime.parse(rawDate);
  } else {
    examDate = DateTime.now();
  }

var rawTasks = planData['dailyTasks'];
  List<dynamic> dailyTasks = [];
  if (rawTasks is String) {
    try {
      dailyTasks = jsonDecode(rawTasks) as List<dynamic>;
    } catch (e) {
      dailyTasks = [];
    }
  } else if (rawTasks is List) {
    dailyTasks = rawTasks;
  }

    // Calculate days left
    final daysLeft = examDate.difference(DateTime.now()).inDays;
    
    // Calculate progress percentage
    int totalTasks = 0;
    int completedTasks = 0;
    
    for (var day in dailyTasks) {
      final tasks = day['tasks'] as List<dynamic>? ?? [];
      totalTasks += tasks.length;
      completedTasks += tasks.where((t) => t['completed'] == true).length;
    }
    
    final progressPercentage = totalTasks > 0 
        ? ((completedTasks / totalTasks) * 100).round() 
        : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RevisionPlanCalendarPage(
                planId: planId,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Folder icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4B3D8E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.folder,
                  color: Color(0xFF4B3D8E),
                  size: 32,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Plan info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folderName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.event,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Exam: ${DateFormat('MMM dd, yyyy').format(examDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                                  ? Colors.red 
                                  : Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Progress bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progressPercentage / 100,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progressPercentage < 30
                                    ? Colors.red
                                    : progressPercentage < 70
                                        ? Colors.orange
                                        : Colors.green,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$progressPercentage%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: progressPercentage < 30
                                ? Colors.red
                                : progressPercentage < 70
                                    ? Colors.orange
                                    : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}