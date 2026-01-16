import 'package:flutter/material.dart';
import '../models/drift_day.dart';
import '../data/drift_repository.dart';
import '../screens/drift_timeline.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DriftDay>>(
      future: DriftRepository.load(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Failed to load logs",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }

        final days = snapshot.data ?? [];

        if (days.isEmpty) {
          return const Center(child: Text("No drift data found"));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Behavior Timeline",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Expanded(
              child: DriftTimeline(days: days),
            ),
          ],
        );
      },
    );
  }
}
