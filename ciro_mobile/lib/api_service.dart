import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://10.188.25.60:8000/api';

  static final List<Map<String, dynamic>> locallyReportedSignals = [];
  static final List<Map<String, dynamic>> liveSignals = [];
  static int _localCounter = 0;

  /// Notifies listeners when locallyReportedSignals changes (new insert or update).
  static final signalsChanged = ValueNotifier<int>(0);
  static void _notifySignals() => signalsChanged.value++;

<<<<<<< Updated upstream
=======
  /// Decrements severity by 1 (min 1) for all signals matching [location].
  /// Called when a user takes an action on an incident.
  static void reduceSeverity(String location) {
    bool changed = false;
    final locLower = location.toLowerCase();
    for (final list in [locallyReportedSignals, liveSignals]) {
      for (final s in list) {
        final sLoc = (s['location']?.toString() ?? '').toLowerCase();
        if (sLoc == locLower || sLoc.contains(locLower) || locLower.contains(sLoc)) {
          final cur = (s['severity'] as num?)?.toInt() ?? 1;
          if (cur > 1) {
            s['severity'] = cur - 1;
            // Also update full_crisis if present
            if (s['full_crisis'] != null) {
              (s['full_crisis'] as Map<String, dynamic>)['severity'] = cur - 1;
            }
            changed = true;
          }
        }
      }
    }
    if (changed) _notifySignals();
  }

>>>>>>> Stashed changes
  /// Map UI type strings → canonical backend values expected by the pipeline agents.
  static String _normalizeType(String type) {
    switch (type.toLowerCase()) {
      case 'flood':
      case 'urban flooding':
        return 'Urban Flooding';
      case 'fire':
      case 'fire hazard':
        return 'Fire Hazard';
      case 'power outage':
      case 'power infrastructure':
        return 'Power Infrastructure';
      case 'accident':
      case 'severe accident':
        return 'Severe Accident';
      case 'traffic':
      case 'traffic gridlock':
        return 'Traffic Gridlock';
      default:
        return type;
    }
  }

  static Future<Map<String, dynamic>> submitAndAnalyze(
    String text,
    String location,
    String type, {
    double? lat,
    double? lng,
  }) async {
    final String backendType = _normalizeType(type);

    final Map<String, dynamic> signalData = {
      'text': text,
      'location': location,
      'crisis_type': backendType,
      'source': 'user_report',
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (lat != null) signalData['lat'] = lat;
    if (lng != null) signalData['lng'] = lng;

    // Assign a number immediately so it shows on the map feed
    _localCounter++;
    signalData['number'] = _localCounter;

    // Insert into local list so the map displays it right away (pending backend)
    locallyReportedSignals.insert(0, Map<String, dynamic>.from(signalData));
    _notifySignals();

    // Send only the primary signal — reduces Gemini token usage and avoids rate limits.
    // The Sensor Agent can normalise a single clear report effectively.
    final signals = [signalData];

    // Detect Crisis & Get Agent Trace (ingest is redundant — detect processes directly)
    final detectRes = await http.post(
      Uri.parse('$baseUrl/detect'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'signals': signals}),
    );

    if (detectRes.statusCode != 200) {
      final body = detectRes.body;
      throw Exception('Failed to report crisis (${detectRes.statusCode}): $body');
    }

    final data = jsonDecode(detectRes.body);

    // Update the local signal with the full backend response so map can show details
    final detectedCrisis = data['detected_crisis'];
    if (detectedCrisis != null && locallyReportedSignals.isNotEmpty) {
      final idx = locallyReportedSignals.indexWhere((s) => s['number'] == _localCounter);
      if (idx >= 0) {
        locallyReportedSignals[idx]['full_crisis'] = detectedCrisis;
        locallyReportedSignals[idx]['actions'] = data['actions_recommended'] ?? [];
        locallyReportedSignals[idx]['agentTrace'] = data['agent_trace'] ?? [];
        locallyReportedSignals[idx]['severity'] = detectedCrisis['severity'];
        _notifySignals();
      }
    }

    return data as Map<String, dynamic>;
  }

  static Future<void> reduceSeverity(String location) async {
    bool changed = false;
    int targetSeverity = 1;
    for (final list in [locallyReportedSignals, liveSignals]) {
      for (final s in list) {
        if (s['location'] == location) {
          final cur = (s['severity'] as num?)?.toInt() ?? 1;
          if (cur > 1) {
            final newSeverity = cur - 1;
            s['severity'] = newSeverity;
            targetSeverity = newSeverity;
            // Also update full_crisis if present
            if (s['full_crisis'] != null) {
              (s['full_crisis'] as Map<String, dynamic>)['severity'] = newSeverity;
            }
            changed = true;
          }
        }
      }
    }
    if (changed) {
      _notifySignals();
      // Notify backend to update persistence
      try {
        await http.post(
          Uri.parse('$baseUrl/reduce_severity'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'location': location,
            'new_severity': targetSeverity,
          }),
        );
      } catch (e) {
        debugPrint('Failed to update backend severity: $e');
      }
    }
  }

  static Future<Map<String, dynamic>> simulateAction(String actionType, String actionId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/simulate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action_id': actionId,
        'action_type': actionType,
      }),
    );
    if (res.statusCode != 200) throw Exception('Failed to simulate (${res.statusCode}): ${res.body}');
    return jsonDecode(res.body);
  }
}
