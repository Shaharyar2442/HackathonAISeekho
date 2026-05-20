import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Mobile-side Firestore service.
/// Handles loading historical crisis events and saving user reports.
/// All operations fail silently if Firestore is not configured.
class FirestoreService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static const String _crisisCollection = 'crisis_events';

  /// Notifier that fires when Firestore data changes (for reactive UI).
  static final historicalSignalsLoaded = ValueNotifier<int>(0);

  /// Load recent crisis events from Firestore (for cold start map population).
  /// Returns a list of signal maps compatible with ApiService.liveSignals format.
  static Future<List<Map<String, dynamic>>> loadRecentCrisisEvents({int limit = 20}) async {
    try {
      final snapshot = await _db
          .collection(_crisisCollection)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final d = doc.data();
        return {
          'text': '[History] ${d['crisis_type'] ?? 'Crisis'} @ ${d['location'] ?? ''}',
          'crisis_type': d['crisis_type'] ?? 'Unknown',
          'location': d['location'] ?? 'Unknown',
          'severity': d['severity'] ?? 1,
          'lat': d['lat'],
          'lng': d['lng'],
          'full_crisis': {
            'type': d['crisis_type'] ?? 'Unknown',
            'location': d['location'] ?? 'Unknown',
            'severity': d['severity'] ?? 1,
            'confidence': d['confidence'] ?? 0.0,
            'reasoning': d['reasoning'] ?? '',
          },
          'actions': List<dynamic>.from(d['actions'] ?? []),
          'agentTrace': List<dynamic>.from(d['agent_trace'] ?? []),
          'source': d['source'] ?? 'history',
          'firestoreId': doc.id,
        };
      }).toList();
    } catch (e) {
      debugPrint('[Firestore] loadRecentCrisisEvents failed: $e');
      return [];
    }
  }

  /// Save a user-reported incident to Firestore immediately on submission.
  static Future<String?> saveUserReport({
    required String text,
    required String location,
    required String crisisType,
    double? lat,
    double? lng,
  }) async {
    try {
      final ref = await _db.collection(_crisisCollection).add({
        'crisis_type': crisisType,
        'location': location,
        'severity': null,     // will be updated by backend detect response
        'confidence': null,
        'reasoning': null,
        'lat': lat,
        'lng': lng,
        'text': text,
        'source': 'user_report',
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('[Firestore] Saved user report: ${ref.id}');
      return ref.id;
    } catch (e) {
      debugPrint('[Firestore] saveUserReport failed: $e');
      return null;
    }
  }

  /// Update an existing Firestore document after backend analysis completes.
  static Future<void> updateCrisisWithAnalysis({
    required String docId,
    required Map<String, dynamic> detectedCrisis,
    required List<dynamic> actions,
    required List<dynamic> agentTrace,
  }) async {
    try {
      await _db.collection(_crisisCollection).doc(docId).update({
        'severity': detectedCrisis['severity'],
        'confidence': detectedCrisis['confidence'],
        'reasoning': detectedCrisis['reasoning'],
        'actions': actions,
        'agent_trace': agentTrace,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[Firestore] updateCrisisWithAnalysis failed: $e');
    }
  }

  /// Update severity in Firestore when a user takes an action.
  static Future<void> updateSeverity(String location, int newSeverity) async {
    try {
      final snapshot = await _db
          .collection(_crisisCollection)
          .where('location', isEqualTo: location)
          .limit(5)
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.update({'severity': newSeverity});
      }
    } catch (e) {
      debugPrint('[Firestore] updateSeverity failed: $e');
    }
  }
}
