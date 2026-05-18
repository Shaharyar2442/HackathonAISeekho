import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Error loading .env in main: $e");
  }
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const CIROApp(),
    ),
  );
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}

class CIROApp extends StatelessWidget {
  const CIROApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CIRO',
      debugShowCheckedModeBanner: false,
      themeMode: context.watch<ThemeProvider>().themeMode,
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
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const MainScreen(),
        '/response': (context) => const ResponseScreen(),
        '/simulate': (context) => const ActionSimulationScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 1.0, curve: Curves.easeIn)),
    );

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final startTime = DateTime.now();
    
    // dotenv is now loaded in main()

    // Ensure splash is visible for at least 2.5 seconds for branding and premium feel
    final elapsedTime = DateTime.now().difference(startTime);
    final remainingDelay = const Duration(milliseconds: 2500) - elapsedTime;
    
    if (remainingDelay > Duration.zero) {
      await Future.delayed(remainingDelay);
    }

    if (mounted) {
      // Custom smooth transition to MainScreen
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Centered Logo & Brand
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Premium container for the logo with smooth drop shadow
                    Container(
                      height: 160,
                      width: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primaryContainer,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: ClipOval(
                        child: Image.asset(
                          'logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'CIRO',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom branding info
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Crisis Intelligence & Response Orchestrator',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Minimal loading line
                    SizedBox(
                      width: 120,
                      height: 2.5,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          color: theme.colorScheme.primary,
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
  TextEditingController? _autoCompleteController;
  
  double? _selectedLat;
  double? _selectedLng;
  String? selectedType = 'Flood';
  bool _isLoading = false;
  
  final List<String> types = ['Flood', 'Accident', 'Power Outage', 'Fire', 'Traffic'];

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  Future<List<String>> _getPlacePredictions(String query) async {
    final apiKey = dotenv.env['MAPS_API_KEY'] ?? '';
    if (apiKey.isEmpty) return [];
    
    final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$apiKey';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = data['predictions'] as List;
        return predictions.map((p) => p['description'] as String).toList();
      }
    } catch (e) {
      debugPrint('Places API error: $e');
    }
    return [];
  }

  Future<void> _fetchCoordinatesFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        _selectedLat = locations.first.latitude;
        _selectedLng = locations.first.longitude;
      }
    } catch (e) {
      debugPrint('Failed to get coordinates from address: $e');
    }
  }

  Future<void> _detectLocation(TextEditingController controller) async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }
      
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _selectedLat = position.latitude;
      _selectedLng = position.longitude;
      
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Clean up the address string
        List<String> parts = [];
        if (place.street != null && place.street!.isNotEmpty) parts.add(place.street!);
        if (place.subLocality != null && place.subLocality!.isNotEmpty) parts.add(place.subLocality!);
        if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!);
        controller.text = parts.join(', ');
      } else {
        controller.text = '${position.latitude}, ${position.longitude}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        automaticallyImplyLeading: false,
        title: Text('CIRO Monitor', style: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.primary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          )
        ],
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
                'Location',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 8),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return await _getPlacePredictions(textEditingValue.text);
                },
                onSelected: (String selection) {
                  _fetchCoordinatesFromAddress(selection);
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  _autoCompleteController = textEditingController;
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    onFieldSubmitted: (String value) {
                      onFieldSubmitted();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search address or tap auto-detect...',
                      filled: true,
                      fillColor: inputFillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.my_location),
                        color: theme.colorScheme.primary,
                        onPressed: () => _detectLocation(textEditingController),
                        tooltip: 'Auto-detect location',
                      ),
                    ),
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
                    String locText = _autoCompleteController?.text ?? '';
                    if (locText.isEmpty) locText = 'Unknown Location';
                    
                    final result = await ApiService.submitAndAnalyze(
                      _reportController.text.isEmpty ? 'Emergency situation observed.' : _reportController.text,
                      locText,
                      selectedType ?? 'Flood',
                      lat: _selectedLat,
                      lng: _selectedLng,
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
                    : const Icon(Icons.send_rounded),
                label: Text(_isLoading ? 'Reporting...' : 'Report', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  WebSocketChannel? _channel;
  final List<Map<String, dynamic>> _liveSignals = [];
  bool _wsConnected = false;
  bool _locationGranted = false;
  
  int _signalCounter = 0;
  final Map<String, BitmapDescriptor> _markerIcons = {};
  final ScrollController _feedScrollController = ScrollController();

  final Map<String, LatLng> _zoneCoordinates = {
    'G-10': const LatLng(33.6738, 73.0135),
    'G-11': const LatLng(33.6651, 72.9922),
    'F-8': const LatLng(33.7082, 73.0374),
    'I-8': const LatLng(33.6690, 73.0760),
    'Blue Area': const LatLng(33.7225, 73.0805),
  };

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    // Defer WebSocket connection to after the first frame so dotenv is guaranteed loaded
    WidgetsBinding.instance.addPostFrameCallback((_) => _connectWebSocket());
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (mounted) {
      setState(() {
        _locationGranted = status.isGranted;
      });
    }
  }

  Future<BitmapDescriptor> _createNumberedMarker(int number, Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 100.0;
    
    final Paint paint = Paint()..color = color;
    final Paint borderPaint = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 6.0;
    
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, borderPaint);
    
    final TextPainter painter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    painter.text = TextSpan(
      text: number.toString(),
      style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
    );
    painter.layout();
    painter.paint(
      canvas,
      Offset((size - painter.width) / 2, (size - painter.height) / 2),
    );
    
    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  void _connectWebSocket() {
    if (_wsConnected || !mounted) return;
    try {
      String wsUrl = dotenv.env['WS_BASE_URL'] ?? 'ws://10.188.25.60:8000/ws/signals';
      wsUrl = wsUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsConnected = true;
      _channel!.stream.listen((message) async {
        if (!mounted) return;
        final rawData = jsonDecode(message);
        if (rawData is Map<String, dynamic> && rawData['type'] == 'new_crisis') {
          final crisis = rawData['crisis'] ?? {};
          final signal = rawData['signal'] ?? {};
          final actions = rawData['actions'] ?? [];
          final agentTrace = rawData['agent_trace'] ?? [];

          final Map<String, dynamic> data = {
            'crisis_type': crisis['type'] ?? 'Alert',
            'severity': crisis['severity'] ?? 1,
            'location': crisis['location'] ?? 'Unknown',
            'text': signal['text'] ?? crisis['reasoning'] ?? 'Crisis reported',
            'lat': signal['lat'],
            'lng': signal['lng'],
            'full_crisis': crisis,
            'actions': actions,
            'agentTrace': agentTrace,
          };

          _signalCounter++;
          final currentNumber = _signalCounter;
          data['number'] = currentNumber;
          final signalId = data['text'] ?? currentNumber.toString();
          
          LatLng? computedLatLng;
          if (data['lat'] != null && data['lng'] != null) {
            computedLatLng = LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble());
            data['computed_latlng'] = computedLatLng;
          } else {
            final locName = data['location'] as String?;
            final baseLatLng = _zoneCoordinates[locName];
            if (baseLatLng != null) {
              computedLatLng = baseLatLng;
              data['computed_latlng'] = computedLatLng;
            }
          }
          
          // Trigger notification if nearby (e.g. within 10km)
          if (computedLatLng != null && _locationGranted) {
            try {
              final pos = await Geolocator.getLastKnownPosition();
              if (pos != null) {
                final dist = Geolocator.distanceBetween(pos.latitude, pos.longitude, computedLatLng.latitude, computedLatLng.longitude);
                if (dist < 10000) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('⚠️ Alert nearby: ${data['crisis_type']}!'),
                      backgroundColor: Colors.red.shade800,
                      action: SnackBarAction(
                        label: 'VIEW ACTIONS',
                        textColor: Colors.white,
                        onPressed: () {
                          Navigator.pushNamed(context, '/response', arguments: {
                            'detectedCrisis': data['full_crisis'],
                            'actions': data['actions'],
                            'agentTrace': data['agentTrace'],
                          });
                        },
                      ),
                      duration: const Duration(seconds: 10),
                    ),
                  );
                }
              }
            } catch (_) {}
          }
          
          _createNumberedMarker(currentNumber, _getSignalColor(data)).then((icon) {
            if (mounted) {
              setState(() {
                _markerIcons[signalId] = icon;
              });
            }
          });

          setState(() {
            _liveSignals.insert(0, data);
          });
        }
      }, onError: (e) {
        print("WebSocket error: $e");
      });
    } catch (e) {
      print("WebSocket connect error: $e");
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _feedScrollController.dispose();
    super.dispose();
  }

  Color _getSignalColor(Map<String, dynamic> signal) {
    final severity = signal['severity'] ?? 1;
    if (severity >= 4) return Colors.red;
    if (severity == 3) return Colors.orange;
    return Colors.blue;
  }

  double _getMarkerHue(Map<String, dynamic> signal) {
    final severity = signal['severity'] ?? 1;
    if (severity >= 4) return BitmapDescriptor.hueRed;
    if (severity == 3) return BitmapDescriptor.hueOrange;
    return BitmapDescriptor.hueAzure;
  }

  Set<Marker> _buildMarkers() {
    final allSignals = [...ApiService.locallyReportedSignals, ..._liveSignals];
    return allSignals.map((signal) {
      LatLng? latLng = signal['computed_latlng'];
      if (latLng == null) {
        if (signal['lat'] != null && signal['lng'] != null) {
          latLng = LatLng((signal['lat'] as num).toDouble(), (signal['lng'] as num).toDouble());
        } else {
          latLng = _zoneCoordinates[signal['location']];
        }
      }
      if (latLng == null) return null;
      
      return Marker(
        markerId: MarkerId(signal['text'] ?? DateTime.now().toString()),
        position: latLng,
        infoWindow: InfoWindow(
          title: '${signal['crisis_type'] ?? 'Report'} (Sev ${signal['severity'] ?? 1})',
          snippet: 'Tap to view simulation & actions',
          onTap: () {
            if (signal['full_crisis'] != null) {
              Navigator.pushNamed(context, '/response', arguments: {
                'detectedCrisis': signal['full_crisis'],
                'actions': signal['actions'] ?? [],
                'agentTrace': signal['agentTrace'] ?? [],
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Locally reported signal pending backend validation.')));
            }
          },
        ),
        icon: _markerIcons[signal['text'] ?? signal['number']?.toString() ?? 'local'] ?? BitmapDescriptor.defaultMarkerWithHue(_getMarkerHue(signal)),
      );
    }).whereType<Marker>().toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GoogleMap(
                myLocationButtonEnabled: true,
                myLocationEnabled: _locationGranted,
                zoomControlsEnabled: false,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(33.6844, 73.0479),
                  zoom: 12.0,
                ),
                markers: _buildMarkers(),
              ),
            ),
            if (_liveSignals.isNotEmpty || ApiService.locallyReportedSignals.isNotEmpty)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sensors, color: Theme.of(context).colorScheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Text('Live Signal Feed', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: Scrollbar(
                          controller: _feedScrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _feedScrollController,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [...ApiService.locallyReportedSignals, ..._liveSignals].map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 4, right: 8),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _getSignalColor(s),
                                    ),
                                  ),
                                  Text(
                                    '#${s['number'] ?? '-'} ',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: _getSignalColor(s),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      s['text'] ?? 'Unknown signal', 
                                      style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                  ),
                                ],
                              ),
                              )).toList(),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
          ],
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
                      actionId: action['id'] ?? 'act_unknown',
                      actionType: action['type'] ?? 'Unknown Action',
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
    required String actionId,
    required String actionType,
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
                Navigator.pushNamed(context, '/simulate', arguments: {
                  'id': actionId,
                  'type': actionType,
                  'title': title, 
                  'priorityText': priorityText
                });
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
  List<String> _execLogs = [];
  Map<String, dynamic>? _result;
  late StreamSubscription _subscription;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final String actionTitle = args?['title'] ?? 'Unknown Action';
      final String actionId = args?['id'] ?? 'act_123';
      final String actionType = args?['type'] ?? 'Unknown Action';
      _startSimulation(actionTitle, actionId, actionType);
    }
  }

  void _startSimulation(String actionTitle, String actionId, String actionType) async {
    try {
      setState(() {
        _logs.add('[Simulator] Connecting to Backend Simulator...');
      });
      // 1. Call the real FastAPI simulation endpoint
      final data = await ApiService.simulateAction(actionType, actionId);
      final result = data['simulation_result'];
      final agentTrace = data['agent_trace'] as List<dynamic>? ?? [];
      
      final execLogs = List<String>.from(result['execution_log'] ?? []);
      setState(() {
        _execLogs = execLogs;
      });

      // Add reasoning steps to logs if available
      final List<String> reasoningSteps = [];
      if (agentTrace.isNotEmpty) {
        final trace = agentTrace.first;
        reasoningSteps.addAll(List<String>.from(trace['reasoning_steps'] ?? []));
      }

      // 2. Animate the logs into the UI
      final eventStream = Stream.periodic(const Duration(milliseconds: 800), (i) {
        if (i < reasoningSteps.length) {
          return {'log': '[Agent] ${reasoningSteps[i]}', 'step': _currentStep};
        }
        
        final execIndex = i - reasoningSteps.length;
        if (execIndex < execLogs.length) {
          return {'log': '[Execution] ${execLogs[execIndex]}', 'step': execIndex};
        } else if (execIndex == execLogs.length) {
          return {
            'step': execLogs.length,
            'log': '[Simulator] Simulation completed successfully.',
            'result': {
              'after_state': result['after_state'],
            }
          };
        }
        return null;
      }).take(reasoningSteps.length + execLogs.length + 1);

      _subscription = eventStream.listen((event) {
        if (event == null || !mounted) return;
        setState(() {
          if (event['log'] != null) _logs.add(event['log'] as String);
          if (event['step'] != null) _currentStep = event['step'] as int;
          if (event['result'] != null) {
            _result = event['result'] as Map<String, dynamic>;
            _isComplete = true;
          }
        });
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _logs.add('[Error] Simulation failed: $e');
        });
      }
    }
  }

  @override
  void dispose() {
    if (_initialized) {
      _subscription.cancel();
    }
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
            child: _execLogs.isEmpty 
              ? const Center(child: CircularProgressIndicator())
              : Stepper(
                  currentStep: _currentStep < _execLogs.length ? _currentStep : _execLogs.length,
                  controlsBuilder: (context, details) => const SizedBox.shrink(),
                  steps: List.generate(_execLogs.length + 1, (index) {
                    if (index == _execLogs.length) {
                      return Step(
                        title: const Text('Evaluation Complete'),
                        content: _isComplete 
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text('After state: ${_result?['after_state']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            )
                          : const Text('Calculating final metrics...'),
                        state: _isComplete ? StepState.complete : (_currentStep == index ? StepState.editing : StepState.indexed),
                        isActive: _currentStep >= index,
                      );
                    }
                    return Step(
                      title: Text('Step ${index + 1}'),
                      content: Text(_execLogs[index]),
                      state: _currentStep > index ? StepState.complete : (_currentStep == index ? StepState.editing : StepState.indexed),
                      isActive: _currentStep >= index,
                    );
                  }),
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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('System Default'),
            value: ThemeMode.system,
            groupValue: themeProvider.themeMode,
            onChanged: (val) => context.read<ThemeProvider>().setThemeMode(val!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Light Theme'),
            value: ThemeMode.light,
            groupValue: themeProvider.themeMode,
            onChanged: (val) => context.read<ThemeProvider>().setThemeMode(val!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark Theme'),
            value: ThemeMode.dark,
            groupValue: themeProvider.themeMode,
            onChanged: (val) => context.read<ThemeProvider>().setThemeMode(val!),
          ),
        ],
      ),
    );
  }
}
