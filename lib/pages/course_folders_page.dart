import 'package:flutter/material.dart';
import '../models/course_folder.dart';
import '../services/folder_service.dart';
import '../widgets/create_folder_dialog.dart';
import 'folder_detail_page.dart';

class CourseFoldersPage extends StatefulWidget {
  const CourseFoldersPage({super.key});

  @override
  State<CourseFoldersPage> createState() => _CourseFoldersPageState();
}

class _CourseFoldersPageState extends State<CourseFoldersPage> {
  final FolderService _folderService = FolderService();
  bool _isManageMode = false;
  CourseFolder? _selectedFolderForQuickAction;

  // Predefined folder colors
  final List<String> _folderColors = [
    '#FFD700', // Yellow
    '#FF8C00', // Orange
    '#4169E1', // Blue
    '#FF69B4', // Pink
    '#32CD32', // Green
    '#9370DB', // Purple
    '#FF6347', // Tomato
    '#20B2AA', // Light Sea Green
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          _buildHeader(),
          // Folders Grid
          Expanded(
            child: GestureDetector(
              onTap: () {
                // Tap outside folders - exit manage mode and clear quick action
                if (_isManageMode || _selectedFolderForQuickAction != null) {
                  setState(() {
                    _isManageMode = false;
                    _selectedFolderForQuickAction = null;
                  });
                }
              },
              child: StreamBuilder<List<CourseFolder>>(
                stream: _folderService.getFolders(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  final folders = snapshot.data ?? [];

                  if (folders.isEmpty) {
                    return const Center(
                      child: Text(
                        'No course folders yet.\nClick "+ New" to create one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: GridView.builder(
                      shrinkWrap: false,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.80,
                      ),
                      itemCount: folders.length,
                      itemBuilder: (context, index) {
                        return _buildFolderCard(folders[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'My Course folders',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isManageMode = !_isManageMode;
                    _selectedFolderForQuickAction = null; // Clear quick action selection
                  });
                },
                icon: Icon(
                  _isManageMode ? Icons.close : Icons.settings,
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  _isManageMode ? 'Done' : 'Manage',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isManageMode ? Colors.grey : const Color(0xFF6B46C1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showCreateFolderDialog(),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'New',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B46C1), // Purple
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFolderCard(CourseFolder folder) {
    final color = Color(int.parse(folder.color.replaceFirst('#', '0xFF')));
    // Show actions only if: manage mode is ON (all folders) OR this specific folder is selected for quick action
    final showActions = _isManageMode || _selectedFolderForQuickAction?.id == folder.id;
    
    return GestureDetector(
      onTap: () {
        if (showActions) {
          // If actions are showing, don't navigate
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FolderDetailPage(folder: folder),
          ),
        );
      },
      onLongPress: () {
        setState(() {
          // Long-press: enter manage mode for all folders (same as Manage button)
          _isManageMode = true;
          _selectedFolderForQuickAction = null; // Clear any quick action selection
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Folder Icon with action buttons overlay
          Stack(
            children: [
              Container(
                width: 120,
                height: 100,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.folder,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              // Action buttons overlay
              if (showActions)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Edit icon - bottom left
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFolderForQuickAction = null;
                                _isManageMode = false;
                              });
                              _showEditFolderDialog(folder);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        // Delete icon - bottom right
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedFolderForQuickAction = null;
                                _isManageMode = false;
                              });
                              _showDeleteConfirmation(folder);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Folder Name
          Flexible(
            child: Text(
              folder.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateFolderDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => CreateFolderDialog(
        onFolderCreated: (name, color) async {
          await _folderService.createFolder(name, color);
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop(); // Close create dialog first
          }
          if (context.mounted) {
            _showSuccessDialog();
          }
        },
        folderColors: _folderColors,
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFF2196F3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'New Course Folder',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The new course folder is added successfully',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B46C1),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }



  void _showEditFolderDialog(CourseFolder folder) {
    final nameController = TextEditingController(text: folder.name);
    String? errorMessage;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Folder'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 300,
              maxWidth: 400,
            ),
            child: TextField(
              controller: nameController,
              maxLength: 20,
              onChanged: (value) {
                // Clear error when user types
                if (errorMessage != null) {
                  setDialogState(() {
                    errorMessage = null;
                  });
                }
              },
              decoration: InputDecoration(
                labelText: 'Folder Name',
                border: const OutlineInputBorder(),
                counterText: '', // Hide character counter
                errorText: errorMessage,
                errorStyle: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
                errorMaxLines: 3,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                
                // Validate and show error under text field
                if (newName.isEmpty) {
                  setDialogState(() {
                    errorMessage = 'Folder name must contain at least 1 character';
                  });
                  return;
                }
                if (newName.length > 20) {
                  setDialogState(() {
                    errorMessage = 'Folder name must be 20 characters or less';
                  });
                  return;
                }

                // Clear any previous error
                setDialogState(() {
                  errorMessage = null;
                });

                try {
                  await _folderService.updateFolder(folder.id, newName);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Folder updated successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    setDialogState(() {
                      final errorStr = e.toString();
                      if (errorStr.contains('already exists')) {
                        errorMessage = 'A folder with this name already exists';
                      } else {
                        errorMessage = errorStr.replaceFirst('Exception: ', '');
                      }
                    });
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B46C1),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(CourseFolder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.red[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning,
                color: Colors.red,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Delete Folder',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to delete "${folder.name}"? This will also delete all files inside it.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _folderService.deleteFolder(folder.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _showDeleteFolderSuccessDialog();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error deleting folder: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteFolderSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFF2196F3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Folder Deleted',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The folder is deleted successfully',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B46C1),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

