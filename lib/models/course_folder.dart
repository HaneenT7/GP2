class CourseFolder {
  final String id;
  final String name;
  final String userId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String color; // Hex color code for folder display

  CourseFolder({
    required this.id,
    required this.name,
    required this.userId,
    required this.createdAt,
    this.updatedAt,
    required this.color,
  });

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'color': color,
    };
  }

  // Create from Firestore document
  factory CourseFolder.fromFirestore(String id, Map<String, dynamic> data) {
    return CourseFolder(
      id: id,
      name: data['name'] ?? '',
      userId: data['userId'] ?? '',
      createdAt: DateTime.parse(data['createdAt']),
      updatedAt: data['updatedAt'] != null ? DateTime.parse(data['updatedAt']) : null,
      color: data['color'] ?? '#FFD700', // Default yellow
    );
  }

  // Create a copy with updated fields
  CourseFolder copyWith({
    String? id,
    String? name,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? color,
  }) {
    return CourseFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      color: color ?? this.color,
    );
  }
}

