import 'package:flutter/material.dart';
import '../models/drift_day.dart';

class DriftTile extends StatelessWidget {
  final DriftDay day;

  const DriftTile({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: day.drift ? Colors.red[50] : Colors.green[50],
      child: ListTile(
        leading: Icon(
          day.drift ? Icons.warning : Icons.check_circle,
          color: day.drift ? Colors.red : Colors.green,
        ),
        title: Text(day.date),
        subtitle: Text(
          day.drift ? "Behavioral Drift Detected" : "Normal Behavior",
        ),
      ),
    );
  }
}
