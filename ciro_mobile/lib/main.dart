import 'dart:async';
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
        '/': (context) => const MainScreen(),
        '/response': (context) => const ResponseScreen(),
        '/simulate': (context) => const ActionSimulationScreen(),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    MapScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Report Incident',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Live Map',
          ),
        ],
      ),
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

    final inputDecorationTheme = InputDecorationTheme(
      filled: true,
      fillColor: inputFillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('CIRO Monitor', style: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.primary)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Report an Incident',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter details to analyze potential crises and coordinate responses.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
              ),
              const SizedBox(height: 32),
              Text(
                'Description',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reportController,
                decoration: InputDecoration(
                  hintText: 'Enter incident details...',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              Text(
                'Zone',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  return DropdownMenu<String>(
                    width: constraints.maxWidth,
                    initialSelection: selectedZone,
                    inputDecorationTheme: inputDecorationTheme,
                    menuStyle: MenuStyle(
                      shape: MaterialStateProperty.all(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    dropdownMenuEntries: zones.map((zone) => DropdownMenuEntry(value: zone, label: zone)).toList(),
                    onSelected: (val) => setState(() => selectedZone = val),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Crisis Type',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  return DropdownMenu<String>(
                    width: constraints.maxWidth,
                    initialSelection: selectedType,
                    inputDecorationTheme: inputDecorationTheme,
                    menuStyle: MenuStyle(
                      shape: MaterialStateProperty.all(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    dropdownMenuEntries: types.map((type) => DropdownMenuEntry(value: type, label: type)).toList(),
                    onSelected: (val) => setState(() => selectedType = val),
                  );
                },
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
    return const Scaffold(
      /*
      appBar: AppBar(
        title: const Text('Live Crisis Map'),
      ),
      */
      body: SafeArea(
        child: GoogleMap(
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          initialCameraPosition: CameraPosition(
            target: LatLng(33.6844, 73.0479),
            zoom: 12.0,
          ),
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
      appBar: AppBar(title: Text('Analysis Results', style: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.primary))),
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
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
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
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
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
                Navigator.pushNamed(context, '/simulate', arguments: {'title': title, 'priorityText': priorityText});
              },
              child: const Text('Simulate Action'),
            ),
          ),
        ),
      ),
    );
  }
}

class ActionSimulationScreen extends StatefulWidget {
  const ActionSimulationScreen({Key? key}) : super(key: key);

  @override
  State<ActionSimulationScreen> createState() => _ActionSimulationScreenState();
}

class _ActionSimulationScreenState extends State<ActionSimulationScreen> {
  int _currentStep = 0;
  bool _isComplete = false;
  final List<String> _logs = [];
  Map<String, dynamic>? _result;
  late StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _startMockSimulation();
  }

  void _startMockSimulation() {
    // Mocking the web_socket_channel stream that will eventually come from FastAPI
    final mockStream = Stream.periodic(const Duration(seconds: 2), (i) {
      switch (i) {
        case 0: return {'step': 0, 'log': '[Simulator] Initializing physical environment...'};
        case 1: return {'step': 1, 'log': '[Simulator] Snapshotting "Before" state (congestion: 85%).'};
        case 2: return {'step': 2, 'log': '[Simulator] Applying action resources... mapping traffic...'};
        case 3: return {'step': 2, 'log': '[Simulator] Simulating crowd movement for 30 ticks...'};
        case 4: return {'step': 3, 'log': '[Simulator] Evaluating outcome... calculating metrics.'};
        case 5: return {
            'step': 3, 
            'log': '[Simulator] Simulation completed successfully.',
            'result': {'success_rate': 0.88, 'after_state': {'congestion': '40%'}}
          };
        default: return null;
      }
    }).take(6);

    _subscription = mockStream.listen((event) {
      if (event == null || !mounted) return;
      
      setState(() {
        if (event['log'] != null) _logs.add(event['log']);
        if (event['step'] != null) _currentStep = event['step'] as int;
        if (event['result'] != null) {
          _result = event['result'];
          _isComplete = true;
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Map<String, dynamic>? args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String actionTitle = args?['title'] ?? 'Unknown Action';

    return Scaffold(
      appBar: AppBar(title: const Text('Action Simulation')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: colorScheme.primaryContainer.withOpacity(0.3),
            child: Row(
              children: [
                Icon(Icons.science, color: colorScheme.primary, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Simulating:', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                      Text(actionTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stepper(
              currentStep: _currentStep,
              controlsBuilder: (context, details) => const SizedBox.shrink(),
              steps: [
                Step(
                  title: const Text('Initialization'),
                  content: const Text('Connecting to Simulator Agent...'),
                  state: _currentStep > 0 ? StepState.complete : StepState.editing,
                  isActive: _currentStep >= 0,
                ),
                Step(
                  title: const Text('State Capture'),
                  content: const Text('Capturing before-state environment...'),
                  state: _currentStep > 1 ? StepState.complete : (_currentStep == 1 ? StepState.editing : StepState.indexed),
                  isActive: _currentStep >= 1,
                ),
                Step(
                  title: const Text('Execution'),
                  content: const Text('Applying action logic and running ticks...'),
                  state: _currentStep > 2 ? StepState.complete : (_currentStep == 2 ? StepState.editing : StepState.indexed),
                  isActive: _currentStep >= 2,
                ),
                Step(
                  title: const Text('Evaluation'),
                  content: _isComplete 
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Text('Success Rate: ${((_result?['success_rate'] ?? 0) * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      )
                    : const Text('Calculating final metrics...'),
                  state: _isComplete ? StepState.complete : (_currentStep == 3 ? StepState.editing : StepState.indexed),
                  isActive: _currentStep >= 3,
                ),
              ],
            ),
          ),
          Container(
            height: 200,
            padding: const EdgeInsets.all(16.0),
            color: colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Live Agent Trace', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Text(_logs[index], style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
