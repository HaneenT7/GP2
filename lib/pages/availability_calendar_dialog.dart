import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TimeBlock {
  String id;
  String title;
  int dayOfWeek; // 1=Mon, 7=Sun
  double startHour; // 8.5 = 8:30am
  double endHour;
  Color color;
  String type; // 'sleep', 'lecture', 'personal'

  TimeBlock({
    required this.id,
    required this.title,
    required this.dayOfWeek,
    required this.startHour,
    required this.endHour,
    required this.color,
    this.type = 'personal',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dayOfWeek': dayOfWeek,
      'startHour': startHour,
      'endHour': endHour,
      'color': color.value,
      'type': type,
    };
  }

  factory TimeBlock.fromMap(Map<String, dynamic> map) {
    return TimeBlock(
      id: map['id'],
      title: map['title'],
      dayOfWeek: map['dayOfWeek'],
      startHour: map['startHour'],
      endHour: map['endHour'],
      color: Color(map['color']),
      type: map['type'] ?? 'personal',
    );
  }

  TimeBlock copyWith({
    String? id,
    String? title,
    int? dayOfWeek,
    double? startHour,
    double? endHour,
    Color? color,
    String? type,
  }) {
    return TimeBlock(
      id: id ?? this.id,
      title: title ?? this.title,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      color: color ?? this.color,
      type: type ?? this.type,
    );
  }
}

class AvailabilityCalendarDialog extends StatefulWidget {
  @override
  State<AvailabilityCalendarDialog> createState() =>
      _AvailabilityCalendarDialogState();
}

class _AvailabilityCalendarDialogState
    extends State<AvailabilityCalendarDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<TimeBlock> blocks = [];
  bool isLoading = true;
  bool isSaving = false;
  String? resizingBlockId;
  String? resizeEdge; // 'top' or 'bottom'

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  
  static const double hourHeight = 80.0;
  static const double dayWidth = 140.0;
  static const double timeColumnWidth = 70.0;
  static const double headerHeight = 50.0;

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBlocks() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final doc = await _firestore
          .collection('students')
          .doc(user.uid)
          .collection('availability')
          .doc('schedule')
          .get();

      if (doc.exists && doc.data() != null) {
        final List<dynamic> blocksList = doc.data()!['blocks'] ?? [];
        setState(() {
          blocks = blocksList.map((b) => TimeBlock.fromMap(b)).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading blocks: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _saveBlocks() async {
    setState(() {
      isSaving = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('students')
          .doc(user.uid)
          .collection('availability')
          .doc('schedule')
          .set({
        'blocks': blocks.map((b) => b.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Availability saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error saving blocks: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  void _addBlock(int dayOfWeek, double startHour) {
    final newBlock = TimeBlock(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'New Block',
      dayOfWeek: dayOfWeek,
      startHour: startHour,
      endHour: (startHour + 1.0).clamp(0.0, 24.0),
      color: const Color(0xFFE9D5FF),
      type: 'personal',
    );

    setState(() {
      blocks.add(newBlock);
    });

    _showEditDialog(newBlock);
  }

  void _showEditDialog(TimeBlock block) {
    final titleController = TextEditingController(text: block.title);
    String selectedType = block.type;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Block'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'sleep', child: Text('🌙 Sleep')),
                DropdownMenuItem(value: 'lecture', child: Text('📚 Lecture')),
                DropdownMenuItem(value: 'personal', child: Text('⭐ Personal')),
                DropdownMenuItem(value: 'meal', child: Text('🍽️ Meal')),
                DropdownMenuItem(value: 'exercise', child: Text('💪 Exercise')),
              ],
              onChanged: (value) {
                if (value != null) selectedType = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                blocks.removeWhere((b) => b.id == block.id);
              });
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final index = blocks.indexWhere((b) => b.id == block.id);
                if (index != -1) {
                  blocks[index] = block.copyWith(
                    title: titleController.text,
                    type: selectedType,
                    color: _getColorForType(selectedType),
                  );
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'sleep':
        return const Color(0xFFDDD6FE);
      case 'lecture':
        return const Color(0xFFC4B5FD);
      case 'meal':
        return const Color(0xFFFBCAFE);
      case 'exercise':
        return const Color(0xFFBFDBFE);
      default:
        return const Color(0xFFE9D5FF);
    }
  }

  void _applyTemplate(String template) {
    setState(() {
      blocks.clear();

      switch (template) {
        case 'student':
          // Sleep 11pm - 7am
          for (int day = 1; day <= 7; day++) {
            blocks.add(TimeBlock(
              id: 'sleep_$day',
              title: 'Sleep',
              dayOfWeek: day,
              startHour: 0.0,
              endHour: 7.0,
              color: const Color(0xFFDDD6FE),
              type: 'sleep',
            ));
            blocks.add(TimeBlock(
              id: 'sleep2_$day',
              title: 'Sleep',
              dayOfWeek: day,
              startHour: 23.0,
              endHour: 24.0,
              color: const Color(0xFFDDD6FE),
              type: 'sleep',
            ));
          }
          // Lectures Mon-Thu 8am-2pm
          for (int day = 1; day <= 4; day++) {
            blocks.add(TimeBlock(
              id: 'lecture_$day',
              title: 'Lectures',
              dayOfWeek: day,
              startHour: 8.0,
              endHour: 14.0,
              color: const Color(0xFFC4B5FD),
              type: 'lecture',
            ));
          }
          break;

        case 'morning':
          for (int day = 1; day <= 7; day++) {
            blocks.add(TimeBlock(
              id: 'sleep_$day',
              title: 'Sleep',
              dayOfWeek: day,
              startHour: 0.0,
              endHour: 6.0,
              color: const Color(0xFFDDD6FE),
              type: 'sleep',
            ));
            blocks.add(TimeBlock(
              id: 'sleep2_$day',
              title: 'Sleep',
              dayOfWeek: day,
              startHour: 22.0,
              endHour: 24.0,
              color: const Color(0xFFDDD6FE),
              type: 'sleep',
            ));
          }
          break;

        case 'night':
          for (int day = 1; day <= 7; day++) {
            blocks.add(TimeBlock(
              id: 'sleep_$day',
              title: 'Sleep',
              dayOfWeek: day,
              startHour: 1.0,
              endHour: 9.0,
              color: const Color(0xFFDDD6FE),
              type: 'sleep',
            ));
          }
          break;
      }
    });
  }

  void _handleMove(TimeBlock block, Offset delta, double currentLeft, double currentTop) {
  setState(() {
    // Calculate new position
    final newTop = (currentTop + delta.dy).clamp(0.0, 23.75 * hourHeight);
    final newLeft = (currentLeft + delta.dx).clamp(0.0, 6 * dayWidth);
    
    // Convert to logical time/day
    final newStartHour = (newTop / hourHeight);
    final newDay = (newLeft / dayWidth).floor() + 1;
    final duration = block.endHour - block.startHour;

    final index = blocks.indexWhere((b) => b.id == block.id);
    if (index != -1) {
      // Snap to 15 min (0.25)
      final snappedStart = (newStartHour * 4).round() / 4;
      blocks[index] = block.copyWith(
        dayOfWeek: newDay.clamp(1, 7),
        startHour: snappedStart.clamp(0.0, 24.0 - duration),
        endHour: (snappedStart + duration).clamp(0.0, 24.0),
      );
    }
  });
}

void _handleResize(TimeBlock block, double localDy, double currentHeight) {
  setState(() {
    final newHeight = (currentHeight + localDy).clamp(hourHeight * 0.25, 24.0 * hourHeight);
    final newEndHour = block.startHour + (newHeight / hourHeight);

    final index = blocks.indexWhere((b) => b.id == block.id);
    if (index != -1) {
      // Snap to 15 min (0.25)
      final snappedEnd = (newEndHour * 4).round() / 4;
      blocks[index] = block.copyWith(
        endHour: snappedEnd.clamp(block.startHour + 0.25, 24.0),
      );
    }
  });
}

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(40),
      child: Container(
        width: 1100,
        height: 700,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildCalendar()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '⚙️ Configure Your Availability',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTemplateButton('📚 Student', 'student'),
              const SizedBox(width: 8),
              _buildTemplateButton('🌅 Morning Person', 'morning'),
              const SizedBox(width: 8),
              _buildTemplateButton('🌙 Night Owl', 'night'),
              const SizedBox(width: 8),
              _buildTemplateButton('🗑️ Clear All', 'clear'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '💡 Long press empty space to add • Drag block to move • Drag top/bottom edges to resize',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateButton(String label, String template) {
    return OutlinedButton(
      onPressed: () {
        if (template == 'clear') {
          setState(() {
            blocks.clear();
          });
        } else {
          _applyTemplate(template);
        }
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: BorderSide(color: Colors.purple[200]!),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: Colors.purple[700]),
      ),
    );
  }
//////////////////////////////////////////////////////////////
  Widget _buildCalendar() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: Colors.grey[50],
      // Single vertical scroll for the entire grid + time column
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeColumnContent(),
            // Horizontal scroll only for the days grid
            Expanded(
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: _buildWeekView(),
              ),
            ),
          ],
        ),
      ),
    );
  }
///////////////////////////////////////////////////////////////////////////////////////////////////////
  Widget _buildTimeColumnContent() {
  return Container(
    width: timeColumnWidth,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: Colors.grey[300]!)),
    ),
    child: Column(
      children: [
        Container(
          height: headerHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 2),
            ),
          ),
        ),
        Column(
          children: List.generate(24, (index) {
            return Container(
              height: hourHeight,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: Text(
                '${index.toString().padLeft(2, '0')}:00',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }),
        ),
      ],
    ),
  );
}

  Widget _buildWeekView() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Days Header
        Row(
          children: List.generate(7, (index) {
            return Container(
              width: dayWidth,
              height: headerHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!, width: 2),
                  left: index == 0 ? BorderSide.none : BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Text(
                days[index],
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            );
          }),
        ),
        // The Interactive Grid
        SizedBox(
          width: dayWidth * 7,
          height: hourHeight * 24,
          child: Stack(
            children: [
              // Grid Lines
              Column(
                children: List.generate(24, (hour) {
                  return Row(
                    children: List.generate(7, (dayIndex) {
                      return GestureDetector(
                        onLongPress: () => _addBlock(dayIndex + 1, hour.toDouble()),
                        child: Container(
                          width: dayWidth,
                          height: hourHeight,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: Colors.grey[200]!),
                              left: dayIndex == 0 ? BorderSide.none : BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
              // Time Blocks
              ...blocks.map((block) => _buildTimeBlock(block)),
            ],
          ),
        ),
      ],
    );
  }

Widget _buildTimeBlock(TimeBlock block) {
  final left = (block.dayOfWeek - 1) * dayWidth;
  final top = block.startHour * hourHeight;
  final height = (block.endHour - block.startHour) * hourHeight;

  return Positioned(
    left: left + 2,
    top: top,
    width: dayWidth - 4,
    height: height,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        // The Main Body of the block
        GestureDetector(
          onTap: () => _showEditDialog(block),
          onPanUpdate: (details) {
            if (resizingBlockId != null) return;
            _handleMove(block, details.delta, left, top);
          },
          child: Container(
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: block.color.withOpacity(0.8), // Semi-transparent like Google
              borderRadius: BorderRadius.circular(4),
              border: Border(
                left: BorderSide(color: block.color, width: 4), // Solid left accent
              ),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_formatHour(block.startHour)} - ${_formatHour(block.endHour)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Resize Handle (The "Grabber")
        Positioned(
          bottom: -5,
          left: 0,
          right: 0,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: GestureDetector(
              onVerticalDragStart: (_) => resizingBlockId = block.id,
              onVerticalDragUpdate: (details) {
                _handleResize(block, details.localPosition.dy, height);
              },
              onVerticalDragEnd: (_) => resizingBlockId = null,
              child: Container(
                height: 10,
                color: Colors.transparent, // Invisible but clickable
                child: Center(
                  child: Container(
                    width: 30,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
  String _formatHour(double hour) {
    final h = hour.floor();
    final m = ((hour % 1) * 60).round();
    final period = h >= 12 ? 'PM' : 'AM';
    final displayHour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '${displayHour}:${m.toString().padLeft(2, '0')} $period';
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: isSaving ? null : _saveBlocks,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE9D5FF),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}