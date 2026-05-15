import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uni_transit/core/util/logger.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign Up
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? rollNo,
    String? regNo,
    String? department,
  }) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Store user role and info in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'name': name,
        'email': email,
        'role': role, // 'Student' or 'Driver'
        'rollNo': rollNo,
        'regNo': regNo,
        'department': department,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "An error occurred during sign up.";
    } catch (e) {
      rethrow;
    }
  }

  // Login
  Future<UserCredential?> login({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "An error occurred during login.";
    } catch (e) {
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get User Role with Fallback
  Future<String?> getUserRole(String uid) async {
    try {
      // 1. Check primary 'users' collection
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data.containsKey('role')) {
          return data['role'] as String?;
        }
      }

      // 2. Fallback: Check 'drivers' collection
      DocumentSnapshot driverDoc = await _firestore.collection('drivers').doc(uid).get();
      if (driverDoc.exists) {
        AppLogger.info("Role found via drivers collection fallback for UID: $uid");
        return 'Driver';
      }

      AppLogger.warning("No role found for UID: $uid in either users or drivers collection");
    } catch (e) {
      AppLogger.error("Error getting user role: $e");
    }
    return null;
  }

  // Update Name
  Future<void> updateName(String uid, String newName) async {
    await _firestore.collection('users').doc(uid).update({'name': newName});
    // Update Firebase Auth Display Name as well
    await _auth.currentUser?.updateDisplayName(newName);
  }

  // Complete/Update Profile
  Future<void> updateProfile({
    required String uid,
    String? profileImageUrl,
    String? rollNo,
    String? regNo,
    String? department,
    String? semester,
  }) async {
    final Map<String, dynamic> data = {};
    if (profileImageUrl != null) data['profileImage'] = profileImageUrl;
    if (rollNo != null) data['rollNo'] = rollNo;
    if (regNo != null) data['regNo'] = regNo;
    if (department != null) data['department'] = department;
    if (semester != null) data['semester'] = semester;

    if (data.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(data);
    }
  }

  // Change Password
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No user logged in");

    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );

    // Re-authenticate
    await user.reauthenticateWithCredential(cred);

    // Update Password
    await user.updatePassword(newPassword);
  }

  // Get Current User
  User? get currentUser => _auth.currentUser;

  // Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? "An error occurred while sending reset email.";
    } catch (e) {
      rethrow;
    }
  }

  // Auth State Changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
