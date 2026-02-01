import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/folder_file.dart';

class FileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Collection reference
  CollectionReference get _filesCollection => _firestore.collection('folderFiles');

  // Get all files in a folder
  Stream<List<FolderFile>> getFiles(String folderId) {
    return _filesCollection
        .where('folderId', isEqualTo: folderId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FolderFile.fromFirestore(doc.id, doc.data() as Map<String, dynamic>))
            .toList());
  }

  // Upload a file to Firebase Storage and save metadata to Firestore
  // Supports both web (Uint8List) and mobile (File or Uint8List)
  Future<FolderFile> uploadFile(String folderId, dynamic fileData, String fileName, int fileSize) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Create a unique file path
      final fileExtension = fileName.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageFileName = '${currentUserId}_${timestamp}.$fileExtension';
      final storagePath = 'courseFolders/$folderId/$storageFileName';

      // Upload to Firebase Storage
      final storageRef = _storage.ref().child(storagePath);
      UploadTask uploadTask;

      // Determine if fileData is File or Uint8List
      if (fileData is File) {
        // Mobile: fileData is File
        final metadata = SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'originalFileName': fileName,
            'uploadedBy': currentUserId!,
          },
        );
        uploadTask = storageRef.putFile(fileData, metadata);
      } else if (fileData is Uint8List) {
        // Web or mobile with bytes: fileData is Uint8List
        final metadata = SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'originalFileName': fileName,
            'uploadedBy': currentUserId!,
          },
        );
        uploadTask = storageRef.putData(fileData, metadata);
      } else {
        throw Exception('Invalid file data type: ${fileData.runtimeType}. Expected File or Uint8List.');
      }

      // Monitor upload progress and wait for completion
      TaskSnapshot snapshot;
      try {
        // Wait for upload to complete
        snapshot = await uploadTask;
        
        // Check if upload was successful
        if (snapshot.state != TaskState.success) {
          throw Exception('Upload failed. State: ${snapshot.state}');
        }
      } on FirebaseException catch (firebaseError) {
        // Handle Firebase-specific errors
        if (firebaseError.code == 'object-not-found') {
          throw Exception('Storage configuration error. Please verify:\n1. Firebase Storage is enabled in Firebase Console\n2. Storage bucket "gp2-watad.firebasestorage.app" exists\n3. Storage security rules allow writes\n\nGo to: Firebase Console > Storage > Get Started (if not enabled)\nThen: Storage > Rules and add rules to allow authenticated uploads.\n\nError code: ${firebaseError.code}');
        } else if (firebaseError.code == 'permission-denied' || firebaseError.code == 'unauthorized') {
          throw Exception('Permission denied. Please check Firebase Storage security rules allow authenticated users to write files.\n\nGo to: Firebase Console > Storage > Rules\n\nError code: ${firebaseError.code}');
        }
        throw Exception('Firebase Storage error: ${firebaseError.code} - ${firebaseError.message}');
      } catch (uploadError) {
        // Re-throw with more context
        final errorString = uploadError.toString();
        if (errorString.contains('object-not-found')) {
          throw Exception('Storage configuration error. Please verify:\n1. Firebase Storage is enabled in Firebase Console\n2. Storage bucket exists and is properly configured\n3. Storage security rules allow uploads\n\nGo to: Firebase Console > Storage > Get Started (if not enabled)\nThen: Storage > Rules\n\nOriginal error: $uploadError');
        }
        throw Exception('Upload task failed: $uploadError');
      }

      // Verify the file exists before getting URL
      try {
        // Get download URL
        final downloadUrl = await snapshot.ref.getDownloadURL();

        // Save metadata to Firestore
        final folderFile = FolderFile(
          id: '', // Will be set by Firestore
          folderId: folderId,
          fileName: fileName,
          fileUrl: downloadUrl,
          fileSize: fileSize,
          uploadedAt: DateTime.now(),
          uploadedBy: currentUserId!,
        );

        final docRef = await _filesCollection.add(folderFile.toFirestore());
        return folderFile.copyWith(id: docRef.id);
      } catch (urlError) {
        // If getting URL fails, try to delete the uploaded file
        try {
          await snapshot.ref.delete();
        } catch (_) {
          // Ignore deletion errors
        }
        throw Exception('Failed to get download URL: $urlError');
      }
    } catch (e) {
      // Re-throw with more context
      if (e.toString().contains('object-not-found')) {
        throw Exception('Storage object not found. This may indicate a permissions issue. Please check Firebase Storage rules. Original error: $e');
      }
      throw Exception('Failed to upload file: $e');
    }
  }

  // Delete a file
  Future<void> deleteFile(FolderFile file) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Delete from Storage
      final storageRef = _storage.refFromURL(file.fileUrl);
      await storageRef.delete();

      // Delete from Firestore
      await _filesCollection.doc(file.id).delete();
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

}

// Extension to add copyWith to FolderFile
extension FolderFileExtension on FolderFile {
  FolderFile copyWith({String? id}) {
    return FolderFile(
      id: id ?? this.id,
      folderId: folderId,
      fileName: fileName,
      fileUrl: fileUrl,
      fileSize: fileSize,
      uploadedAt: uploadedAt,
      uploadedBy: uploadedBy,
    );
  }
}

