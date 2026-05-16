import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Using 10.0.2.2 which is the special alias to your host loopback interface from the Android emulator.
  // If testing on a physical device, this should be your computer's local network IP (e.g., 192.168.x.x).
  static const String baseUrl = 'http://10.188.25.60:8000/api';

  static Future<Map<String, dynamic>> submitAndAnalyze(String text, String location, String type) async {
    final signalData = {
      'text': text,
      'location': location,
      'crisis_type': type,
      'severity': 3, // Defaulting severity for raw ingestion
      'source': 'user_report',
      'timestamp': DateTime.now().toIso8601String(),
    };

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
      throw Exception('Failed to analyze crisis (Status: ${detectRes.statusCode})');
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
