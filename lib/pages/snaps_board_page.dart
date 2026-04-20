import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'board_detail_page.dart';
import 'package:gp2_watad/DashBoard.dart';
import 'package:gp2_watad/widgets/app_header.dart';


class SnapsBoardPage extends StatefulWidget {
  const SnapsBoardPage({super.key});

  @override
  State<SnapsBoardPage> createState() => _SnapsBoardPageState();
}

class _SnapsBoardPageState extends State<SnapsBoardPage> {
  // ── CHANGED: replaced hardcoded list with empty list + Firestore ──
  final List<Map<String, String>> _boards = []; // {id, name}
  bool _isLoading = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedBoardName;
  String? _selectedBoardId;

  @override
  void initState() {
    super.initState();
    _loadBoards(); // ── CHANGED: load from Firestore on startup ──
  }

  // ── CHANGED: fetch boards from Firestore ──
  Future<void> _loadBoards() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final snapshot = await _firestore
          .collection('students')
          .doc(userId)
          .collection('boards')
          .orderBy('createdAt')
          .get();

      setState(() {
        _boards.clear();
        for (var doc in snapshot.docs) {
          _boards.add({'id': doc.id, 'name': doc.data()['name'] ?? doc.id});
        }
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading boards: $e');
      setState(() => _isLoading = false);
    }
  }

  String _normalizeName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  // ── use board name as document ID to stay consistent with old data ──
  Future<void> _createBoard(String name) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection('students')
        .doc(userId)
        .collection('boards')
        .doc(name) // ← name is the document ID
        .set({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      _boards.add({'id': name, 'name': name});
    });
  }

  // ── CHANGED: rename board in Firestore ──
  Future<void> _renameBoard(int index, String newName) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final boardId = _boards[index]['id']!;
    await _firestore
        .collection('students')
        .doc(userId)
        .collection('boards')
        .doc(boardId)
        .update({'name': newName});

    setState(() {
      _boards[index] = {'id': boardId, 'name': newName};
    });
  }

  // ── CHANGED: delete board from Firestore ──
  Future<void> _deleteBoard(int index) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final boardId = _boards[index]['id']!;
    await _firestore
        .collection('students')
        .doc(userId)
        .collection('boards')
        .doc(boardId)
        .delete();

    setState(() {
      _boards.removeAt(index);
    });
  }

  void _openCreateBoardModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreateBoardModal(
        onOk: (name) async {
          final normalizedName = _normalizeName(name ?? '');
          if (normalizedName.isEmpty) return;

          final isDuplicate = _boards.any(
            (b) => _normalizeName(b['name']!).toLowerCase() ==
                normalizedName.toLowerCase(),
          );
          if (isDuplicate) {
            _showDuplicateNameError(normalizedName);
            return;
          }

          Navigator.pop(context);
          await _createBoard(normalizedName); // ── CHANGED ──
          _showSuccessModal();
        },
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  void _showDuplicateNameError(String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Board Name'),
        content: Text(
          'A board named "$name" already exists. Please choose a different name.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SuccessModal(
        onOk: () => Navigator.pop(context),
      ),
    );
  }

  void _showRenameDialog(int index, String currentName) {
    showDialog(
      context: context,
      builder: (context) => _RenameBoardModal(
        currentName: currentName,
        onOk: (newName) async {
          final normalizedName = _normalizeName(newName ?? '');
          if (normalizedName.isEmpty) return;

          final isDuplicate = _boards.asMap().entries.any(
            (e) =>
                e.key != index &&
                _normalizeName(e.value['name']!).toLowerCase() ==
                    normalizedName.toLowerCase(),
          );
          if (isDuplicate) {
            _showDuplicateNameError(normalizedName);
            return;
          }

          Navigator.pop(context);
          await _renameBoard(index, normalizedName); // ── CHANGED ──
        },
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Board'),
        content: Text(
          'Are you sure you want to delete "${_boards[index]['name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteBoard(index); // ── CHANGED ──
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  if (_selectedBoardName != null && _selectedBoardId != null) {
    return BoardDetailPage(
      boardName: _selectedBoardName!,
      boardId: _selectedBoardId!,
      onBack: () => setState(() {
        _selectedBoardName = null;
        _selectedBoardId = null;
      }),
    );
  }

  const purpleDark = Color(0xFF4C1D95);

  return Container(
    color: Colors.white,
    padding: const EdgeInsets.only(top: 0, bottom: 24), // top 0 so header hits the top
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. THE NEW GLOBAL HEADER
        const AppHeader(title: 'My Snaps Board'),

        // 2. ACTION BUTTON ROW (Under the Header)
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end, // Aligns button to the right
            children: [
              ElevatedButton.icon(
                onPressed: _openCreateBoardModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Create New Board'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 3. THE BOARDS GRID
        _isLoading
            ? const Expanded(
                child: Center(child: CircularProgressIndicator()))
            : Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return _buildBoardsGrid(
                          constraints.maxWidth, constraints.maxHeight);
                    },
                  ),
                ),
              ),
      ],
    ),
  );
}


  Widget _buildBoardsGrid(double availableWidth, double availableHeight) {
    const horizontalSpacing = 20.0;
    const verticalSpacing = 20.0;
    const crossAxisCount = 4;

    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: verticalSpacing,
        crossAxisSpacing: horizontalSpacing,
        childAspectRatio: 1.3,
      ),
      itemCount: _boards.length,
      itemBuilder: (context, index) {
        return _BoardCard(
          name: _boards[index]['name']!,
          // ── CHANGED: pass boardId when opening detail page ──
          onTap: () => setState(() {
            _selectedBoardName = _boards[index]['name'];
            _selectedBoardId = _boards[index]['id'];
          }),
          onRename: () =>
              _showRenameDialog(index, _boards[index]['name']!),
          onDelete: () => _showDeleteConfirmation(index),
        );
      },
    );
  }
}

// ── No changes below this line ──

class _BoardCard extends StatelessWidget {
  final String name;
  final VoidCallback? onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _BoardCard({
    required this.name,
    this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const lightPurple = Color(0xFFE0D0EB);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: lightPurple,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              left: 0,
              child: Icon(Icons.computer_outlined,
                  size: 20, color: const Color(0xFF6B46C1)),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[800]),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                onSelected: (value) {
                  if (value == 'rename') onRename();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 12),
                      Text('Rename'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 20),
                      SizedBox(width: 12),
                      Text('Delete'),
                    ]),
                  ),
                ],
              ),
            ),
            Center(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateBoardModal extends StatefulWidget {
  final void Function(String?) onOk;
  final VoidCallback onClose;

  const _CreateBoardModal({required this.onOk, required this.onClose});

  @override
  State<_CreateBoardModal> createState() => _CreateBoardModalState();
}

class _CreateBoardModalState extends State<_CreateBoardModal> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const lightPurple = Color(0xFFE9D5FF);
    const purpleDark = Color(0xFF4C1D95);

    return Dialog(
      backgroundColor: lightPurple,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDD6FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.computer,
                          size: 32, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Board Name',
                  hintStyle:
                      TextStyle(color: Colors.grey[600], fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
                style: const TextStyle(fontSize: 14),
                onSubmitted: (_) => widget.onOk(_controller.text),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => widget.onOk(_controller.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purpleDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Ok'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RenameBoardModal extends StatefulWidget {
  final String currentName;
  final void Function(String?) onOk;
  final VoidCallback onClose;

  const _RenameBoardModal({
    required this.currentName,
    required this.onOk,
    required this.onClose,
  });

  @override
  State<_RenameBoardModal> createState() => _RenameBoardModalState();
}

class _RenameBoardModalState extends State<_RenameBoardModal> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const purpleDark = Color(0xFF4C1D95);
    return AlertDialog(
      title: const Text('Rename Board'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Board Name',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => widget.onOk(_controller.text),
      ),
      actions: [
        TextButton(
            onPressed: widget.onClose, child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => widget.onOk(_controller.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: purpleDark,
            foregroundColor: Colors.white,
          ),
          child: const Text('Ok'),
        ),
      ],
    );
  }
}

class _SuccessModal extends StatelessWidget {
  final VoidCallback onOk;

  const _SuccessModal({required this.onOk});

  @override
  Widget build(BuildContext context) {
    const purpleDark = Color(0xFF4C1D95);
    const lightBlue = Color(0xFF60A5FA);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFE9D5FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 44, color: lightBlue),
            ),
            const SizedBox(height: 20),
            const Text(
              'New Snaps Board Created!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "You can find this board created among all the boards.",
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onOk,
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Ok'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}