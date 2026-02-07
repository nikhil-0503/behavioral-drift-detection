import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/monitored_app.dart';
import '../models/realtime_drift.dart';
import '../services/monitoring_service.dart';
import '../services/drift_detection_service.dart';

/// Detail page for a single monitored app – shows drift history,
/// usage breakdown, and limit adjustment (reduce only).
class AppDetailPage extends StatefulWidget {
  final MonitoredApp app;

  const AppDetailPage({super.key, required this.app});

  @override
  State<AppDetailPage> createState() => _AppDetailPageState();
}

class _AppDetailPageState extends State<AppDetailPage> {
  List<RealtimeDrift> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = context.read<DriftDetectionService>();
    _history = await svc.getHistory(widget.app.packageName);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final usedMin = app.todayUsageSeconds / 60.0;
    final ratio = app.usageRatio.clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: Text(app.appName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── TODAY'S USAGE ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Today\'s Usage',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 12,
                                  backgroundColor: Colors.grey.shade800,
                                  color: app.isLimitExceeded
                                      ? Colors.red
                                      : Colors.deepPurpleAccent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${usedMin.toStringAsFixed(0)} / ${app.dailyLimitMinutes} min',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        if (app.isLimitExceeded || app.isBlocked)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              '⛔ This app is BLOCKED. You set this limit — '
                              'own your commitment.',
                              style: TextStyle(
                                  color: Colors.redAccent, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── LIMIT ADJUSTMENT ──
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Adjust Limit',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        const Text(
                          'You can only reduce your limit — never increase it.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        _LimitSlider(app: app),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── DRIFT HISTORY CHART ──
                if (_history.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Drift History (last 30 days)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          const Text(
                            'Higher score = bigger deviation from YOUR baseline',
                            style:
                                TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                minY: 0,
                                maxY: 2,
                                gridData: const FlGridData(show: true),
                                titlesData:
                                    const FlTitlesData(show: false),
                                borderData: FlBorderData(show: false),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _history
                                        .reversed
                                        .toList()
                                        .asMap()
                                        .entries
                                        .map((e) => FlSpot(
                                            e.key.toDouble(),
                                            e.value.driftScore
                                                .clamp(0, 2)))
                                        .toList(),
                                    isCurved: true,
                                    barWidth: 2.5,
                                    color: Colors.deepPurpleAccent,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: Colors.deepPurpleAccent
                                          .withOpacity(0.15),
                                    ),
                                  ),
                                ],
                                extraLinesData: ExtraLinesData(
                                  horizontalLines: [
                                    HorizontalLine(
                                      y: 0.5,
                                      color: Colors.redAccent.withOpacity(0.5),
                                      strokeWidth: 1,
                                      dashArray: [6, 4],
                                      label: HorizontalLineLabel(
                                        show: true,
                                        labelResolver: (_) => 'drift threshold',
                                        style: const TextStyle(
                                            fontSize: 9, color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── DRIFT LOG ──
                if (_history.isNotEmpty) ...[
                  Text('Drift Log',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._history.take(10).map((d) => Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          leading: Icon(
                            d.isDrifted
                                ? Icons.warning_amber
                                : Icons.check_circle,
                            color: d.isDrifted
                                ? Colors.redAccent
                                : Colors.greenAccent,
                          ),
                          title: Text(d.date),
                          subtitle: Text(
                            d.explanation,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            '${(d.driftScore * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: d.isDrifted
                                  ? Colors.redAccent
                                  : Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )),
                ],
              ],
            ),
    );
  }
}

/// Slider that only allows reducing the limit (leftward).
class _LimitSlider extends StatefulWidget {
  final MonitoredApp app;

  const _LimitSlider({required this.app});

  @override
  State<_LimitSlider> createState() => _LimitSliderState();
}

class _LimitSliderState extends State<_LimitSlider> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.app.dailyLimitMinutes.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slider(
          value: _value,
          min: 1,
          max: widget.app.dailyLimitMinutes.toDouble(),
          divisions: widget.app.dailyLimitMinutes - 1 > 0
              ? widget.app.dailyLimitMinutes - 1
              : 1,
          label: '${_value.round()} min',
          onChanged: (v) => setState(() => _value = v),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1 min', style: TextStyle(fontSize: 11, color: Colors.grey)),
            Text('${widget.app.dailyLimitMinutes} min (current)',
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        if (_value.round() < widget.app.dailyLimitMinutes)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final monitor = context.read<MonitoringService>();
                final ok = await monitor.reduceLimit(
                    widget.app.packageName, _value.round());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok
                        ? 'Limit reduced to ${_value.round()} min. No going back.'
                        : 'Could not reduce limit.'),
                  ));
                  if (ok) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent),
              child: Text('Reduce to ${_value.round()} min'),
            ),
          ),
      ],
    );
  }
}
