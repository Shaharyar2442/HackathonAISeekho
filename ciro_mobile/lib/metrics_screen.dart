import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'api_service.dart';
import 'dart:math';

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({Key? key}) : super(key: key);

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  @override
  void initState() {
    super.initState();
    ApiService.signalsChanged.addListener(_onSignalsChanged);
  }

  @override
  void dispose() {
    ApiService.signalsChanged.removeListener(_onSignalsChanged);
    super.dispose();
  }

  void _onSignalsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allSignals = [...ApiService.locallyReportedSignals, ...ApiService.liveSignals];

    // Calculate metrics
    final totalSignals = allSignals.length;
    final Map<String, int> typeCounts = {};
    int highSeverityCount = 0; // Severity >= 4
    int mitigatedCount = 0;    // Severity <= 2

    for (final s in allSignals) {
      final type = s['crisis_type'] ?? 'Unknown';
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      
      final severity = (s['severity'] as num?)?.toInt() ?? 1;
      if (severity >= 4) highSeverityCount++;
      if (severity <= 2) mitigatedCount++; // Count minor or resolved
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('CIRO Metrics', style: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.primary)),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Total Incidents',
                      totalSignals.toString(),
                      Icons.analytics_outlined,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'High Severity',
                      highSeverityCount.toString(),
                      Icons.warning_amber_rounded,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Mitigated',
                      mitigatedCount.toString(),
                      Icons.check_circle_outline,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              Text(
                'Incidents by Type',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              
              if (typeCounts.isEmpty)
                Container(
                  height: 200,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('No data available', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                )
              else
                Container(
                  height: 300,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _buildPieSections(typeCounts),
                    ),
                  ),
                ),
                
              const SizedBox(height: 24),
              Text(
                'Legend',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...typeCounts.keys.map((type) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _getColorForType(type),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$type (${typeCounts[type]})', style: theme.textTheme.bodyMedium),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(Map<String, int> counts) {
    int total = counts.values.fold(0, (sum, val) => sum + val);
    return counts.entries.map((e) {
      final percentage = (e.value / total) * 100;
      return PieChartSectionData(
        color: _getColorForType(e.key),
        value: e.value.toDouble(),
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Color _getColorForType(String type) {
    switch (type.toLowerCase()) {
      case 'fire hazard':
        return Colors.orange;
      case 'urban flooding':
        return Colors.blue;
      case 'power infrastructure':
        return Colors.amber;
      case 'severe accident':
        return Colors.red;
      case 'traffic gridlock':
        return Colors.grey;
      default:
        // Hash string to generate a deterministic color
        final hash = type.hashCode;
        return Colors.primaries[hash % Colors.primaries.length];
    }
  }
}
