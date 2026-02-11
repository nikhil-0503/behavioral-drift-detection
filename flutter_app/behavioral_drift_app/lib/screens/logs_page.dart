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
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../data/drift_repository.dart';
import '../models/drift_day.dart';
import '../services/monitoring_service.dart';
import '../services/drift_detection_service.dart';
import '../models/realtime_drift.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  late Future<List<DriftDay>> _future;
  String _source = 'all'; // 'all', 'offline', 'live'

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
    switch (_source) {
      case 'offline':
        return DriftRepository.loadOfflineOnly();
      case 'live':
        return DriftRepository.loadLiveOnly();
      default:
        return DriftRepository.load(preferNetwork: !_useLocal);
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _future = _loadDays();
    });
    await _future;
  }

  Color _statusColor(bool drift) =>
      drift ? Colors.redAccent : Colors.green;

  IconData _statusIcon(bool drift) =>
      drift ? Icons.warning_amber_rounded : Icons.check_circle;

  String _statusText(bool drift) =>
      drift ? "Behavior deviation detected" : "Normal behavior";

  @override
  Widget build(BuildContext context) {
    final driftSvc = context.watch<DriftDetectionService>();
    final latestDrifts = driftSvc.latestDrifts;

    return Column(
      children: [
        // ── Source filter chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              _FilterChip(
                  label: 'All',
                  selected: _source == 'all',
                  onTap: () {
                    setState(() => _source = 'all');
                    _refresh();
                  }),
              const SizedBox(width: 8),
              _FilterChip(
                  label: 'Dataset',
                  selected: _source == 'offline',
                  onTap: () {
                    setState(() => _source = 'offline');
                    _refresh();
                  }),
              const SizedBox(width: 8),
              _FilterChip(
                  label: 'Live',
                  selected: _source == 'live',
                  onTap: () {
                    setState(() => _source = 'live');
                    _refresh();
                  }),
            ],
          ),
        ),

        // ── Today's per-app drift (live, always visible) ──
        if (latestDrifts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.sensors, size: 16, color: Colors.deepPurple),
                const SizedBox(width: 6),
                Text(
                  'Live Drift Today',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: latestDrifts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final d = latestDrifts[i];
                return _LiveDriftChip(drift: d);
              },
            ),
          ),
        ],

        // ── Main drift log list ──
        Expanded(
          child: FutureBuilder<List<DriftDay>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const Center(child: Text("Failed to load logs"));
              }

              final days = snapshot.data ?? [];
              if (days.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.list_alt,
                          size: 48, color: Colors.grey.shade600),
                      const SizedBox(height: 8),
                      Text(
                        _source == 'live'
                            ? 'No live drift data yet.\nAdd apps and use them to generate data.'
                            : 'No logs available',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              // Most recent first
              final reversed = days.reversed.toList();

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: reversed.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final day = reversed[index];
                    final confidencePct =
                        (day.confidence * 100).toStringAsFixed(0);

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
                          style:
                              const TextStyle(fontWeight: FontWeight.bold),
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
                                    value:
                                        day.confidence.clamp(0.0, 1.0),
                                    backgroundColor: Colors.grey.shade300,
                                    color: _statusColor(day.drift),
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text("$confidencePct%",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _statusColor(day.drift),
                                    )),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.deepPurple,
      labelStyle: TextStyle(
        color: selected ? Colors.white : null,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _LiveDriftChip extends StatelessWidget {
  final RealtimeDrift drift;
  const _LiveDriftChip({required this.drift});

  @override
  Widget build(BuildContext context) {
    final pct = (drift.driftScore * 100).toStringAsFixed(0);
    final label = drift.packageName.split('.').last;
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: drift.isDrifted
            ? Colors.red.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        border: Border.all(
          color: drift.isDrifted ? Colors.redAccent : Colors.green,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$pct% deviation',
            style: TextStyle(
              fontSize: 11,
              color: drift.isDrifted ? Colors.redAccent : Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${drift.todayMinutes.toStringAsFixed(0)}min today',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
