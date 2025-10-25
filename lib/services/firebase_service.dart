import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../firebase_options.dart';
import 'database_service.dart';
import 'security_service.dart';
import 'language_service.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Firebase instances
  late FirebaseAuth _auth;
  late FirebaseFirestore _firestore;
  late FirebaseCrashlytics _crashlytics;
  late FirebaseAnalytics _analytics;

  // Services
  final DatabaseService _databaseService = DatabaseService.instance;
  final SecurityService _securityService = SecurityService();
  final LanguageService _languageService = LanguageService.instance;

  // Stream controllers for real-time updates
  final StreamController<User?> _userController = StreamController<User?>.broadcast();
  final StreamController<bool> _syncStatusController = StreamController<bool>.broadcast();

  // Properties
  bool _isInitialized = false;
  bool _isSyncing = false;
  Timer? _autoSyncTimer;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;
  bool get isUserSignedIn => _isInitialized && FirebaseAuth.instance.currentUser != null;
  User? get currentUser => _isInitialized ? FirebaseAuth.instance.currentUser : null;
  String? get userId => currentUser?.uid;
  
  Stream<User?> get authStateChanges => _userController.stream;
  Stream<bool> get syncStatusStream => _syncStatusController.stream;

  /// Initialize Firebase services
  Future<void> initialize() async {
    try {
      // Initialize Firebase Core
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Initialize Firebase App Check
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
        androidProvider: AndroidProvider.debug,
        appleProvider: AppleProvider.debug,
      );
      
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _crashlytics = FirebaseCrashlytics.instance;
      _analytics = FirebaseAnalytics.instance;

      // Set up Crashlytics
      await _setupCrashlytics();

      // Listen to auth state changes
      _auth.authStateChanges().listen((User? user) {
        _userController.add(user);
        _onAuthStateChanged(user);
      });

      // Configure Firestore settings
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      _isInitialized = true;
      debugPrint('Firebase services initialized successfully');

      // Start auto-sync if user is signed in
      if (isUserSignedIn) {
        _startAutoSync();
      }

    } catch (e, st) {
      debugPrint('Error initializing Firebase: $e');
      // Guard against late initialization issues if Crashlytics isn't ready yet
      try {
        await FirebaseCrashlytics.instance.recordError(e, st);
      } catch (_) {}
      rethrow;
    }
  }

  /// Setup Crashlytics
  Future<void> _setupCrashlytics() async {
    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = (errorDetails) {
      _crashlytics.recordFlutterFatalError(errorDetails);
    };
  }

  /// Handle authentication state changes
  void _onAuthStateChanged(User? user) {
    if (user != null) {
      _startAutoSync();
      _trackUserLogin();
    } else {
      _stopAutoSync();
    }
  }

  /// Sign in with email and password
  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    try {
      _analytics.logLogin(loginMethod: 'email');
      
      final credential = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password,
      );
      
      if (credential.user != null) {
        await _onSignInSuccess(credential.user!);
      }
      
      return credential;
    } on FirebaseAuthException catch (e) {
      await _crashlytics.recordError(e, StackTrace.current);
      throw _getAuthErrorMessage(e.code);
    } catch (e) {
      await _crashlytics.recordError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Create account with email and password
  Future<UserCredential?> createAccountWithEmailPassword(
    String email, 
    String password, 
    String displayName,
  ) async {
    try {
      _analytics.logSignUp(signUpMethod: 'email');
      
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password,
      );
      
      if (credential.user != null) {
        // Update profile
        await credential.user!.updateDisplayName(displayName);
        
        // Create user document
        await _createUserDocument(credential.user!);
        
        await _onSignInSuccess(credential.user!);
      }
      
      return credential;
    } on FirebaseAuthException catch (e) {
      await _crashlytics.recordError(e, StackTrace.current);
      throw _getAuthErrorMessage(e.code);
    } catch (e) {
      await _crashlytics.recordError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      _stopAutoSync();
      await _auth.signOut();
      _analytics.logEvent(name: 'user_logout');
    } catch (e) {
      await _crashlytics.recordError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _analytics.logEvent(name: 'password_reset_sent');
    } on FirebaseAuthException catch (e) {
      await _crashlytics.recordError(e, StackTrace.current);
      throw _getAuthErrorMessage(e.code);
    } catch (e) {
      await _crashlytics.recordError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Actions after successful sign in
  Future<void> _onSignInSuccess(User user) async {
    try {
      // Set user properties for analytics
      await _analytics.setUserId(id: user.uid);
      await _analytics.setUserProperty(name: 'user_type', value: 'authenticated');
      
      // Start data sync
      await syncDataToCloud();
      
      debugPrint('User signed in successfully: ${user.email}');
    } catch (e) {
      debugPrint('Error in sign in success handler: $e');
    }
  }

  /// Create user document in Firestore
  Future<void> _createUserDocument(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    
    await userRef.set({
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName ?? 'Carbon Tracker User',
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'settings': {
        'language': _languageService.isEnglish ? 'en' : 'tr',
        'notifications': true,
        'autoBackup': true,
      },
      'stats': {
        'totalActivities': 0,
        'totalCO2': 0.0,
        'lastSyncAt': FieldValue.serverTimestamp(),
      }
    });
  }

  /// Sync local data to cloud
  Future<void> syncDataToCloud() async {
    if (!_isInitialized || !isUserSignedIn || _isSyncing) return;

    try {
      _isSyncing = true;
      _syncStatusController.add(true);

      final userId = _auth.currentUser!.uid;
      
      // Get all local data
      final activities = await _databaseService.getAllActivities();
      final dashboardStats = await _databaseService.getDashboardStats();
      
      final batch = _firestore.batch();
      
      // Update user stats
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'stats.totalActivities': activities.length,
        'stats.totalCO2': dashboardStats['totalCarbon'] ?? 0.0,
        'stats.lastSyncAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      // Sync activities
      for (final activity in activities) {
        final activityRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('activities')
            .doc('activity_${activity['id']}');
            
        // Encrypt sensitive data
        final encryptedData = await _encryptActivityData(activity);
        
        batch.set(activityRef, {
          ...encryptedData,
          'syncedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      
      _analytics.logEvent(
        name: 'data_sync_completed',
        parameters: {'activities_count': activities.length},
      );
      
      debugPrint('Data synced to cloud successfully: ${activities.length} activities');
      
    } catch (e) {
      debugPrint('Error syncing data to cloud: $e');
      await _crashlytics.recordError(e, StackTrace.current);
      rethrow;
    } finally {
      _isSyncing = false;
      _syncStatusController.add(false);
    }
  }

  /// Sync cloud data to local
  Future<void> syncDataFromCloud() async {
    if (!isUserSignedIn) return;

    try {
      final userId = _auth.currentUser!.uid;
      
      // Get activities from cloud
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('activities')
          .get();

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final decryptedData = await _decryptActivityData(data);
          
          // Check if activity exists locally
          try {
            final activityId = int.tryParse(decryptedData['id'].toString()) ?? 0;
            final existingActivity = await _databaseService.getActivityById(activityId);
            
            if (existingActivity == null) {
              // Insert new activity
              await _databaseService.insertActivity(decryptedData);
              debugPrint('Synced activity from cloud: ${decryptedData['id']}');
            }
          } catch (activityError) {
            debugPrint('Could not process activity ${doc.id}: $activityError');
          }
        } catch (e) {
          debugPrint('Error processing activity ${doc.id}: $e');
        }
      }
      
      _analytics.logEvent(
        name: 'data_restore_completed',
        parameters: {'activities_count': snapshot.docs.length},
      );
      
      debugPrint('Data restored from cloud: ${snapshot.docs.length} activities');
      
    } catch (e) {
      debugPrint('Error syncing data from cloud: $e');
      await _crashlytics.recordError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Encrypt activity data before cloud storage
  Future<Map<String, dynamic>> _encryptActivityData(Map<String, dynamic> data) async {
    final encryptedData = Map<String, dynamic>.from(data);
    
    // Encrypt sensitive fields
    final sensitiveFields = ['description', 'notes', 'location'];
    for (final field in sensitiveFields) {
      if (data[field] != null) {
        encryptedData[field] = await _securityService.encryptData(data[field].toString());
      }
    }
    
    return encryptedData;
  }

  /// Decrypt activity data from cloud storage
  Future<Map<String, dynamic>> _decryptActivityData(Map<String, dynamic> data) async {
    final decryptedData = Map<String, dynamic>.from(data);
    
    // Decrypt sensitive fields
    final sensitiveFields = ['description', 'notes', 'location'];
    for (final field in sensitiveFields) {
      if (data[field] != null) {
        decryptedData[field] = await _securityService.decryptData(data[field].toString());
      }
    }
    
    return decryptedData;
  }

  /// Start auto-sync timer
  void _startAutoSync() {
    _stopAutoSync(); // Stop existing timer
    
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      if (isUserSignedIn && !_isSyncing) {
        syncDataToCloud();
      }
    });
  }

  /// Stop auto-sync timer
  void _stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Track user login for analytics
  void _trackUserLogin() {
    _analytics.logEvent(
      name: 'user_authenticated',
      parameters: {
        'method': 'email',
        'language': _languageService.isEnglish ? 'en' : 'tr',
      },
    );
  }

  /// Get user-friendly auth error messages
  String _getAuthErrorMessage(String errorCode) {
    final isEnglish = _languageService.isEnglish;
    
    switch (errorCode) {
      case 'user-not-found':
        return isEnglish ? 'No user found with this email address.' : 'Bu e-posta adresi ile kayıtlı kullanıcı bulunamadı.';
      case 'wrong-password':
        return isEnglish ? 'Incorrect password.' : 'Yanlış şifre.';
      case 'email-already-in-use':
        return isEnglish ? 'This email address is already registered.' : 'Bu e-posta adresi zaten kayıtlı.';
      case 'weak-password':
        return isEnglish ? 'Password is too weak.' : 'Şifre çok zayıf.';
      case 'invalid-email':
        return isEnglish ? 'Invalid email address.' : 'Geçersiz e-posta adresi.';
      case 'network-request-failed':
        return isEnglish ? 'Network error. Please check your connection.' : 'Ağ hatası. Bağlantınızı kontrol edin.';
      case 'too-many-requests':
        return isEnglish ? 'Too many attempts. Please try again later.' : 'Çok fazla deneme. Lütfen daha sonra tekrar deneyin.';
      default:
        return isEnglish ? 'Authentication error: $errorCode' : 'Kimlik doğrulama hatası: $errorCode';
    }
  }

  /// Get backup status for user
  Future<Map<String, dynamic>> getBackupStatus() async {
    if (!isUserSignedIn) return {'hasBackup': false};

    try {
      final userId = _auth.currentUser!.uid;
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) return {'hasBackup': false};
      
      final data = userDoc.data()!;
      final stats = data['stats'] as Map<String, dynamic>? ?? {};
      
      return {
        'hasBackup': true,
        'totalActivities': stats['totalActivities'] ?? 0,
        'totalCO2': stats['totalCO2'] ?? 0.0,
        'lastSyncAt': stats['lastSyncAt'],
        'accountCreated': data['createdAt'],
      };
    } catch (e) {
      await _crashlytics.recordError(e, StackTrace.current);
      return {'hasBackup': false, 'error': e.toString()};
    }
  }

  /// Delete user account and all data
  Future<void> deleteAccount() async {
    if (!isUserSignedIn) return;

    try {
      final userId = _auth.currentUser!.uid;
      
      // Delete user data from Firestore
      final batch = _firestore.batch();
      
      // Delete all activities
      final activitiesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('activities')
          .get();
      
      for (final doc in activitiesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete user document
      batch.delete(_firestore.collection('users').doc(userId));
      
      await batch.commit();
      
      // Delete Firebase Auth account
      await _auth.currentUser!.delete();
      
      _analytics.logEvent(name: 'account_deleted');
      
    } catch (e) {
      await _crashlytics.recordError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Dispose resources
  void dispose() {
    _stopAutoSync();
    _userController.close();
    _syncStatusController.close();
  }
}