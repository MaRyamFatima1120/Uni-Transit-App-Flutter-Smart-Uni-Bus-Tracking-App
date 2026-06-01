/// Model representing a user profile stored in Firestore.
/// Provides type-safe access to user data across the app.
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'Student', 'Driver', or 'Admin'
  final String? rollNo;
  final String? regNo;
  final String? department;
  final String? semester;
  final String? profileImage;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.rollNo,
    this.regNo,
    this.department,
    this.semester,
    this.profileImage,
  });

  /// Creates a UserModel from a Firestore document map.
  /// Backward-compatible: handles both 'profileImage' and 'profileImageUrl' keys.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? 'User',
      email: map['email'] ?? '',
      role: map['role'] ?? 'Student',
      rollNo: map['rollNo'],
      regNo: map['regNo'],
      department: map['department'],
      semester: map['semester'],
      profileImage: map['profileImage'] ?? map['profileImageUrl'],
    );
  }

  /// Converts to Map for Firestore writes.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      if (rollNo != null) 'rollNo': rollNo,
      if (regNo != null) 'regNo': regNo,
      if (department != null) 'department': department,
      if (semester != null) 'semester': semester,
      if (profileImage != null) 'profileImage': profileImage,
    };
  }

  bool get isStudent => role == 'Student';
  bool get isDriver => role == 'Driver';
  bool get isAdmin => role == 'Admin';

  /// Whether the user has a profile image URL set.
  bool get hasProfileImage =>
      profileImage != null && profileImage!.isNotEmpty;

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    String? rollNo,
    String? regNo,
    String? department,
    String? semester,
    String? profileImage,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      rollNo: rollNo ?? this.rollNo,
      regNo: regNo ?? this.regNo,
      department: department ?? this.department,
      semester: semester ?? this.semester,
      profileImage: profileImage ?? this.profileImage,
    );
  }
}
