import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/course_folder.dart';
import 'models/folder_file.dart';
import 'services/folder_service.dart';
import 'services/file_service.dart';
import 'services/revision_plan_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SetUpRevPlan extends StatefulWidget {
  final VoidCallback onClose;
  const SetUpRevPlan({super.key, required this.onClose});

  @override
  State<StatefulWidget> createState() => _SetUpRevPlanState();
}

/// Watad brand purple (buttons, accents).
const Color _watadPurple = Color(0xFF423066);

class _SetUpRevPlanState extends State<SetUpRevPlan> {
  final FolderService _folderService = FolderService();
  final FileService _fileService = FileService();
  final RevisionPlanService _revisionPlanService = RevisionPlanService();

  CourseFolder? _selectedFolder;
  final Set<String> _selectedFileIds = {};
  late DateTime _selectedDate;
  /// First day of the month currently shown in the exam-date calendar.
  late DateTime _calendarDisplayMonth;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _selectedDate = today;
    _calendarDisplayMonth = DateTime(today.year, today.month, 1);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Create new Revision Plan',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(80.0),
                children: [
                  // Select course folder
                  const Text(
                    'Select course folder',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  _buildCourseFolderSection(),
                  const SizedBox(height: 20),

                  // Select exam materials
                  const Text(
                    'Select exam materials',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  _buildExamMaterialsSection(),
                  const SizedBox(height: 20),

                  // Select exam date
                  const Text(
                    'Select exam date',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 650,
                      height: 350,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: _buildExamDateCalendar(),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
        
        // -- Generate Button --
        Positioned(
          right: 32,
          bottom: 32,
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _onGenerateRevisionPlan,
            icon: _isGenerating
                ? const SizedBox(
                    width: 23,
                    height: 23,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome, color: Colors.white, size: 23),
            label: Text(
              _isGenerating ? 'Generating…' : 'Generate Revision Plan',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _watadPurple,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (_isGenerating)
          Positioned.fill(
            child: ModalBarrier(
              color: Colors.black26,
              dismissible: false,
            ),
          ),
      ],
    );
  }

  String _monthYearLabel(int year, int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[month - 1]} $year';
  }

  bool _canGoToPreviousMonth(DateTime today) {
    final cur = DateTime(
      _calendarDisplayMonth.year,
      _calendarDisplayMonth.month,
      1,
    );
    final firstOfTodayMonth = DateTime(today.year, today.month, 1);
    return cur.isAfter(firstOfTodayMonth);
  }

  Widget _buildDayCell(DateTime date, DateTime today) {
    final d = _dateOnly(date);
    final isPast = d.isBefore(today);
    final isToday = d == today;
    final isSelected = d == _dateOnly(_selectedDate);

    if (isPast) {
      return Center(
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: Colors.grey.shade500,
            decoration: TextDecoration.lineThrough,
            decorationColor: Colors.grey.shade600,
            fontSize: 15,
          ),
        ),
      );
    }

    void select() {
      setState(() => _selectedDate = d);
    }

    if (isSelected) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: select,
          customBorder: const CircleBorder(),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: _watadPurple,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${date.day}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (isToday) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: select,
          customBorder: const CircleBorder(),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _watadPurple, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                '${date.day}',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: select,
        customBorder: const CircleBorder(),
        child: Center(
          child: Text(
            '${date.day}',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExamDateCalendar() {
    final today = _dateOnly(DateTime.now());
    final y = _calendarDisplayMonth.year;
    final m = _calendarDisplayMonth.month;
    final daysInMonth = DateTime(y, m + 1, 0).day;
    final firstWeekday = DateTime(y, m, 1).weekday;
    final leading = firstWeekday % 7;
    final cellCount = ((leading + daysInMonth + 6) ~/ 7) * 7;

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _canGoToPreviousMonth(today)
                  ? () => setState(() {
                        _calendarDisplayMonth = DateTime(y, m - 1, 1);
                      })
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                _monthYearLabel(y, m),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() {
                _calendarDisplayMonth = DateTime(y, m + 1, 1);
              }),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
              .map(
                (s) => SizedBox(
                  width: 36,
                  child: Text(
                    s,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.15,
            ),
            itemCount: cellCount,
            itemBuilder: (context, index) {
              if (index < leading) {
                return const SizedBox.shrink();
              }
              final dayNum = index - leading + 1;
              if (dayNum > daysInMonth) {
                return const SizedBox.shrink();
              }
              return _buildDayCell(DateTime(y, m, dayNum), today);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _onGenerateRevisionPlan() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showSnackBar('Please sign in to generate a plan.', isError: true);
      return;
    }
    if (_selectedFolder == null) {
      _showSnackBar('Please select a course folder.', isError: true);
      return;
    }
    if (_selectedFileIds.isEmpty) {
      _showSnackBar('Please select at least one exam material.', isError: true);
      return;
    }

    setState(() => _isGenerating = true);

    try {
final files = await _fileService.getFiles(_selectedFolder!.id).first;
final selectedFiles = files.where((f) => _selectedFileIds.contains(f.id)).toList();

final selectedFileNames = selectedFiles.map((f) => f.fileName).toList();
final fileUrls = selectedFiles.map((f) => f.fileUrl).toList();

final requestId = _revisionPlanService.generateRequestId();

final request = RevisionPlanRequest(
  userId: userId,
  requestId: requestId,
  folderId: _selectedFolder!.id,
  folderName: _selectedFolder!.name,
  examDateIso: _selectedDate.toIso8601String().split('T').first,
  selectedFileIds: _selectedFileIds.toList(),
  selectedFileNames: selectedFileNames,
  selectedFileUrls: fileUrls,
);

final result = await _revisionPlanService.generatePlan(request);
      if (!mounted) return;
      setState(() => _isGenerating = false);

      if (result.status == 'completed') {
        _showSnackBar('Revision plan generated successfully.');
        widget.onClose();
      } else {
        _showSnackBar(
          result.errorMessage ?? 'Failed to generate plan.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isGenerating = false);
      _showSnackBar('Error: ${e.toString().replaceFirst(RegExp(r'^Exception: '), '')}', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  Widget _buildCourseFolderSection() {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: StreamBuilder<List<CourseFolder>>(
        stream: _folderService.getFolders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'Error loading folders',
                  style: TextStyle(color: Colors.red[700]),
                ),
              ),
            );
          }
          final folders = snapshot.data ?? [];
          if (folders.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No course folders yet. Create folders from Course Folder first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: folders.map((folder) {
                final isSelected = _selectedFolder?.id == folder.id;
                final folderColor = Color(
                  int.parse(folder.color.replaceFirst('#', '0xFF')),
                );
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedFolder = folder;
                        _selectedFileIds.clear();
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? folderColor.withOpacity(0.25)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? folderColor
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder,
                            color: isSelected ? folderColor : Colors.grey,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            folder.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected ? folderColor : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExamMaterialsSection() {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _selectedFolder == null
          ? Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'Select a course folder above to see its files',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            )
          : StreamBuilder<List<FolderFile>>(
              stream: _fileService.getFiles(_selectedFolder!.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'Error loading files',
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  );
                }
                final files = snapshot.data ?? [];
                if (files.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No files in "${_selectedFolder!.name}". Add materials to this folder first.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: files.map((file) {
                      final isSelected = _selectedFileIds.contains(file.id);
                      return FilterChip(
                        selected: isSelected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 18,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[700],
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: Text(
                                file.fileName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedFileIds.add(file.id);
                            } else {
                              _selectedFileIds.remove(file.id);
                            }
                          });
                        },
                        selectedColor: _watadPurple.withOpacity(0.85),
                        checkmarkColor: Colors.white,
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }
}
