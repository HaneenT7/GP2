import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TimeBlock {
  String id;
  String title;
  int dayOfWeek; // 1=Sun, 7=Sat
  double startHour; 
  double endHour;
  Color color;

  TimeBlock({
    required this.id,
    required this.title,
    required this.dayOfWeek,
    required this.startHour,
    required this.endHour,
    required this.color,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dayOfWeek': dayOfWeek,
      'startHour': startHour,
      'endHour': endHour,
      'color': color.value,
    };
  }

  factory TimeBlock.fromMap(Map<String, dynamic> map) {
    return TimeBlock(
      id: map['id'],
      title: map['title'] ?? '',
      dayOfWeek: map['dayOfWeek'],
      startHour: map['startHour'],
      endHour: map['endHour'],
      color: Color(map['color']),
    );
  }

  TimeBlock copyWith({
    String? id,
    String? title,
    int? dayOfWeek,
    double? startHour,
    double? endHour,
    Color? color,
  }) {
    return TimeBlock(
      id: id ?? this.id,
      title: title ?? this.title,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startHour: startHour ?? this.startHour,
      endHour: endHour ?? this.endHour,
      color: color ?? this.color,
    );
  }
}

class AvailabilityCalendarDialog extends StatefulWidget {
  const AvailabilityCalendarDialog({super.key});

  @override
  State<AvailabilityCalendarDialog> createState() => _AvailabilityCalendarDialogState();
}

class _AvailabilityCalendarDialogState extends State<AvailabilityCalendarDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<TimeBlock> blocks = [];
  bool isLoading = true;
  bool isSaving = false;
  String? resizingBlockId;
  

  final ScrollController _verticalScrollController = ScrollController();
  
  static const double hourHeight = 50.0;
  static const double timeColumnWidth = 65.0; 
  static const double headerHeight = 40.0;

  double _dragBuffer = 0.0;
  
  final List<String> _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  // --- Logic Methods ---

  Future<void> _loadBlocks() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final doc = await _firestore.collection('students').doc(user.uid).collection('availability').doc('schedule').get();
      if (doc.exists && doc.data() != null) {
        final List<dynamic> blocksList = doc.data()!['blocks'] ?? [];
        setState(() {
          blocks = blocksList.map((b) => TimeBlock.fromMap(b)).toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveBlocks() async {
    setState(() => isSaving = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _firestore.collection('students').doc(user.uid).collection('availability').doc('schedule').set({
        'blocks': blocks.map((b) => b.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  bool _isPositionOverlap(String blockId, int day, double start, double end) {
    for (var other in blocks) {
      if (other.id == blockId) continue;
      if (other.dayOfWeek == day) {
        if (start < other.endHour && end > other.startHour) return true;
      }
    }
    return false;
  }

  void _handleMoveWithDayWidth(TimeBlock block, Offset delta, double currentLeft, double currentTop, double dayWidth) {
    final newTop = (currentTop + delta.dy).clamp(0.0, 23.5 * hourHeight);
    final newLeftCenter = (currentLeft + (dayWidth / 2) + delta.dx).clamp(0.0, 7 * dayWidth);
    final newStartHour = (newTop / hourHeight);
    final snappedStart = (newStartHour * 4).round() / 4;
    final newDay = (newLeftCenter / dayWidth).floor() + 1;
    final duration = block.endHour - block.startHour;
    final newEnd = snappedStart + duration;

    if (!_isPositionOverlap(block.id, newDay.clamp(1, 7), snappedStart, newEnd)) {
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

  void _handleResize(TimeBlock block, Offset delta, double currentHeight) {
    // 1. Accumulate movement
    _dragBuffer += delta.dy;
    
    // 2. Convert buffer to hours
    double hourDelta = _dragBuffer / hourHeight;
    
    // 3. Only act if the movement is significant enough to change time (0.25h = 15m)
    if (hourDelta.abs() < 0.25) return;

    // 4. Find collision boundary below
    double maxPossibleEnd = 24.0;
    for (var other in blocks) {
      if (other.id == block.id || other.dayOfWeek != block.dayOfWeek) continue;
      if (other.startHour >= block.endHour && other.startHour < maxPossibleEnd) {
        maxPossibleEnd = other.startHour;
      }
    }

    setState(() {
      // Calculate new end hour based on snapped buffer
      double snappedDelta = (hourDelta * 4).round() / 4;
      double newEndHour = block.endHour + snappedDelta;

      // Apply constraints
      if (newEndHour > maxPossibleEnd) newEndHour = maxPossibleEnd;
      if (newEndHour < block.startHour + 0.5) newEndHour = block.startHour + 0.5;

      if (newEndHour != block.endHour) {
        final index = blocks.indexWhere((b) => b.id == block.id);
        if (index != -1) blocks[index] = block.copyWith(endHour: newEndHour);
        _dragBuffer = 0; // Reset buffer only after a successful change
      }
    });
  }

void _handleResizeTop(TimeBlock block, Offset delta) {
    _dragBuffer += delta.dy;
    double hourDelta = _dragBuffer / hourHeight;
    
    if (hourDelta.abs() < 0.25) return;

    double minPossibleStart = 0.0;
    for (var other in blocks) {
      if (other.id == block.id || other.dayOfWeek != block.dayOfWeek) continue;
      if (other.endHour <= block.startHour && other.endHour > minPossibleStart) {
        minPossibleStart = other.endHour;
      }
    }

    setState(() {
      double snappedDelta = (hourDelta * 4).round() / 4;
      double newStartHour = block.startHour + snappedDelta;

      if (newStartHour < minPossibleStart) newStartHour = minPossibleStart;
      if (newStartHour > block.endHour - 0.5) newStartHour = block.endHour - 0.5;

      if (newStartHour != block.startHour) {
        final index = blocks.indexWhere((b) => b.id == block.id);
        if (index != -1) blocks[index] = block.copyWith(startHour: newStartHour);
        _dragBuffer = 0;
      }
    });
  }

  void _addBlock(int dayOfWeek, double startHour) {
    if (_isPositionOverlap('', dayOfWeek, startHour, startHour + 0.5)) return;
    final newBlock = TimeBlock(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '', // Title is no longer used
      dayOfWeek: dayOfWeek,
      startHour: startHour,
      endHour: (startHour + 1.0).clamp(0.0, 24.0),
      color: const Color(0xFFE9D5FF),
    );
    setState(() => blocks.add(newBlock));
  }

  String _formatHour(double hour) {
    int h = hour.floor();
    int m = ((hour % 1) * 60).round();
    String period = h >= 12 ? 'PM' : 'AM';
    int displayHour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$displayHour:${m.toString().padLeft(2, '0')} $period';
  }

  // --- UI Methods ---

 @override
Widget build(BuildContext context) {
  return Dialog(
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: SizedBox(
      width: 850,  // Reduced from 1000
      height: 550, // Reduced from 650
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            _buildHeader(),
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
    return LayoutBuilder(builder: (context, constraints) {
      final dynamicDayWidth = (constraints.maxWidth - timeColumnWidth) / 7;
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
                    ..._days.map((day) => Container(
                      width: dynamicDayWidth,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[300]!), left: BorderSide(color: Colors.grey[100]!))),
                      child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
                    )),
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
    });
  }

  Widget _buildTimeColumn() {
    return Container(
      width: timeColumnWidth,
      decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Colors.grey[200]!))),
      child: Column(
        children: List.generate(24, (i) => Container(
          height: hourHeight,
          alignment: Alignment.topRight,
          padding: const EdgeInsets.only(right: 8, top: 4),
          child: Text(_formatHour(i.toDouble()), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
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
                onLongPress: () => _addBlock(dayIndex + 1, hour.toDouble()),
                child: Container(
                  width: dayWidth,
                  height: hourHeight,
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey[50]!), right: BorderSide(color: Colors.grey[100]!))),
                ),
              )),
            )),
          ),
          ...blocks.map((block) => _buildTimeBlock(block, dayWidth)),
        ],
      ),
    );
  }

Widget _buildTimeBlock(TimeBlock block, double dayWidth) {
  final left = (block.dayOfWeek - 1) * dayWidth;
  final top = block.startHour * hourHeight;
  final height = (block.endHour - block.startHour) * hourHeight;

  return Positioned(
    left: left + 2,
    top: top + 1,
    width: dayWidth - 4,
    height: height - 2,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
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
              borderRadius: BorderRadius.circular(6), // Slightly smaller radius
              border: Border.all(color: block.color.withOpacity(0.5)),
            ),
            padding: const EdgeInsets.only(top: 4, left: 2, right: 2), 
            child: Align(
              alignment: Alignment.topCenter,
              child: Text(
                '${_formatHour(block.startHour)}\n${_formatHour(block.endHour)}', // Split into two lines for better fit
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 8, // Smaller font
                  fontWeight: FontWeight.w600, 
                  color: Colors.black87,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ),
        _buildResizeHandle(block, true, height),
        _buildResizeHandle(block, false, height),
      ],
    ),
  );
}

Widget _buildResizeHandle(TimeBlock block, bool isTop, double currentHeight) {
  return Positioned(
    // By using -5.5, the handle sits directly ON the edge border
    top: isTop ? -7.5: null,
    bottom: isTop ? null : -7.5,
    left: 0,
    right: 0,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) {
        _dragBuffer = 0;
        setState(() => resizingBlockId = block.id);
      },
      onVerticalDragUpdate: (details) {
        if (isTop) {
          _handleResizeTop(block, details.delta);
        } else {
          _handleResize(block, details.delta, currentHeight);
        }
      },
      onVerticalDragEnd: (_) => setState(() => resizingBlockId = null),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: SizedBox(
          height: 20, // The hit area for the finger
          child: Center(
            child: Container(
              width: 35, // Slightly wider bar
              height: 4, 
              decoration: BoxDecoration(
                // Using a darker version of your theme purple for the handle
                color: const Color(0xFF9333EA).withOpacity(0.4), 
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
  // --- Header, Footer, and Dialogs ---

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey[200]!))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configure Availability', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Long press to add • Drag handles to resize', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          OutlinedButton.icon(
            onPressed: () => setState(() => blocks.clear()),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Clear All'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Color(0xFFFFEBEE))),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.grey[50], border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          const SizedBox(width: 15),
          ElevatedButton(
            onPressed: isSaving ? null : _saveBlocks,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9333EA), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Schedule'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(TimeBlock block) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Block?'),
        content: Text('At ${_formatHour(block.startHour)} - ${_formatHour(block.endHour)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () { 
              setState(() => blocks.removeWhere((b) => b.id == block.id)); 
              Navigator.pop(context); 
            }, 
            child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyHeaderDelegate({required this.child});
  @override double get minExtent => 50.0;
  @override double get maxExtent => 50.0;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Material(elevation: overlapsContent ? 4 : 0, child: child);
  @override bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) => false;
}