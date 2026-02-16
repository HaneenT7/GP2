import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SnapData {
  final Uint8List bytes;
  Offset position;
  String? storageUrl; // Firebase Storage URL
  String? snapId; // Firestore document ID

  SnapData({
    required this.bytes,
    required this.position,
    this.storageUrl,
    this.snapId,
  });
}

class BoardDetailPage extends StatefulWidget {
  final String boardName;
  final VoidCallback onBack;

  const BoardDetailPage({
    super.key,
    required this.boardName,
    required this.onBack,
  });

  @override
  State<BoardDetailPage> createState() => _BoardDetailPageState();
}

class _BoardDetailPageState extends State<BoardDetailPage> {
  final List<SnapData> _snaps = [];
  int? _draggedIndex;
  final Random _random = Random();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isLoading = true;

  /// Firestore document IDs cannot contain /. Use a safe id for save/load.
  String get _boardDocId {
    final s = widget.boardName.trim().replaceAll(RegExp(r'[/\\]'), '_');
    return s.isEmpty ? 'board' : s;
  }

  @override
  void initState() {
    super.initState();
    _loadSnaps();
  }

  Future<void> _loadSnaps() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('Cannot load snaps: User not logged in');
      setState(() => _isLoading = false);
      return;
    }

    try {
      print('Loading snaps for board: ${widget.boardName} (docId: $_boardDocId)');
      final snapsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('boards')
          .doc(_boardDocId)
          .collection('snaps')
          .get();

      // Sort by createdAt if present so order is stable
      final docs = snapsSnapshot.docs.toList()
        ..sort((a, b) {
          final tA = a.data()['createdAt'] as Timestamp?;
          final tB = b.data()['createdAt'] as Timestamp?;
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tA.compareTo(tB);
        });

      print('Found ${docs.length} snaps in Firestore');
      final loadedSnaps = <SnapData>[];
      
      for (var doc in docs) {
        final data = doc.data();
        final storageUrl = data['storageUrl'] as String?;
        final imageBase64 = data['imageBase64'] as String?;
        final positionX = (data['positionX'] as num?)?.toDouble() ?? 50.0;
        final positionY = (data['positionY'] as num?)?.toDouble() ?? 50.0;

        Uint8List? bytes;

        // 1) Prefer image stored in Firestore (works without Storage rules)
        if (imageBase64 != null && imageBase64.isNotEmpty) {
          try {
            bytes = Uint8List.fromList(base64Decode(imageBase64));
            print('Loaded snap from Firestore (base64): ${doc.id}');
          } catch (e) {
            print('Error decoding base64 for snap ${doc.id}: $e');
          }
        }

        // 2) Otherwise try Storage URL
        if (bytes == null && storageUrl != null && storageUrl.isNotEmpty) {
          try {
            final ref = _storage.refFromURL(storageUrl);
            bytes = await ref.getData();
            if (bytes != null && bytes.isNotEmpty) {
              print('Loaded snap from Storage: ${doc.id}');
            }
          } catch (e) {
            print('Error loading from storage for snap ${doc.id}: $e');
          }
        }

        if (bytes != null && bytes.isNotEmpty) {
          loadedSnaps.add(SnapData(
            bytes: bytes,
            position: Offset(positionX, positionY),
            storageUrl: storageUrl,
            snapId: doc.id,
          ));
        }
      }

      print('Successfully loaded ${loadedSnaps.length} snaps');
      setState(() {
        _snaps.clear();
        _snaps.addAll(loadedSnaps);
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('Error loading snaps: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
      if (mounted) {
        final isPermissionDenied = e.toString().contains('permission-denied');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPermissionDenied
                  ? 'Database access denied. Publish Firestore rules in Firebase Console (see SNAPS_PERSISTENCE_README.md).'
                  : 'Error loading snaps: $e',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  /// Max size to store image as base64 in Firestore (doc limit ~1MB; base64 ~1.33x)
  static const int _maxBase64Bytes = 700000;

  Future<void> _saveSnapToFirestore(SnapData snap, {int? index}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // We need either storageUrl (from Storage) or we save image as base64 in Firestore
    final hasStorageUrl = snap.storageUrl != null && snap.storageUrl!.isNotEmpty;
    final canSaveBase64 = snap.bytes.length <= _maxBase64Bytes;

    if (!hasStorageUrl && !canSaveBase64) {
      print('Cannot save: image too large for Firestore fallback (${snap.bytes.length} bytes)');
      return;
    }

    try {
      final snapData = <String, dynamic>{
        'positionX': snap.position.dx,
        'positionY': snap.position.dy,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (hasStorageUrl) {
        snapData['storageUrl'] = snap.storageUrl;
      } else {
        // Fallback: store image in Firestore as base64 so it persists without Storage
        snapData['imageBase64'] = base64Encode(snap.bytes);
        snapData['storageUrl'] = null;
        print('Saving snap image in Firestore (base64, ${snap.bytes.length} bytes)');
      }

      String? docId;

      if (snap.snapId != null) {
        docId = snap.snapId;
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('boards')
            .doc(_boardDocId)
            .collection('snaps')
            .doc(snap.snapId)
            .update(snapData);
        print('Updated snap in Firestore: $docId');
      } else {
        final docRef = await _firestore
            .collection('users')
            .doc(userId)
            .collection('boards')
            .doc(_boardDocId)
            .collection('snaps')
            .add(snapData);
        docId = docRef.id;
        print('Created snap in Firestore: $docId');

        final snapIndex = index ?? _snaps.indexOf(snap);
        if (snapIndex != -1 && snapIndex < _snaps.length) {
          setState(() {
            _snaps[snapIndex] = SnapData(
              bytes: _snaps[snapIndex].bytes,
              position: _snaps[snapIndex].position,
              storageUrl: _snaps[snapIndex].storageUrl,
              snapId: docId,
            );
          });
        }
      }
    } catch (e) {
      print('Error saving snap to Firestore: $e');
      if (mounted) {
        final isPermissionDenied = e.toString().contains('permission-denied');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPermissionDenied
                  ? 'Cannot save to database. Publish Firestore rules in Firebase Console (see SNAPS_PERSISTENCE_README.md).'
                  : 'Error saving snap: $e',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<String?> _uploadImageToStorage(Uint8List bytes) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('❌ Cannot upload: User not logged in');
      return null;
    }

    if (bytes.isEmpty) {
      print('❌ Cannot upload: Image bytes are empty');
      return null;
    }

    try {
      print('📤 Starting upload...');
      print('   User ID: $userId');
      print('   Board Name: ${widget.boardName}');
      print('   Image size: ${bytes.length} bytes');
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Sanitize board name for file path
      final sanitizedBoardName = widget.boardName.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
      final fileName = '${userId}_${sanitizedBoardName}_$timestamp.jpg';
      final storagePath = 'snaps/$sanitizedBoardName/$fileName';
      
      print('   Storage path: $storagePath');
      
      final ref = _storage.ref().child(storagePath);
      
      print('   Uploading to Firebase Storage...');
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': userId,
            'boardName': widget.boardName,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      print('   Upload complete! Bytes uploaded: ${snapshot.bytesTransferred}');
      
      // Get download URL
      final downloadUrl = await ref.getDownloadURL();
      print('   Download URL: $downloadUrl');
      
      return downloadUrl;
    } catch (e, stackTrace) {
      print('❌ Error uploading image to storage: $e');
      print('   Stack trace: $stackTrace');
      return null;
    }
  }

  Future<void> _deleteSnapFromFirestore(SnapData snap) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null || snap.snapId == null) return;

    try {
      // Delete from Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('boards')
          .doc(_boardDocId)
          .collection('snaps')
          .doc(snap.snapId)
          .delete();

      // Delete from Storage if URL exists
      if (snap.storageUrl != null) {
        try {
          final ref = _storage.refFromURL(snap.storageUrl!);
          await ref.delete();
        } catch (e) {
          print('Error deleting from storage: $e');
        }
      }
    } catch (e) {
      print('Error deleting snap from Firestore: $e');
    }
  }

  void _showUploadModal() {
    showDialog(
      context: context,
      builder: (context) => _UploadImageModal(
        onClose: () => Navigator.pop(context),
        onSave: (imageBytes) async {
          print('💾 Save button clicked, bytes: ${imageBytes.length}');
          Navigator.pop(context);

          if (imageBytes.isEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invalid image. Please select a different file.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          // 1. Add snap to board immediately so it always shows
          final newSnap = SnapData(
            bytes: imageBytes,
            position: Offset(
              50.0 + _random.nextDouble() * 200,
              50.0 + _random.nextDouble() * 200,
            ),
          );
          final newIndex = _snaps.length;
          setState(() {
            _snaps.add(newSnap);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Snap added to board!'),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          }

          // 2. Upload to Firebase in background (for persistence)
          final userId = _auth.currentUser?.uid;
          if (userId == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sign in to save snaps across devices.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }

          try {
            print('📤 Uploading to Storage...');
            final storageUrl = await _uploadImageToStorage(imageBytes);

            // Update the snap with storage URL if upload succeeded
            if (storageUrl != null && newIndex < _snaps.length) {
              setState(() {
                _snaps[newIndex] = SnapData(
                  bytes: _snaps[newIndex].bytes,
                  position: _snaps[newIndex].position,
                  storageUrl: storageUrl,
                );
              });
            }

            // Always persist to Firestore: with storageUrl if we have it, else as base64
            if (newIndex < _snaps.length) {
              await _saveSnapToFirestore(_snaps[newIndex], index: newIndex);
            }

            if (mounted) {
              if (storageUrl != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Snap saved to cloud!'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Snap saved on this device (image stored in cloud).'),
                    duration: Duration(seconds: 3),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          } catch (e) {
            print('Upload error: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Snap on board; cloud save failed: $e'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showManageSnapsModal() {
    // Store current snaps data before opening modal - create a copy
    final snapsCopy = <SnapData>[];
    for (final snap in _snaps) {
      snapsCopy.add(SnapData(
        bytes: snap.bytes,
        position: snap.position,
        storageUrl: snap.storageUrl,
        snapId: snap.snapId,
      ));
    }
    final originalBytes = snapsCopy.map((s) => s.bytes).toList();
    
    showDialog(
      context: context,
      builder: (context) => _ManageSnapsModal(
        snaps: originalBytes,
        onReorder: (newOrder) async {
          setState(() {
            // Build new list maintaining positions based on original order
            final newSnaps = <SnapData>[];
            
            for (int newIndex = 0; newIndex < newOrder.length; newIndex++) {
              final bytes = newOrder[newIndex];
              // Find the original index of this bytes
              int? originalIndex;
              for (int i = 0; i < originalBytes.length; i++) {
                // Compare byte arrays by content
                if (originalBytes[i].length == bytes.length) {
                  bool matches = true;
                  for (int j = 0; j < bytes.length; j++) {
                    if (originalBytes[i][j] != bytes[j]) {
                      matches = false;
                      break;
                    }
                  }
                  if (matches) {
                    originalIndex = i;
                    break;
                  }
                }
              }
              
              if (originalIndex != null && originalIndex < snapsCopy.length) {
                // Use the snap from the original position (preserves storageUrl and snapId)
                newSnaps.add(snapsCopy[originalIndex]);
              } else {
                // Fallback: create new snap (shouldn't happen normally)
                // This would need to be uploaded to storage first
                print('Warning: Could not find original snap for reordered item');
                newSnaps.add(SnapData(
                  bytes: bytes,
                  position: Offset(
                    50.0 + _random.nextDouble() * 200,
                    50.0 + _random.nextDouble() * 200,
                  ),
                ));
              }
            }
            
            _snaps.clear();
            _snaps.addAll(newSnaps);
          });
          
          // Save all snaps to Firestore to update positions
          for (int i = 0; i < _snaps.length; i++) {
            await _saveSnapToFirestore(_snaps[i], index: i);
          }
        },
        onDelete: (index) async {
          if (index >= 0 && index < _snaps.length) {
            final snap = _snaps[index];
            await _deleteSnapFromFirestore(snap);
            setState(() {
              _snaps.removeAt(index);
            });
          }
        },
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const headerColor = Color(0xFF6A4E88); // Muted purple (banner)
    const corkColor = Color(0xFFC4A574);
    const frameColor = Color(0xFF8B6914);

    return Container(
      color: const Color(0xFFEAE1ED), // Very light purple (pastel lavender)
      child: Column(
        children: [
          _buildHeader(headerColor, context),
          Expanded(
            child: _buildCorkboard(corkColor, frameColor, context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color headerColor, BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: headerColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back),
            color: Colors.white,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Center(
              child: Text(
                '${widget.boardName} Snaps Board',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _showUploadModal,
            icon: const Icon(Icons.upload),
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _snaps.isEmpty ? null : _showManageSnapsModal,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEAE1ED), // Very light purple
              foregroundColor: headerColor,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.settings_outlined, size: 20),
            label: const Text('Manage Snaps'),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildCorkboard(Color corkColor, Color frameColor, BuildContext ctx) {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: corkColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: frameColor, width: 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          fit: StackFit.expand, // Ensure stack fills the container
          children: [
            // Background texture - always fills the board
            Positioned.fill(
              child: CustomPaint(
                painter: _CorkTexturePainter(),
              ),
            ),
            // Content layer - consistent sizing
            Positioned.fill(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _snaps.isEmpty
                      ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 64,
                              color: Colors.black26,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Add your snaps here',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black45,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload photos to pin on your board',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black38,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _showUploadModal,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4C1D95),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.upload, size: 20),
                              label: const Text('Upload Snaps'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final boardWidth = constraints.maxWidth > 0 
                              ? constraints.maxWidth 
                              : MediaQuery.of(context).size.width - 48;
                          final boardHeight = MediaQuery.of(context).size.height * 0.7;
                          
                          return SizedBox(
                            width: boardWidth,
                            height: boardHeight,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ..._snaps.asMap().entries.map((e) {
                                  return _buildPositionedSnapCard(e.key, e.value, boardWidth, boardHeight);
                                }),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(Uint8List bytes, int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _FullScreenImageViewer(
        imageBytes: bytes,
        onDelete: () async {
          Navigator.pop(context);
          final snap = _snaps[index];
          await _deleteSnapFromFirestore(snap);
          setState(() {
            _snaps.removeAt(index);
          });
        },
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildPositionedSnapCard(int index, SnapData snapData, double boardWidth, double boardHeight) {
    return Positioned(
      left: snapData.position.dx.clamp(0.0, boardWidth - 140),
      top: snapData.position.dy.clamp(0.0, boardHeight - 140),
      child: _buildDraggableSnapCard(index, snapData, boardWidth, boardHeight),
    );
  }

  Widget _buildDraggableSnapCard(int index, SnapData snapData, double boardWidth, double boardHeight) {
    final isDragging = _draggedIndex == index;
    
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          snapData.position += details.delta;
          // Keep snap within board bounds
          snapData.position = Offset(
            snapData.position.dx.clamp(0.0, boardWidth - 140),
            snapData.position.dy.clamp(0.0, boardHeight - 140),
          );
        });
      },
      onPanStart: (_) {
        setState(() {
          _draggedIndex = index;
        });
      },
      onPanEnd: (_) async {
        setState(() {
          _draggedIndex = null;
        });
        // Save position change to Firestore
        final snapIndex = _snaps.indexOf(snapData);
        if (snapIndex != -1) {
          await _saveSnapToFirestore(snapData, index: snapIndex);
        }
      },
      onTap: () {
        if (!isDragging) {
          _showFullScreenImage(snapData.bytes, index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.identity()..scale(isDragging ? 1.1 : 1.0),
        child: _buildSnapCardContent(snapData.bytes, index: index, isDragging: isDragging),
      ),
    );
  }

  Widget _buildSnapCardContent(Uint8List bytes, {bool isDragging = false, int? index}) {
    return GestureDetector(
      onTap: () {
        if (!isDragging && index != null) {
          _showFullScreenImage(bytes, index);
        }
      },
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Image.memory(
                bytes,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
              ),
              // Drag handle indicator
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.drag_handle,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CorkTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB8956A)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 50; i++) {
      final x = (i * 37) % size.width.toInt() + 0.0;
      final y = (i * 53) % size.height.toInt() + 0.0;
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FullScreenImageViewer extends StatelessWidget {
  final Uint8List imageBytes;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const _FullScreenImageViewer({
    required this.imageBytes,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Full screen image with zoom/pan support
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(
                imageBytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  size: 100,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Close button (top left)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  // Delete button (top right)
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Delete Snap'),
                          content: const Text('Are you sure you want to delete this snap?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                onDelete();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete, color: Colors.white, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.7),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageSnapsModal extends StatefulWidget {
  final List<Uint8List> snaps;
  final Future<void> Function(List<Uint8List> newOrder) onReorder;
  final void Function(int index) onDelete;
  final VoidCallback onClose;

  const _ManageSnapsModal({
    required this.snaps,
    required this.onReorder,
    required this.onDelete,
    required this.onClose,
  });

  @override
  State<_ManageSnapsModal> createState() => _ManageSnapsModalState();
}

class _ManageSnapsModalState extends State<_ManageSnapsModal> {
  late List<Uint8List> _reorderedSnaps;

  @override
  void initState() {
    super.initState();
    _reorderedSnaps = List.from(widget.snaps);
  }

  @override
  Widget build(BuildContext context) {
    const purpleDark = Color(0xFF4C1D95);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Manage Snaps',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Reorderable list
            Flexible(
              child: _reorderedSnaps.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No snaps to manage',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ReorderableListView(
                      padding: const EdgeInsets.all(16),
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }
                          final item = _reorderedSnaps.removeAt(oldIndex);
                          _reorderedSnaps.insert(newIndex, item);
                        });
                      },
                      children: _reorderedSnaps.asMap().entries.map((entry) {
                        final index = entry.key;
                        final bytes = entry.value;
                        return _ReorderableSnapItem(
                          key: ValueKey('snap_$index'),
                          index: index,
                          imageBytes: bytes,
                          onDelete: () {
                            setState(() {
                              _reorderedSnaps.removeAt(index);
                              widget.onDelete(index);
                            });
                            if (_reorderedSnaps.isEmpty) {
                              widget.onClose();
                            }
                          },
                        );
                      }).toList(),
                    ),
            ),
            // Footer buttons
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onClose,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      await widget.onReorder(_reorderedSnaps);
                      widget.onClose();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Snaps reordered successfully!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purpleDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Save Order'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReorderableSnapItem extends StatelessWidget {
  final int index;
  final Uint8List imageBytes;
  final VoidCallback onDelete;

  const _ReorderableSnapItem({
    required Key key,
    required this.index,
    required this.imageBytes,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            imageBytes,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
          ),
        ),
        title: Text('Snap ${index + 1}'),
        subtitle: const Text('Drag to reorder'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Delete Snap'),
                    content: const Text('Are you sure you want to delete this snap?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          onDelete();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Icon(Icons.drag_handle, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _UploadImageModal extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(Uint8List imageBytes) onSave;

  const _UploadImageModal({
    required this.onClose,
    required this.onSave,
  });

  @override
  State<_UploadImageModal> createState() => _UploadImageModalState();
}

class _UploadImageModalState extends State<_UploadImageModal> {
  List<int>? _selectedBytes;
  String? _selectedFileName;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _showImageSourceDialog() async {
    if (!mounted) return;
    
    final source = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF4C1D95)),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF4C1D95)),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.folder, color: Color(0xFF4C1D95)),
              title: const Text('File Browser'),
              subtitle: const Text('Browse files (drag & drop from PC first)', 
                style: TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Color(0xFF4C1D95)),
              title: const Text('Use Demo Image'),
              onTap: () => Navigator.pop(context, 'demo'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source != null) {
      switch (source) {
        case 'camera':
          await _pickFromCamera();
          break;
        case 'gallery':
          await _pickFromGallery();
          break;
        case 'file':
          await _chooseImage();
          break;
        case 'demo':
          await _useDemoImage();
          break;
      }
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.camera);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedBytes = bytes;
          _selectedFileName = image.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedBytes = bytes;
          _selectedFileName = image.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting from gallery: $e')),
        );
      }
    }
  }

  Future<void> _useDemoImage() async {
    try {
      // Load the app logo as a demo image
      final ByteData data = await rootBundle.load('assets/images/watad_logo.png');
      final bytes = data.buffer.asUint8List();
      setState(() {
        _selectedBytes = bytes;
        _selectedFileName = 'watad_logo.png';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demo image loaded! You can use this for testing.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading demo image: $e')),
        );
      }
    }
  }

  Future<void> _chooseImage() async {
    try {
      print('📸 Opening file picker...');
      
      // Use FileType.any to allow browsing ALL files (works better for accessing files from PC)
      // Users can drag & drop files from their computer into the emulator, then browse to them
      FilePickerResult? result;
      
      if (Platform.isAndroid) {
        // On Android, use custom type to allow browsing files
        // Users can drag & drop files from PC into emulator, then browse to them
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'],
          allowMultiple: false,
          withData: false, // Read from path on Android - allows accessing files from PC
        );
      } else {
        // On iOS/Web, use image type
        result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: kIsWeb || Platform.isIOS,
        );
      }
      
      print('📸 File picker result: ${result != null ? "selected" : "cancelled"}');
      
      if (result == null) {
        print('📸 User cancelled file picker');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No image selected'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        return;
      }

      if (result.files.isEmpty) {
        print('📸 No files in result');
        return;
      }

      final file = result.files.single;
      print('📸 Selected file: ${file.name}, path: ${file.path}, bytes: ${file.bytes != null ? file.bytes!.length : "null"}');
      
      List<int>? bytes;

      // Try to get bytes from file picker result first
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        bytes = file.bytes!.toList();
        print('📸 Using bytes from file picker: ${bytes.length} bytes');
      } 
      // If no bytes, try reading from file path (Android/Desktop)
      else if (file.path != null && file.path!.isNotEmpty) {
        try {
          print('📸 Reading from file path: ${file.path}');
          final xFile = XFile(file.path!);
          bytes = await xFile.readAsBytes();
          print('📸 Read ${bytes.length} bytes from file path');
        } catch (e) {
          print('📸 Error reading from path: $e');
          // Try using File directly as fallback
          try {
            final fileObj = File(file.path!);
            if (await fileObj.exists()) {
              bytes = await fileObj.readAsBytes();
              print('📸 Read ${bytes.length} bytes using File');
            }
          } catch (e2) {
            print('📸 Error with File: $e2');
          }
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        print('📸 Successfully loaded image: ${bytes.length} bytes');
        setState(() {
          _selectedBytes = bytes;
          _selectedFileName = file.name;
        });
      } else {
        print('📸 Failed to load image bytes');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not load image. Please try another file.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('📸 Error selecting image: $e');
      print('📸 Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const purpleDark = Color(0xFF4C1D95);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Upload an image to Add to Your Board',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Supported formats: JPG, PNG, JPEG',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              if (Platform.isAndroid)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '💡 Tip: Drag & drop images from your PC into the emulator, then use File Browser',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        height: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: _selectedBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                Uint8List.fromList(_selectedBytes!),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            )
                          : Icon(
                              Icons.landscape,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton(
                        onPressed: _showImageSourceDialog,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text('Choose Image', style: TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedFileName ?? 'No Image Chosen',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedBytes != null && _selectedBytes!.isNotEmpty
                    ? () {
                        widget.onSave(Uint8List.fromList(_selectedBytes!));
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleDark,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
