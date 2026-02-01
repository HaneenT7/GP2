import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/course_folder.dart';

class FolderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Collection reference
  CollectionReference get _foldersCollection => _firestore.collection('courseFolders');

  // Get all folders for current user
  Stream<List<CourseFolder>> getFolders() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _foldersCollection
        .where('userId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CourseFolder.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Create a new folder
  Future<String> createFolder(String name, String color) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Check for duplicate folder name
    final existingFolders = await _foldersCollection
        .where('userId', isEqualTo: currentUserId)
        .where('name', isEqualTo: name)
        .get();

    if (existingFolders.docs.isNotEmpty) {
      throw Exception('A folder with this name already exists');
    }

    final folder = CourseFolder(
      id: '', // Will be set by Firestore
      name: name,
      userId: currentUserId!,
      createdAt: DateTime.now(),
      color: color,
    );

    final docRef = await _foldersCollection.add(folder.toFirestore());
    return docRef.id;
  }

  // Update folder name
  Future<void> updateFolder(String folderId, String newName) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Check for duplicate folder name (excluding current folder)
    final existingFolders = await _foldersCollection
        .where('userId', isEqualTo: currentUserId)
        .where('name', isEqualTo: newName)
        .get();

    if (existingFolders.docs.isNotEmpty && existingFolders.docs.first.id != folderId) {
      throw Exception('A folder with this name already exists');
    }

    await _foldersCollection.doc(folderId).update({
      'name': newName,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // Delete folder
  Future<void> deleteFolder(String folderId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Delete all files in the folder first
    final filesSnapshot = await _firestore
        .collection('folderFiles')
        .where('folderId', isEqualTo: folderId)
        .get();

    final batch = _firestore.batch();
    for (var doc in filesSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Delete the folder
    await _foldersCollection.doc(folderId).delete();
  }

  // Get folder by ID
  Future<CourseFolder?> getFolderById(String folderId) async {
    final doc = await _foldersCollection.doc(folderId).get();
    if (doc.exists) {
      return CourseFolder.fromFirestore(doc.id, doc.data() as Map<String, dynamic>);
    }
    return null;
  }
}

