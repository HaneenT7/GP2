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
  
  static const double hourHeight = 65.0;
  static const double dayWidth = 130.0;
  static const double timeColumnWidth = 60.0;
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
  // 1. Find the nearest block below the current one on the same day
  double maxPossibleEnd = 24.0;
  for (var other in blocks) {
    if (other.id == block.id || other.dayOfWeek != block.dayOfWeek) continue;
    
    // If the other block starts after our block starts, it's a potential boundary
    if (other.startHour >= block.endHour) {
      if (other.startHour < maxPossibleEnd) {
        maxPossibleEnd = other.startHour;
      }
    }
  }

  setState(() {
    // 2. Calculate the new height based on drag
    // NEW: We clamp the max height to (maxPossibleEnd - block.startHour)
    final newHeight = (currentHeight + localDy).clamp(
      hourHeight * 0.5, 
      (maxPossibleEnd - block.startHour) * hourHeight,
    );

    // 3. Convert height back to logical hours
    final newEndHour = block.startHour + (newHeight / hourHeight);

    final index = blocks.indexWhere((b) => b.id == block.id);
    if (index != -1) {
      double snappedEnd = (newEndHour * 4).round() / 4;
      
      // 4. Final safety checks for 30-min min and collision
      if (snappedEnd - block.startHour < 0.5) {
        snappedEnd = block.startHour + 0.5;
      }
      
      // Ensure snapping doesn't push us into the next block
      if (snappedEnd > maxPossibleEnd) {
        snappedEnd = maxPossibleEnd;
      }

      blocks[index] = block.copyWith(
        endHour: snappedEnd,
      );
    }
  });
}

void _handleResizeTop(TimeBlock block, double localDy) {
  // 1. Find the nearest block ABOVE the current one
  double minPossibleStart = 0.0;
  for (var other in blocks) {
    if (other.id == block.id || other.dayOfWeek != block.dayOfWeek) continue;
    if (other.endHour <= block.startHour) {
      if (other.endHour > minPossibleStart) {
        minPossibleStart = other.endHour;
      }
    }
  }

  setState(() {
    // 2. Calculate the change in hours based on drag
    double dyInHours = localDy / hourHeight;
    double newStartHour = block.startHour + dyInHours;

    // 3. Snap to 15-min increments
    double snappedStart = (newStartHour * 4).round() / 4;

    // 4. Constraints: 
    // - Don't overlap block above
    // - Maintain at least 30 mins duration (snappedStart <= block.endHour - 0.5)
    if (snappedStart < minPossibleStart) snappedStart = minPossibleStart;
    if (snappedStart > block.endHour - 0.5) snappedStart = block.endHour - 0.5;

    final index = blocks.indexWhere((b) => b.id == block.id);
    if (index != -1) {
      blocks[index] = block.copyWith(startHour: snappedStart);
    }
  });
}

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 1000, // Widened slightly to accommodate 7 days comfortably
        height: 650,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              _buildHeader(),
              // This is the method we defined to handle the sticky headers
              Expanded(child: _buildCalendarBody()), 
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildCalendarBody() {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - timeColumnWidth;
        final dynamicDayWidth = availableWidth / 7;

        return CustomScrollView(
          controller: _verticalScrollController,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeaderDelegate(
                child: Container(
                  color: Colors.white,
                  child: Row(
                    children: [
                      const SizedBox(width: timeColumnWidth),
                      ..._days.map(
                        (day) => Container(
                          width: dynamicDayWidth,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                              left: BorderSide(color: Colors.grey[100]!),
                            ),
                          ),
                          child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimeColumn(),
                  _buildDaysGrid(dynamicDayWidth),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

Widget _buildTimeColumn() {
    return Container(
      width: timeColumnWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: List.generate(24, (index) => Container(
          height: hourHeight,
          alignment: Alignment.topRight,
          padding: const EdgeInsets.only(right: 8, top: 4),
          child: Text(
            // Show 12 AM/PM instead of 00:00
            _formatHour(index.toDouble()),
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        )),
      ),
    );
  }

Widget _buildDaysGrid(double dayWidth) {
    return SizedBox(
      width: dayWidth * 7,
      height: hourHeight * 24,
      child: Stack(
        children: [
          Column(
            children: List.generate(24, (hour) => Row(
              children: List.generate(7, (dayIndex) => GestureDetector(
                // dayIndex + 1 where 1 is Sunday
                onLongPress: () => _addBlock(dayIndex + 1, hour.toDouble()),
                child: Container(
                  width: dayWidth,
                  height: hourHeight,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[50]!),
                      right: BorderSide(color: Colors.grey[100]!),
                    ),
                  ),
                ),
              )),
            )),
          ),
          ...blocks.map((block) => _buildTimeBlock(block, dayWidth)),
        ],
      ),
    );
  }



 Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configure Availability',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Long press to add • Drag to move or resize',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          Row(
            children: [
              // Only the Clear button remains as requested
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => blocks.clear());
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Clear All'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Color(0xFFFFEBEE)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
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
    final List<String> _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

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
                _days[index],
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
              ...blocks.map((block) => _buildTimeBlock(block,dayWidth)),
            ],
          ),
        ),
      ],
    );
  }

bool _isPositionOverlap(String blockId, int day, double start, double end) {
  for (var other in blocks) {
    // Don't check the block against itself
    if (other.id == blockId) continue;

    // Only check blocks on the same day
    if (other.dayOfWeek == day) {
      // Intersection Logic
      if (start < other.endHour && end > other.startHour) {
        return true; // Collision detected!
      }
    }
  }
  return false;
}

Widget _buildTimeBlock(TimeBlock block, double dayWidth) {
  final left = (block.dayOfWeek - 1) * dayWidth;
  final top = block.startHour * hourHeight;
  final height = (block.endHour - block.startHour) * hourHeight;
  bool isSmallBlock = (block.endHour - block.startHour) <= 0.5;

  return Positioned(
    left: left + 2,
    top: top + 1,
    width: dayWidth - 4,
    height: height - 2,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        // MAIN BODY
        GestureDetector(
          onTap: () => _showEditDialog(block),
          onPanUpdate: (details) {
            if (resizingBlockId != null) return;
            _handleMoveWithDayWidth(block, details.delta, left, top, dayWidth);
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: block.color.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: block.color.withOpacity(0.5)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  block.title,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, height: 1.1),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (!isSmallBlock)
                  Text('${_formatHour(block.startHour)}', style: const TextStyle(fontSize: 8, color: Colors.black54)),
              ],
            ),
          ),
        ),

        // TOP RESIZE HANDLE (NEW)
        Positioned(
          top: -5,
          left: 0,
          right: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (_) => setState(() => resizingBlockId = block.id),
            onVerticalDragUpdate: (details) => _handleResizeTop(block, details.localPosition.dy),
            onVerticalDragEnd: (_) => setState(() => resizingBlockId = null),
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: Container(
                height: 15,
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: 20,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
            ),
          ),
        ),

        // BOTTOM RESIZE HANDLE
        Positioned(
          bottom: -5,
          left: 0,
          right: 0,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (_) => setState(() => resizingBlockId = block.id),
            onVerticalDragUpdate: (details) => _handleResize(block, details.localPosition.dy, height),
            onVerticalDragEnd: (_) => setState(() => resizingBlockId = null),
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: Container(
                height: 15,
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: 20,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
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

void _handleMoveWithDayWidth(TimeBlock block, Offset delta, double currentLeft, double currentTop, double dayWidth) {
  final newTop = (currentTop + delta.dy).clamp(0.0, 23.75 * hourHeight);
  final newLeftCenter = (currentLeft + (dayWidth / 2) + delta.dx).clamp(0.0, 7 * dayWidth);
  
  final newStartHour = (newTop / hourHeight);
  final snappedStart = (newStartHour * 4).round() / 4;
  final newDay = (newLeftCenter / dayWidth).floor() + 1;
  final duration = block.endHour - block.startHour;
  final newEnd = snappedStart + duration;

  // ONLY update state if the new position is clear
  if (!_isPositionOverlap(block.id, newDay, snappedStart, newEnd)) {
    setState(() {
      final index = blocks.indexWhere((b) => b.id == block.id);
      if (index != -1) {
        blocks[index] = block.copyWith(
          dayOfWeek: newDay.clamp(1, 7),
          startHour: snappedStart,
          endHour: newEnd,
        );
      }
    });
  }
}

  String _formatHour(double hour) {
    int h = hour.floor();
    int m = ((hour % 1) * 60).round();
    String period = h >= 12 ? 'PM' : 'AM';
    int displayHour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$displayHour:${m.toString().padLeft(2, '0')} $period';
  }

Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 15),
          ElevatedButton(
            onPressed: isSaving ? null : _saveBlocks,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9333EA), // Match button from RevPlanPage
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Schedule'),
          ),
        ],
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyHeaderDelegate({required this.child});

  @override
  double get minExtent => 50.0;
  @override
  double get maxExtent => 50.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(elevation: overlapsContent ? 4 : 0, child: child);
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) => false;
}