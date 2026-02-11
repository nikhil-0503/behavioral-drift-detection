import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../data/drift_repository.dart';
import '../models/drift_day.dart';
import '../services/monitoring_service.dart';
import '../services/drift_detection_service.dart';

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
      return DriftRepository.load(preferNetwork: false);
    }
    return DriftRepository.load(preferNetwork: true);
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
          return const Center(child: Text("Failed to load stats"));
        }

        final days = snapshot.data ?? [];
        if (days.isEmpty) {
          return const Center(child: Text("No data available"));
        }

        // ===== COMPUTATIONS =====
        final driftDays = days.where((d) => d.drift).toList();
        final normalDays = days.where((d) => !d.drift).toList();

        final totalDrift = driftDays.length;
        final totalNormal = normalDays.length;

        final lastDriftDate =
            driftDays.isNotEmpty ? driftDays.last.date : "None";

        // Confidence-based line chart
        final List<FlSpot> confidenceSpots = [];
        for (int i = 0; i < days.length; i++) {
          final c = days[i].confidence.clamp(0.0, 1.0);
          confidenceSpots.add(FlSpot(i.toDouble(), c));
        }

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

              // ===== SUMMARY =====
              Card(
                child: ListTile(
                  leading: Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade700),
                  title: const Text("Total Drift Days"),
                  subtitle: Text("$totalDrift days detected"),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.timeline, color: Colors.deepPurple),
                  title: const Text("Last Drift Detected"),
                  subtitle: Text(lastDriftDate),
                ),
              ),
              Card(
                child: const ListTile(
                  leading: Icon(Icons.insights, color: Colors.green),
                  title: Text("System Status"),
                  subtitle: Text("Behavior monitoring active"),
                ),
              ),

              const SizedBox(height: 24),

              // ===== DRIFT DISTRIBUTION =====
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
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            centerSpaceRadius: 50,
                            sectionsSpace: 3,
                            sections: [
                              PieChartSectionData(
                                value: totalDrift.toDouble(),
                                title: "Drift",
                                color: Colors.redAccent,
                                radius: 45,
                              ),
                              PieChartSectionData(
                                value: totalNormal.toDouble(),
                                title: "Normal",
                                color: Colors.greenAccent,
                                radius: 45,
                              ),
                            ],
                          ),
                        ),
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
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
