import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'api_service.dart';

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
  final TextEditingController _reportController = TextEditingController();
  String? selectedZone = 'G-10';
  String? selectedType = 'Flood';
  bool _isLoading = false;
  
  final List<String> zones = ['G-10', 'G-11', 'F-8', 'I-8', 'Blue Area'];
  final List<String> types = ['Flood', 'Accident', 'Power Outage', 'Fire', 'Traffic'];

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

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
                controller: _reportController,
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
                onPressed: _isLoading ? null : () async {
                  setState(() => _isLoading = true);
                  try {
                    // Send to backend via ApiService
                    final result = await ApiService.submitAndAnalyze(
                      _reportController.text.isEmpty ? 'Emergency situation observed.' : _reportController.text,
                      selectedZone ?? 'G-10',
                      selectedType ?? 'Flood',
                    );
                    if (!mounted) return;
                    Navigator.pushNamed(context, '/response', arguments: result);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: theme.colorScheme.error,
                      ),
                    );
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
                icon: _isLoading 
                    ? Container(width: 20, height: 20, margin: const EdgeInsets.only(right: 8), child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.analytics_outlined),
                label: Text(_isLoading ? 'Analyzing...' : 'Analyze Crisis', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
    final Map<String, dynamic>? data = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final crisis = data?['detectedCrisis'] ?? data?['detected_crisis'] ?? {
      'type': 'Unknown',
      'location': 'Unknown',
      'severity': 1,
      'confidence': 0.0,
      'reasoning': 'No data available'
    };

    final rawActions = data?['actions'] ?? [];
    final agentTrace = data?['agentTrace'] ?? data?['agent_trace'] ?? [];
    
    // Safely parse values
    final double confidence = (crisis['confidence'] as num?)?.toDouble() ?? 0.0;
    final int severity = (crisis['severity'] as num?)?.toInt() ?? 1;

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Results')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                        Expanded(
                          child: Text(
                            'Detected: ${crisis['type']}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colorScheme.onErrorContainer,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(context, Icons.location_on_outlined, 'Location', '${crisis['location']}'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.priority_high, size: 20, color: theme.colorScheme.onErrorContainer.withOpacity(0.8)),
                        const SizedBox(width: 12),
                        Text('Severity:', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onErrorContainer.withOpacity(0.8))),
                        const SizedBox(width: 8),
                        Row(
                          children: List.generate(5, (index) => Icon(
                            index < severity ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 20,
                          )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.verified_user_outlined, size: 20, color: theme.colorScheme.onErrorContainer.withOpacity(0.8)),
                        const SizedBox(width: 12),
                        Text('Confidence:', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onErrorContainer.withOpacity(0.8))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: confidence,
                              minHeight: 8,
                              backgroundColor: colorScheme.onErrorContainer.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onErrorContainer),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${(confidence * 100).toStringAsFixed(0)}%', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Reasoning: ${crisis['reasoning']}',
                      style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer.withOpacity(0.9), fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Recommended Actions',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (rawActions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("No actions recommended yet."),
                )
              else
                ...List.generate(rawActions.length, (index) {
                  final action = rawActions[index];
                  final p = (action['priority'] as num?)?.toInt() ?? 3;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _buildActionCard(
                      context: context,
                      title: action['description'] ?? action['type'] ?? 'Unknown Action',
                      priorityText: 'P$p',
                      priorityColor: p == 1 ? Colors.red : (p == 2 ? Colors.orange : Colors.green),
                      icon: p == 1 ? Icons.alt_route : (p == 2 ? Icons.emergency : Icons.notifications_active_outlined),
                    ),
                  );
                }),
              
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest ?? theme.colorScheme.surfaceVariant,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  title: Text(
                    'View Agent Reasoning Trace',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  leading: const Icon(Icons.memory),
                  children: [
                    if (agentTrace.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("No trace available."),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: List.generate(agentTrace.length, (index) {
                            final trace = agentTrace[index];
                            final steps = trace['reasoning_steps'] as List<dynamic>? ?? [];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16.0),
                              color: theme.colorScheme.surface,
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trace['agent_name'] ?? 'Unknown Agent',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...List.generate(steps.length, (sIndex) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${sIndex + 1}. ', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
                                            Expanded(child: Text(steps[sIndex].toString(), style: TextStyle(color: theme.colorScheme.onSurface))),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      )
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
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
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Simulation initiated...')));
              },
              child: const Text('Simulate Action'),
            ),
          ),
        ),
      ),
    );
  }
}
