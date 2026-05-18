import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://10.188.25.60:8000/api';

  static final List<Map<String, dynamic>> locallyReportedSignals = [];

  static Future<Map<String, dynamic>> submitAndAnalyze(String text, String location, String type, {double? lat, double? lng}) async {
    // Send the crisis type as-is — backend expects full names like "Urban Flooding"
    final String backendType = type;

    final Map<String, dynamic> signalData = {
      'text': text,
      'location': location,
      'crisis_type': backendType,
      'source': 'user_report',
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    if (lat != null) signalData['lat'] = lat;
    if (lng != null) signalData['lng'] = lng;

    locallyReportedSignals.insert(0, signalData);

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
      body: jsonEncode({
        'signals': signals
      }),
    );

    if (ingestRes.statusCode != 200 && ingestRes.statusCode != 201) {
      throw Exception('Failed to ingest signal (Status: ${ingestRes.statusCode})');
    }

    // 2. Detect Crisis & Get Agent Trace
    final detectRes = await http.post(
      Uri.parse('$baseUrl/detect'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'signals': signals
      }),
    );

    if (detectRes.statusCode != 200) {
      throw Exception('Failed to report crisis (Status: ${detectRes.statusCode})');
    }

    final data = jsonDecode(detectRes.body);
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
    if (res.statusCode != 200) throw Exception('Failed to simulate');
    return jsonDecode(res.body);
  }
}
