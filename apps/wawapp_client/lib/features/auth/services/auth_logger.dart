import 'dart:convert';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> logAuthStart(String phoneNumber, String eventType) async {
    final event = {
      'timestamp': DateTime.now().toIso8601String(),
      'level': 'INFO',
      'event': 'auth_start',
      'phoneNumber': phoneNumber,
      'metadata': {'flow': eventType},
    };
    
    developer.log(jsonEncode(event), name: 'AuthLogger');
    await _logToFirestore('auth_start', phoneNumber, event['metadata'] as Map<String, dynamic>);
  }

  static Future<void> logAuthSuccess(String userId, String method) async {
    final event = {
      'timestamp': DateTime.now().toIso8601String(),
      'level': 'INFO',
      'event': 'auth_success',
      'userId': userId,
      'metadata': {'method': method},
    };
    
    developer.log(jsonEncode(event), name: 'AuthLogger');
    await _logToFirestore('auth_success', userId, event['metadata'] as Map<String, dynamic>);
  }

  static Future<void> logAuthFail(String phoneNumber, String error, int attemptNumber) async {
    final event = {
      'timestamp': DateTime.now().toIso8601String(),
      'level': 'ERROR',
      'event': 'auth_fail',
      'phoneNumber': phoneNumber,
      'metadata': {
        'error': error,
        'attemptNumber': attemptNumber.toString(),
      },
    };
    
    developer.log(jsonEncode(event), name: 'AuthLogger');
    await _logToFirestore('auth_fail', phoneNumber, event['metadata'] as Map<String, dynamic>);
  }

  static Future<void> logLockoutTriggered(String phoneNumber, Duration lockoutDuration) async {
    final event = {
      'timestamp': DateTime.now().toIso8601String(),
      'level': 'WARN',
      'event': 'lockout_triggered',
      'phoneNumber': phoneNumber,
      'metadata': {
        'lockoutDurationMinutes': lockoutDuration.inMinutes.toString(),
      },
    };
    
    developer.log(jsonEncode(event), name: 'AuthLogger');
    await _logToFirestore('lockout_triggered', phoneNumber, event['metadata'] as Map<String, dynamic>);
  }

  static Future<void> _logToFirestore(String eventType, String identifier, Map<String, dynamic> metadata) async {
    try {
      await _firestore.collection('auth_events').add({
        'eventType': eventType,
        'identifier': identifier,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
    } catch (e) {
      // Silent fail for logging
    }
  }
}