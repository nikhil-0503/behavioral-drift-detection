import 'package:flutter/material.dart';
import '../models/drift_day.dart';

class DriftTimeline extends StatelessWidget {
  final List<DriftDay> days;

  const DriftTimeline({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: days.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final d = days[i];
        final isDrift = d.drift;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Icon(
                  isDrift ? Icons.warning_amber_rounded : Icons.check_circle,
                  color: isDrift ? Colors.redAccent : Colors.greenAccent,
                  size: 20,
                ),
                Container(
                  width: 2,
                  height: 40,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.date,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isDrift
                          ? "Behavior deviation detected"
                          : "Normal behavior",
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
