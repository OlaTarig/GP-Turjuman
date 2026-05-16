import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Global ValueNotifier for AuthService (optional - for state management)
ValueNotifier<AuthService> authService = ValueNotifier(AuthService());

class AuthService {
  final FirebaseAuth firebaseAuth;

  AuthService({FirebaseAuth? firebaseAuth})
      : firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  // Get current user
  User? get currentUser => firebaseAuth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign up / Create account with email and password
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    return await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }

  // Send password reset email
  Future<void> resetPassword({
    required String email,
  }) async {
    await firebaseAuth.sendPasswordResetEmail(email: email);
  }

  // Update user display name
  Future<void> updateUsername({
    required String username,
  }) async {
    await currentUser!.updateDisplayName(username);
  }

  // Delete account (requires re-authentication)
  Future<void> deleteAccount({
    required String email,
    required String password,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.delete();
    await firebaseAuth.signOut();
  }

  // Change password (requires re-authentication)
  Future<void> resetPasswordFromCurrentPassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.updatePassword(newPassword);
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    if (currentUser != null && !currentUser!.emailVerified) {
      await currentUser!.sendEmailVerification();
    }
  }

  // Reload user to get updated info (like email verification status)
  Future<void> reloadUser() async {
    await currentUser?.reload();
  }

  // Check if email is verified
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  // Get user email
  String? get userEmail => currentUser?.email;

  // Get user display name
  String? get userDisplayName => currentUser?.displayName;

  // Get user ID
  String? get userId => currentUser?.uid;
}