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
  CourseFolder? _openedFolder; // null = grid, non-null = detail

  final List<String> _folderColors = [
    '#FFD700', '#FF8C00', '#4169E1', '#FF69B4',
    '#32CD32', '#9370DB', '#FF6347', '#20B2AA',
  ];

  @override
  Widget build(BuildContext context) {
    // Swap between grid and detail in-place
    if (_openedFolder != null) {
      return FolderDetailPage(
        folder: _openedFolder!,
        onBack: () => setState(() => _openedFolder = null),
      );
    }
    return _buildFoldersGrid();
  }

  Widget _buildFoldersGrid() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => setState(() => _isManageMode = !_isManageMode),
                icon: Icon(
                  _isManageMode ? Icons.close : Icons.settings,
                  color: Colors.white, size: 18,
                ),
                label: Text(
                  _isManageMode ? 'Done' : 'Manage',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isManageMode ? Colors.grey : const Color(0xFF6B46C1),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showCreateFolderDialog,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('New', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B46C1),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isManageMode = false),
            child: StreamBuilder<List<CourseFolder>>(
              stream: _folderService.getFolders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final folders = snapshot.data ?? [];
                if (folders.isEmpty) {
                  return const Center(
                    child: Text(
                      'No course folders yet.\nClick "+ New" to create one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: folders.length,
                    itemBuilder: (context, index) => _buildFolderCard(folders[index]),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFolderCard(CourseFolder folder) {
    final color = Color(int.parse(folder.color.replaceFirst('#', '0xFF')));
    final showActions = _isManageMode;

    return GestureDetector(
      onTap: () {
        if (showActions) return;
        // Open detail in-place — no Navigator
        setState(() => _openedFolder = folder);
      },
      onLongPress: () => setState(() => _isManageMode = true),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            children: [
              Container(
                width: 120, height: 100,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.folder, size: 60, color: Colors.white),
              ),
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
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _isManageMode = false);
                              _showEditFolderDialog(folder);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue, shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _isManageMode = false);
                              _showDeleteConfirmation(folder);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                              ),
                              child: const Icon(Icons.delete, color: Colors.white, size: 18),
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
          Flexible(
            child: Text(
              folder.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
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
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          if (context.mounted) _showSuccessDialog('New Course Folder', 'The new course folder is added successfully');
        },
        folderColors: _folderColors,
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
            constraints: const BoxConstraints(minWidth: 300, maxWidth: 400),
            child: TextField(
              controller: nameController,
              maxLength: 20,
              onChanged: (_) {
                if (errorMessage != null) setDialogState(() => errorMessage = null);
              },
              decoration: InputDecoration(
                labelText: 'Folder Name',
                border: const OutlineInputBorder(),
                counterText: '',
                errorText: errorMessage,
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) {
                  setDialogState(() => errorMessage = 'Folder name must contain at least 1 character');
                  return;
                }
                try {
                  await _folderService.updateFolder(folder.id, newName);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Folder updated successfully')),
                    );
                  }
                } catch (e) {
                  setDialogState(() {
                    errorMessage = e.toString().contains('already exists')
                        ? 'A folder with this name already exists'
                        : e.toString().replaceFirst('Exception: ', '');
                  });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B46C1)),
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
              width: 60, height: 60,
              decoration: BoxDecoration(color: Colors.red[100], shape: BoxShape.circle),
              child: const Icon(Icons.warning, color: Colors.red, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Delete Folder', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
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
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _folderService.deleteFolder(folder.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        _showSuccessDialog('Folder Deleted', 'The folder is deleted successfully');
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

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: const BoxDecoration(color: Color(0xFF2196F3), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2196F3))),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B46C1),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}