import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://10.188.25.60:8000/api';

  static Future<Map<String, dynamic>> submitAndAnalyze(String text, String location, String type, {double? lat, double? lng}) async {
    // Map dropdown UI values to backend expected keys
    String backendType = type.toLowerCase();
    if (backendType == 'power outage') backendType = 'outage';

    final signalData = {
      'text': text,
      'location': location,
      'crisis_type': backendType,
      'source': 'user_report',
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    if (lat != null) signalData['lat'] = lat;
    if (lng != null) signalData['lng'] = lng;

    // 1. Ingest Signal
    final ingestRes = await http.post(
      Uri.parse('$baseUrl/ingest'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'signals': [signalData]
      }),
    );

    if (ingestRes.statusCode != 200 && ingestRes.statusCode != 201) {
      throw Exception('Failed to ingest signal (Status: ${ingestRes.statusCode})');
    }

    // 2. Detect Crisis & Get Agent Trace
    // According to the backend design, /api/detect returns the full agent trace, the detected crisis, and actions.
    final detectRes = await http.post(
      Uri.parse('$baseUrl/detect'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'signals': [signalData]
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
