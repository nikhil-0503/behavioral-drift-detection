import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/drift_day.dart';
import '../widgets/drift_tile.dart';

class DriftHome extends StatefulWidget {
  const DriftHome({super.key});

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
    final String jsonString =
        await rootBundle.loadString('assets/drift_results.json');
    final List data = json.decode(jsonString);

    setState(() {
      driftDays = data.map((e) => DriftDay.fromJson(e)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Behavioral Drift Monitor"),
      ),
      body: ListView.builder(
        itemCount: driftDays.length,
        itemBuilder: (context, index) {
          return DriftTile(day: driftDays[index]);
        },
      ),
    );
  }
}
