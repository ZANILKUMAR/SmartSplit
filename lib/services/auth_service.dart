import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/UserModel.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

class AuthService {
  // Debug flag
  static const bool _debug = true;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  UserModel? get currentUser {
    final User? firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    
    // Return a basic UserModel from Firebase Auth
    // Full user data should be fetched from Firestore when needed
    return UserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? '',
      phoneNumber: firebaseUser.phoneNumber ?? '',
    );
  }

  void _debugPrint(String message) {
    if (_debug) {
      print('AuthService: $message');
    }
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      _debugPrint('Error fetching user data: $e');
      return null;
    }
  }

  // Sign in with email and password
  Future<UserModel?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      _debugPrint('Attempting login for email: $email');
      
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        _debugPrint('Login successful for: $email');
        
        // Fetch complete user data from Firestore
        final userData = await getUserData(userCredential.user!.uid);
        return userData;
      }
      
      throw AuthException('Login failed');
    } on FirebaseAuthException catch (e) {
      _debugPrint('Login error: ${e.code}');
      
      switch (e.code) {
        case 'user-not-found':
          throw AuthException('No user found with this email');
        case 'wrong-password':
          throw AuthException('Invalid password');
        case 'invalid-email':
          throw AuthException('Invalid email format');
        case 'user-disabled':
          throw AuthException('This account has been disabled');
        case 'too-many-requests':
          throw AuthException('Too many attempts. Please try again later');
        default:
          throw AuthException('Login failed: ${e.message}');
      }
    } catch (e) {
      _debugPrint('Login error: $e');
      throw AuthException('An error occurred during login');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _debugPrint('User signed out successfully');
    } catch (e) {
      _debugPrint('Sign out error: $e');
      throw AuthException('Failed to sign out');
    }
  }

  // Password reset
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _debugPrint('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      _debugPrint('Password reset error: ${e.code}');
      
      switch (e.code) {
        case 'user-not-found':
          throw AuthException('No user found with this email');
        case 'invalid-email':
          throw AuthException('Invalid email format');
        default:
          throw AuthException('Failed to send reset email: ${e.message}');
      }
    } catch (e) {
      _debugPrint('Password reset error: $e');
      throw AuthException('An error occurred during password reset');
    }
  }

  // Check if email is already in use
  Future<bool> isEmailInUse(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      _debugPrint('Email check error: $e');
      return false;
    }
  }

  // Register with email and password
  Future<UserModel?> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
    String phoneNumber,
  ) async {
    try {
      _debugPrint('Attempting registration for email: $email');

      // Create user in Firebase Authentication
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final User firebaseUser = userCredential.user!;
        
        // Update display name in Firebase Auth
        await firebaseUser.updateDisplayName(name);

        // Create UserModel
        final UserModel newUser = UserModel(
          uid: firebaseUser.uid,
          email: email,
          name: name,
          phoneNumber: phoneNumber,
        );

        // Store additional user data in Firestore
        await _firestore.collection('users').doc(firebaseUser.uid).set(
          newUser.toJson(),
        );

        _debugPrint('Registration successful for: $email');
        _debugPrint('User stored in Firestore with UID: ${firebaseUser.uid}');

        return newUser;
      }
      
      throw AuthException('Registration failed');
    } on FirebaseAuthException catch (e) {
      _debugPrint('Registration error: ${e.code}');
      
      switch (e.code) {
        case 'email-already-in-use':
          throw AuthException('Email already in use');
        case 'invalid-email':
          throw AuthException('Invalid email format');
        case 'weak-password':
          throw AuthException('Password is too weak');
        case 'operation-not-allowed':
          throw AuthException('Email/password accounts are not enabled');
        default:
          throw AuthException('Registration failed: ${e.message}');
      }
    } catch (e) {
      _debugPrint('Registration error: $e');
      throw AuthException('An error occurred during registration');
    }
  }

  // Listen to auth state changes
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}