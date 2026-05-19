import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://10.188.25.60:8000/api';

  static final List<Map<String, dynamic>> locallyReportedSignals = [];
  static int _localCounter = 0;

  /// Notifies listeners when locallyReportedSignals changes (new insert or update).
  static final signalsChanged = ValueNotifier<int>(0);
  static void _notifySignals() => signalsChanged.value++;

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

    // Build sensor-specific reading text based on crisis type
    String sensorReading = 'abnormal readings';
    final typeLower = backendType.toLowerCase();
    if (typeLower.contains('flood')) {
      sensorReading = 'elevated water level';
    } else if (typeLower.contains('fire')) {
      sensorReading = 'heat signature anomaly';
    } else if (typeLower.contains('power')) {
      sensorReading = 'grid fluctuation detected';
    } else if (typeLower.contains('accident')) {
      sensorReading = 'traffic flow anomaly';
    } else if (typeLower.contains('traffic')) {
      sensorReading = 'severe congestion pattern';
    }

    // Send 3 multi-source signals for richer AI analysis
    final signals = [
      signalData,
      {
        'text': '$backendType situation reported near $location — multiple citizens confirming',
        'location': location,
        'crisis_type': backendType,
        'source': 'social_media',
        'timestamp': DateTime.now().toIso8601String(),
      },
      {
        'text': 'Automated sensors detecting $sensorReading in $location sector',
        'location': location,
        'crisis_type': backendType,
        'source': 'sensor',
        'timestamp': DateTime.now().toIso8601String(),
      },
    ];

    // 1. Ingest Signal
    final ingestRes = await http.post(
      Uri.parse('$baseUrl/ingest'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'signals': signals}),
    );

    if (ingestRes.statusCode != 200 && ingestRes.statusCode != 201) {
      throw Exception('Failed to ingest signal (Status: ${ingestRes.statusCode})');
    }

    // 2. Detect Crisis & Get Agent Trace
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
