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
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1A73E8), // Google Blue
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1A73E8),
        brightness: Brightness.dark,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
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
    final theme = Theme.of(context);
    final inputFillColor = theme.colorScheme.onSurface.withOpacity(0.05);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CIRO Monitor', style: TextStyle(fontWeight: FontWeight.w500)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Report an Incident',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter details to analyze potential crises and coordinate responses.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
              ),
              const SizedBox(height: 32),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedZone,
                decoration: InputDecoration(
                  labelText: 'Zone',
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                icon: const Icon(Icons.arrow_drop_down),
                items: zones.map((zone) => DropdownMenuItem(value: zone, child: Text(zone))).toList(),
                onChanged: (val) => setState(() => selectedZone = val),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: InputDecoration(
                  labelText: 'Crisis Type',
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                icon: const Icon(Icons.arrow_drop_down),
                items: types.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (val) => setState(() => selectedType = val),
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/response');
                },
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Analyze Crisis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, '/map');
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('View Live Map', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.9),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: const GoogleMap(
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        initialCameraPosition: CameraPosition(
          target: LatLng(33.6844, 73.0479),
          zoom: 12.0,
        ),
      ),
    );
  }
}

class ResponseScreen extends StatelessWidget {
  const ResponseScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Results')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: colorScheme.onErrorContainer, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Detected Crisis',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(context, Icons.water_drop_outlined, 'Type', 'Urban Flooding'),
                  const SizedBox(height: 8),
                  _buildDetailRow(context, Icons.location_on_outlined, 'Location', 'G-10'),
                  const SizedBox(height: 8),
                  _buildDetailRow(context, Icons.priority_high, 'Severity', 'Level 4'),
                  const SizedBox(height: 8),
                  _buildDetailRow(context, Icons.verified_user_outlined, 'Confidence', '87%'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Recommended Actions',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildActionCard(
                    context: context,
                    title: 'Redirect traffic via alternate routes',
                    priorityText: 'P1',
                    priorityColor: Colors.red,
                    icon: Icons.alt_route,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context: context,
                    title: 'Dispatch emergency services',
                    priorityText: 'P2',
                    priorityColor: Colors.orange,
                    icon: Icons.emergency,
                  ),
                  const SizedBox(height: 12),
                  _buildActionCard(
                    context: context,
                    title: 'Send alerts to residents',
                    priorityText: 'P3',
                    priorityColor: Colors.green,
                    icon: Icons.notifications_active_outlined,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onErrorContainer.withOpacity(0.8)),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onErrorContainer.withOpacity(0.8),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onErrorContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String priorityText,
    required MaterialColor priorityColor,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.surface,
          child: Icon(icon, color: theme.colorScheme.onSurface.withOpacity(0.8)),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: priorityColor.withOpacity(isDark ? 0.3 : 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            priorityText,
            style: TextStyle(
              color: isDark ? priorityColor.shade200 : priorityColor.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
