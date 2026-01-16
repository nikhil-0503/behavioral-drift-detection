import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/drift_repository.dart';
import '../models/drift_day.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DriftDay>>(
      future: DriftRepository.load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final days = snapshot.data!;

        // ===== REAL DATA COMPUTATION =====
        final driftDays = days.where((d) => d.drift).toList();
        final normalDays = days.where((d) => !d.drift).toList();

        final totalDrift = driftDays.length;
        final totalNormal = normalDays.length;

        final lastDriftDate =
            driftDays.isNotEmpty ? driftDays.last.date : "None";

        final spots = <FlSpot>[];
        for (int i = 0; i < days.length; i++) {
          spots.add(FlSpot(i.toDouble(), days[i].drift ? 1 : 0));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              "Behavior Overview",
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),

            // ===== SUMMARY CARDS =====
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
                leading: const Icon(Icons.timeline, color: Colors.purple),
                title: const Text("Last Drift"),
                subtitle: Text(lastDriftDate),
              ),
            ),
            Card(
              child: const ListTile(
                leading: Icon(Icons.insights, color: Colors.green),
                title: Text("System Status"),
                subtitle: Text("Tracking live behavior"),
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
                          centerSpaceRadius: 55,
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

            // ===== DRIFT TIMELINE =====
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Drift Timeline",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: false),
                          titlesData: FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          minY: 0,
                          maxY: 1,
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: Colors.deepPurpleAccent,
                              barWidth: 3,
                              dotData: FlDotData(show: true),
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
        );
      },
    );
  }
}
