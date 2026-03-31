import 'package:flutter/material.dart';
import '../models/drift_day.dart';

class DriftTile extends StatelessWidget {
  final DriftDay day;

  const DriftTile({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final bool drifted = day.drift;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(
          drifted ? Icons.warning : Icons.check_circle,
          color: drifted ? Colors.red : Colors.green,
        ),
        title: Text(day.date),
        subtitle: Text(
          drifted ? 'Drift Detected' : 'No Drift',
          style: TextStyle(
            color: drifted ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
