// import 'package:flutter/material.dart';
// import '../models/drift_day.dart';
// import '../data/drift_repository.dart';
// import '../screens/drift_timeline.dart';

// class LogsPage extends StatelessWidget {
//   const LogsPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<List<DriftDay>>(
//       future: DriftRepository.load(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }

//         if (snapshot.hasError) {
//           return Center(
//             child: Text(
//               "Failed to load logs",
//               style: Theme.of(context).textTheme.bodyLarge,
//             ),
//           );
//         }

//         final days = snapshot.data ?? [];

//         if (days.isEmpty) {
//           return const Center(child: Text("No drift data found"));
//         }

//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Padding(
//               padding: const EdgeInsets.all(16),
//               child: Text(
//                 "Behavior Timeline",
//                 style: Theme.of(context).textTheme.headlineSmall,
//               ),
//             ),
//             Expanded(
//               child: DriftTimeline(days: days),
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
import 'package:flutter/material.dart';
import '../data/drift_repository.dart';
import '../models/drift_day.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  Color _statusColor(bool drift) =>
      drift ? Colors.redAccent : Colors.green;

  IconData _statusIcon(bool drift) =>
      drift ? Icons.warning_amber_rounded : Icons.check_circle;

  String _statusText(bool drift) =>
      drift ? "Behavior deviation detected" : "Normal behavior";

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DriftDay>>(
      future: DriftRepository.load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final days = snapshot.data!;
        if (days.isEmpty) {
          return const Center(child: Text("No logs available"));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: days.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final day = days[index];
            final confidencePct = (day.confidence * 100).toStringAsFixed(0);

            return Card(
              elevation: 2,
              child: ListTile(
                leading: Icon(
                  _statusIcon(day.drift),
                  color: _statusColor(day.drift),
                  size: 30,
                ),
                title: Text(
                  day.date,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      _statusText(day.drift),
                      style: TextStyle(
                        color: _statusColor(day.drift),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: day.confidence.clamp(0.0, 1.0),
                            backgroundColor: Colors.grey.shade300,
                            color: _statusColor(day.drift),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text("$confidencePct%"),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
