import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get firestore => FirebaseFirestore.instance;

  static Future<void> initialize() async {
    await Firebase.initializeApp();
    await _initializeAppCheck();
    await _configureAuth();
    await _configureFirestore();
  }

  static Future<void> _initializeAppCheck() async {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode 
        ? AndroidProvider.debug 
        : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode 
        ? AppleProvider.debug 
        : AppleProvider.deviceCheck,
    );
  }

  static Future<void> _configureAuth() async {
    auth.setSettings(
      appVerificationDisabledForTesting: kDebugMode,
      forceRecaptchaFlow: !kDebugMode,
    );
  }

  static Future<void> _configureFirestore() async {
    if (kDebugMode) {
      firestore.useFirestoreEmulator('localhost', 8080);
    }
    
    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }
}