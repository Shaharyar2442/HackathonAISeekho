import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const CIROApp());
}

class CIROApp extends StatelessWidget {
  const CIROApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CIRO',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/map': (context) => const MapScreen(),
        '/response': (context) => const ResponseScreen(),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? selectedZone = 'G-10';
  String? selectedType = 'Flood';
  
  final List<String> zones = ['G-10', 'G-11', 'F-8', 'I-8', 'Blue Area'];
  final List<String> types = ['Flood', 'Accident', 'Power Outage', 'Fire', 'Traffic'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CIRO Crisis Monitor')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Report Text',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedZone,
              decoration: const InputDecoration(labelText: 'Zone', border: OutlineInputBorder()),
              items: zones.map((zone) => DropdownMenuItem(value: zone, child: Text(zone))).toList(),
              onChanged: (val) => setState(() => selectedZone = val),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedType,
              decoration: const InputDecoration(labelText: 'Crisis Type', border: OutlineInputBorder()),
              items: types.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (val) => setState(() => selectedType = val),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/response');
              },
              child: const Text('Analyze Crisis', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/map');
              },
              child: const Text('View Map', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crisis Map')),
      body: const GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(33.6844, 73.0479),
          zoom: 12.0,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pop(context),
        child: const Icon(Icons.arrow_back),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}

class ResponseScreen extends StatelessWidget {
  const ResponseScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detected Crisis')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              color: Colors.red.shade900.withOpacity(0.4),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detected Situation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    SizedBox(height: 8),
                    Text('Type: Urban Flooding', style: TextStyle(fontSize: 16)),
                    Text('Location: G-10', style: TextStyle(fontSize: 16)),
                    Text('Severity: 4', style: TextStyle(fontSize: 16)),
                    Text('Confidence: 87%', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Recommended Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  _buildActionItem('Redirect traffic via alternate routes', 'P1', Colors.red),
                  _buildActionItem('Dispatch emergency services', 'P2', Colors.orange),
                  _buildActionItem('Send alerts to residents', 'P3', Colors.green),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(String description, String priority, Color color) {
    return Card(
      child: ListTile(
        leading: Chip(
          label: Text(priority, style: const TextStyle(color: Colors.white)),
          backgroundColor: color,
        ),
        title: Text(description),
      ),
    );
  }
}
