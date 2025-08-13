import 'package:firebase_auth/firebase_auth.dart';
import 'package:codecraft_project/models/user.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AppUser? _userFromFirebaseUser(User? user) {
    return user != null ? AppUser(uid: user.uid) : null;
  }

  // Auth change user stream
  Stream<AppUser?> get user {
    return _auth.authStateChanges().map(_userFromFirebaseUser);
  }

  // Sign in anonymously
  Future<AppUser?> signInAnonim() async {
    try {
      UserCredential result = await _auth.signInAnonymously();
      User? user = result.user;
      return _userFromFirebaseUser(user);
    } catch (e) {
      print('Error signing in anonymously: $e');
      return null;
    }
  }

  // Sign in with email and password
  Future<AppUser?> signInWithAnEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      return _userFromFirebaseUser(user);
    } catch (e) {
      return null;
    }
  }

  // Register with email and password
  Future<AppUser?> registerWithAnEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      if (user != null) {
        // Create user_progress doc with default values
        await FirebaseFirestore.instance
            .collection('user_progress')
            .doc(user.uid)
            .set({
              'highestLevel': 1,
              'username': 'Username',
              'totalAttempt': 0,         
              'totalTimeSpent': 0,    
            });
      }
      return _userFromFirebaseUser(user);
    } on FirebaseAuthException catch (e) {
      print('Registration error [${e.code}]: ${e.message}');
      return null;
    }
  }

  Future<AppUser?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // User canceled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = result.user;

      // Create user_progress doc if new user
      if (result.additionalUserInfo?.isNewUser ?? false) {
        await FirebaseFirestore.instance
            .collection('user_progress')
            .doc(user!.uid)
            .set({
              'highestLevel': 1,
              'username': user.displayName ?? 'Username',
              'totalAttempt': 0,       
              'totalTimeSpent': 0,    
            });
      }

      return _userFromFirebaseUser(user);
    } catch (e) {
      print('Google sign-in error: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut();
    } catch (e) {
      print('Sign out error: $e');
      return;
    }
  }
}
