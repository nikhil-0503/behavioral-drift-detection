import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/drift_day.dart';
import '../widgets/drift_tile.dart';
import 'about_page.dart';

class DriftHome extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const DriftHome({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<DriftHome> createState() => _DriftHomeState();
}

class _DriftHomeState extends State<DriftHome> {
  List<DriftDay> driftDays = [];

  @override
  void initState() {
    super.initState();
    loadDriftData();
  }

  Future<void> loadDriftData() async {
    final jsonString =
        await rootBundle.loadString('assets/drift_results.json');
    final List data = json.decode(jsonString);

    setState(() {
      driftDays = data.map((e) => DriftDay.fromJson(e)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final driftCount = driftDays.where((d) => d.drift).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Behavioral Drift Monitor"),
        actions: [
          IconButton(
            icon: Icon(widget.isDark ? Icons.dark_mode : Icons.light_mode),
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: ListTile(
                title: const Text("Summary"),
                subtitle: Text(
                  "Total Days: ${driftDays.length}\n"
                  "Drift Detected: $driftCount days",
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: driftDays.length,
              itemBuilder: (context, index) {
                return DriftTile(day: driftDays[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
