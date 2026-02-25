import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'models/course_folder.dart';
import 'models/folder_file.dart';
import 'services/folder_service.dart';
import 'services/file_service.dart';
import 'services/revision_plan_service.dart';

class SetUpRevPlan extends StatefulWidget {
  final VoidCallback onClose;
  const SetUpRevPlan({super.key, required this.onClose});

  @override
  State<StatefulWidget> createState() => _SetUpRevPlanState();
}

class _SetUpRevPlanState extends State<SetUpRevPlan> {
  final FolderService _folderService = FolderService();
  final FileService _fileService = FileService();
  final RevisionPlanService _revisionPlanService = RevisionPlanService();

  CourseFolder? _selectedFolder;
  final Set<String> _selectedFileIds = {};
  DateTime _selectedDate = DateTime.now();
  bool _isGenerating = false;

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
                      child: Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: ColorScheme.light(
                            primary: const Color(0xFF423066),
                            onPrimary: const Color(0xFF423066),
                            surface: const Color(0xFFF9F9F9),
                            onSurface: Colors.black,
                          ),
                          datePickerTheme: DatePickerThemeData(
                            dayForegroundColor: WidgetStateProperty.resolveWith(
                              (states) {
                                if (states.contains(WidgetState.selected)) {
                                  return const Color.fromARGB(
                                    255,
                                    118,
                                    30,
                                    219,
                                  );
                                }
                                return Colors.black;
                              },
                            ),
                            dayBackgroundColor: WidgetStateProperty.resolveWith(
                              (states) {
                                if (states.contains(WidgetState.selected)) {
                                  return const Color(0xFF423066);
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        child: CalendarDatePicker(
                          key: ValueKey(
                            '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}',
                          ),
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          onDateChanged: (DateTime date) {
                            setState(() => _selectedDate = date);
                          },
                        ),
                      ),
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
              backgroundColor: const Color(0xFF423066),
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
      final selectedFiles = files
          .where((f) => _selectedFileIds.contains(f.id))
          .map((f) => f.fileName)
          .toList();
      final requestId = _revisionPlanService.generateRequestId();
      final request = RevisionPlanRequest(
        userId: userId,
        requestId: requestId,
        folderId: _selectedFolder!.id,
        folderName: _selectedFolder!.name,
        examDateIso: _selectedDate.toIso8601String().split('T').first,
        selectedFileIds: _selectedFileIds.toList(),
        selectedFileNames: selectedFiles,
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
                        selectedColor: const Color(
                          0xFF423066,
                        ).withOpacity(0.85),
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
