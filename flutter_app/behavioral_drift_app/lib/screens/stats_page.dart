import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../data/drift_repository.dart';
import '../models/drift_day.dart';
import '../services/monitoring_service.dart';
import '../services/drift_detection_service.dart';
import '../models/realtime_drift.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late Future<List<DriftDay>> _future;

  bool get _useLocal =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _future = _loadDays();
  }

  Future<List<DriftDay>> _loadDays() async {
    if (_useLocal) {
      final monitor = context.read<MonitoringService>();
      final driftSvc = context.read<DriftDetectionService>();
      await monitor.refreshUsage();
      await driftSvc.computeAll(monitor.apps);
    }
    // Always load merged (offline + live) data
    return DriftRepository.load(preferNetwork: !_useLocal);
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _future = _loadDays();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DriftDay>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                const Text("Failed to load stats"),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _refresh,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final days = snapshot.data ?? [];
        if (days.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.analytics_outlined,
                    size: 64, color: Colors.grey.shade600),
                const SizedBox(height: 12),
                const Text("No data available"),
                const SizedBox(height: 4),
                const Text(
                  'Add apps to monitor or ensure drift_results.json is present.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _refresh,
                  child: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        // ===== COMPUTATIONS =====
        final driftDays = days.where((d) => d.drift).toList();
        final normalDays = days.where((d) => !d.drift).toList();

        final totalDrift = driftDays.length;
        final totalNormal = normalDays.length;
        final total = days.length;
        final driftPct =
            total > 0 ? (totalDrift / total * 100).toStringAsFixed(1) : '0.0';
        final normalPct =
            total > 0 ? (totalNormal / total * 100).toStringAsFixed(1) : '0.0';

        final avgConfidence = days.isNotEmpty
            ? days.map((d) => d.confidence).reduce((a, b) => a + b) /
                days.length
            : 0.0;
        final avgConfPct = (avgConfidence * 100).toStringAsFixed(1);

        final lastDriftDate =
            driftDays.isNotEmpty ? driftDays.last.date : "None";

        // Last 7 days subset
        final last7 = days.length > 7 ? days.sublist(days.length - 7) : days;
        final last7Drift = last7.where((d) => d.drift).length;
        final last7Normal = last7.length - last7Drift;

        // Confidence-based line chart
        final List<FlSpot> confidenceSpots = [];
        for (int i = 0; i < days.length; i++) {
          final c = days[i].confidence.clamp(0.0, 1.0);
          confidenceSpots.add(FlSpot(i.toDouble(), c));
        }

        // Get real-time drift data for per-app summary
        final driftSvc = context.watch<DriftDetectionService>();
        final latestDrifts = driftSvc.latestDrifts;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                "Behavior Overview",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),

              // ===== SUMMARY CARDS =====
              Row(
                children: [
                  _StatCard(
                      label: 'Total Days',
                      value: '$total',
                      color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  _StatCard(
                      label: 'Drift Days',
                      value: '$totalDrift',
                      sub: '$driftPct%',
                      color: Colors.redAccent),
                  const SizedBox(width: 8),
                  _StatCard(
                      label: 'Normal',
                      value: '$totalNormal',
                      sub: '$normalPct%',
                      color: Colors.green),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.timeline, color: Colors.deepPurple),
                  title: const Text("Last Drift Detected"),
                  subtitle: Text(lastDriftDate),
                  trailing: Text(
                    'Avg: $avgConfPct%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ===== DRIFT DISTRIBUTION PIE CHART =====
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Drift Distribution",
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Overall: $driftPct% drift | $normalPct% normal',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: (totalDrift == 0 && totalNormal == 0)
                            ? const Center(
                                child: Text('No distribution data'))
                            : PieChart(
                                PieChartData(
                                  centerSpaceRadius: 50,
                                  sectionsSpace: 3,
                                  sections: [
                                    if (totalDrift > 0)
                                      PieChartSectionData(
                                        value: totalDrift.toDouble(),
                                        title: 'Drift\n$totalDrift',
                                        color: Colors.redAccent,
                                        radius: 45,
                                        titleStyle: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white),
                                      ),
                                    if (totalNormal > 0)
                                      PieChartSectionData(
                                        value: totalNormal.toDouble(),
                                        title: 'Normal\n$totalNormal',
                                        color: Colors.greenAccent,
                                        radius: 45,
                                        titleStyle: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ===== LAST 7 DAYS MINI SUMMARY =====
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Last 7 Days",
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: last7.isNotEmpty
                                  ? last7Drift / last7.length
                                  : 0,
                              minHeight: 10,
                              backgroundColor: Colors.greenAccent.withOpacity(0.3),
                              color: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$last7Drift drift / $last7Normal normal',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        children: last7.map((d) {
                          return Chip(
                            label: Text(
                              d.date.substring(5), // MM-DD
                              style: const TextStyle(fontSize: 10),
                            ),
                            backgroundColor:
                                d.drift ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                            avatar: Icon(
                              d.drift ? Icons.warning : Icons.check,
                              size: 14,
                              color: d.drift ? Colors.red : Colors.green,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ===== CONFIDENCE TIMELINE =====
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Drift Confidence Timeline",
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Higher values indicate stronger deviation from baseline",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 240,
                        child: LineChart(
                          LineChartData(
                            minY: 0,
                            maxY: 1,
                            gridData: FlGridData(show: true),
                            titlesData: FlTitlesData(show: false),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: confidenceSpots,
                                isCurved: true,
                                barWidth: 3,
                                color: Colors.deepPurpleAccent,
                                dotData: FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.deepPurpleAccent.withOpacity(0.2),
                                ),
                              ),
                            ],
                            extraLinesData: ExtraLinesData(
                              horizontalLines: [
                                HorizontalLine(
                                  y: 0.5,
                                  color: Colors.redAccent.withOpacity(0.4),
                                  strokeWidth: 1,
                                  dashArray: [6, 4],
                                  label: HorizontalLineLabel(
                                    show: true,
                                    labelResolver: (_) => 'threshold',
                                    style: const TextStyle(
                                        fontSize: 9, color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ===== PER-APP DRIFT SUMMARY (Live Data) =====
              if (latestDrifts.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Per-App Drift Summary',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...latestDrifts.map((d) => _AppDriftSummaryCard(drift: d)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              if (sub != null)
                Text(sub!,
                    style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppDriftSummaryCard extends StatelessWidget {
  final RealtimeDrift drift;
  const _AppDriftSummaryCard({required this.drift});

  @override
  Widget build(BuildContext context) {
    final pct = (drift.driftScore * 100).toStringAsFixed(0);
    final baseMin = drift.baselineAvgMinutes.toStringAsFixed(0);
    final todayMin = drift.todayMinutes.toStringAsFixed(0);
    final appLabel = drift.packageName.split('.').last;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  drift.isDrifted ? Icons.warning_amber : Icons.check_circle,
                  color: drift.isDrifted ? Colors.redAccent : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: drift.isDrifted
                        ? Colors.red.withOpacity(0.15)
                        : Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$pct% deviation',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: drift.isDrifted ? Colors.redAccent : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Today: ${todayMin}min  |  Baseline: ${baseMin}min',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (drift.explanation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                drift.explanation,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
