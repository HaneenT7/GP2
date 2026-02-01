class FolderFile {
  final String id;
  final String folderId;
  final String fileName;
  final String fileUrl;
  final int fileSize; // in bytes
  final DateTime uploadedAt;
  final String uploadedBy;

  FolderFile({
    required this.id,
    required this.folderId,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.uploadedAt,
    required this.uploadedBy,
  });

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'folderId': folderId,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
      'uploadedAt': uploadedAt.toIso8601String(),
      'uploadedBy': uploadedBy,
    };
  }

  // Create from Firestore document
  factory FolderFile.fromFirestore(String id, Map<String, dynamic> data) {
    return FolderFile(
      id: id,
      folderId: data['folderId'] ?? '',
      fileName: data['fileName'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      fileSize: data['fileSize'] ?? 0,
      uploadedAt: DateTime.parse(data['uploadedAt']),
      uploadedBy: data['uploadedBy'] ?? '',
    );
  }
}

