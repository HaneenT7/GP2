import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/course_folder.dart';
import '../models/folder_file.dart';
import '../services/file_service.dart';
import '../services/folder_service.dart';
import 'pdf_viewer_page.dart';
import '../widgets/pill_toast.dart';

class FolderDetailPage extends StatefulWidget {
  final CourseFolder folder;
  final VoidCallback onBack; // ← replaces Navigator.pop

  const FolderDetailPage({
    super.key,
    required this.folder,
    required this.onBack,
  });

  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage> {
  final FileService _fileService = FileService();
  final FolderService _folderService = FolderService();
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final folderColor = Color(
      int.parse(widget.folder.color.replaceFirst('#', '0xFF')),
    );

    return Column(
      children: [
        // ── Back header (replaces AppBar) ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 24, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: const Color(0xFF553C76),
                onPressed: widget.onBack, // ← calls parent setState
              ),
              Container(
                width: 44,
                height: 40,
                decoration: BoxDecoration(
                  color: folderColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: folderColor.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.folder, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.folder.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1a0a2e),
                      ),
                    ),
                    StreamBuilder<List<FolderFile>>(
                      stream: _fileService.getFiles(widget.folder.id),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return Text(
                          '$count ${count == 1 ? 'file' : 'files'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Upload button in header
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadFile,
                icon: _isUploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.upload_file,
                        color: Colors.white,
                        size: 18,
                      ),
                label: const Text(
                  'Upload',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B46C1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── Files grid ─────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<FolderFile>>(
            stream: _fileService.getFiles(widget.folder.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final files = snapshot.data ?? [];
              if (files.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No files yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Click Upload to add PDF files',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              // FIXED: Replaced rigid FixedCrossAxisCount with a highly adaptive MaxCrossAxisExtent approach
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 320, // Clean desktop and tablet sizing limits
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.6, // Safer aspect ratio layout allocation
                ),
                itemCount: files.length,
                itemBuilder: (context, index) => _buildFileCard(files[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileCard(FolderFile file) {
    final fileNameWithoutExt = file.fileName.replaceAll(
      RegExp(r'\.pdf$', caseSensitive: false),
      '',
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openFile(file),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.picture_as_pdf,
                  color: Colors.red,
                  size: 24, // Slightly scaled down to gain layout height
                ),
              ),
              const SizedBox(height: 8),
              
              // FIXED: Wrapped file title with Expanded to take up available space safely
              Expanded(
                child: Text(
                  fileNameWithoutExt,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatFileSize(file.fileSize),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  // Small alignment adjustment wrapper to protect bounds
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: PopupMenuButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert, size: 18),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'open', child: Text('Open')),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'open') _openFile(file);
                        if (value == 'delete') _deleteFile(file);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFile(FolderFile file) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfViewerPage(file: file)),
    );
  }

  Future<void> _uploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: kIsWeb,
        dialogTitle: 'Select a PDF file',
      );
      if (result == null || result.files.isEmpty) return;

      final pickedFile = result.files.single;
      if (!pickedFile.name.toLowerCase().endsWith('.pdf')) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a PDF file'),
              backgroundColor: Colors.orange,
            ),
          );
        return;
      }

      final existingFiles = await _fileService.getFiles(widget.folder.id).first;
      final normalizedPickedName = _normalizeFileName(pickedFile.name);
      final isDuplicate = existingFiles.any(
        (file) => _normalizeFileName(file.fileName) == normalizedPickedName,
      );

      if (isDuplicate) {
        _showDuplicateFileDialog(pickedFile.name);
        return;
      }

      setState(() {
        _isUploading = true;
      });

      dynamic fileData;
      int fileSize;

      if (kIsWeb) {
        fileData = pickedFile.bytes ?? (throw Exception('File data is null'));
        fileSize = pickedFile.size;
      } else {
        if (pickedFile.path != null && pickedFile.path!.isNotEmpty) {
          final f = File(pickedFile.path!);
          if (await f.exists()) {
            fileData = f;
            fileSize = await f.length();
          } else {
            fileData = pickedFile.bytes;
            fileSize = pickedFile.size;
          }
        } else {
          fileData = pickedFile.bytes;
          fileSize = pickedFile.size;
        }
      }

      await _fileService.uploadFile(
        widget.folder.id,
        fileData,
        pickedFile.name,
        fileSize,
      );
      await _folderService.touchFolder(widget.folder.id);
      if (mounted)
        PillToast.show(
            context,
            message: 'File uploaded ',
            icon: Icons.edit_note_rounded, // A nice icon for editing/updating
          );
      } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  

  Future<void> _deleteFile(FolderFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${file.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _fileService.deleteFile(file);
        await _folderService.touchFolder(widget.folder.id);
        
        if (mounted) {
          final overlayState = Overlay.of(context);
          PillToast.show(
              context,
              message: 'File deleted',
              icon: Icons.edit_note_rounded, // A nice icon for editing/updating
            );        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting file: $e'),
              backgroundColor: Colors.red,
            ),
          );
      }
    }
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
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFF2196F3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B46C1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 12,
                ),
              ),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDuplicateFileDialog(String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File already exists'),
        content: Text('"$fileName" already exists in this course folder.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _normalizeFileName(String fileName) {
    return fileName.trim().toLowerCase();
  }
}