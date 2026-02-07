import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/monitoring_service.dart';
import '../services/drift_detection_service.dart';
import '../services/auth_service.dart';
import '../services/permission_service.dart';
import '../models/monitored_app.dart';
import '../models/realtime_drift.dart';

/// Modern, accountability-focused dashboard with real-time drift summaries,
/// per-app usage cards, and behavioral nudges.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final monitor = context.read<MonitoringService>();
    final driftSvc = context.read<DriftDetectionService>();
    await monitor.refreshUsage();
    await driftSvc.computeAll(monitor.apps);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final monitor = context.watch<MonitoringService>();
    final driftSvc = context.watch<DriftDetectionService>();
    final apps = monitor.apps;
    final drifts = driftSvc.latestDrifts;

    final driftedCount = drifts.where((d) => d.isDrifted).length;
    final totalTracked = apps.length;
    final blockedCount = apps.where((a) => a.isBlocked).length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── PERMISSIONS WARNING BANNER (Android only) ──
          _buildPermissionsBanner(context),
          const SizedBox(height: 16),

          // ── GREETING & ACCOUNTABILITY NUDGE ──
          _buildHeader(context, driftedCount),
          const SizedBox(height: 20),

          // ── SUMMARY CARDS ROW ──
          Row(
            children: [
              _SummaryCard(
                icon: Icons.apps,
                label: 'Tracked',
                value: '$totalTracked',
                color: Colors.deepPurple,
              ),
              const SizedBox(width: 12),
              _SummaryCard(
                icon: Icons.trending_up,
                label: 'Drifted',
                value: '$driftedCount',
                color: driftedCount > 0 ? Colors.redAccent : Colors.green,
              ),
              const SizedBox(width: 12),
              _SummaryCard(
                icon: Icons.block,
                label: 'Blocked',
                value: '$blockedCount',
                color: blockedCount > 0 ? Colors.orange : Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── DRIFT SCORE CHART ──
          if (drifts.isNotEmpty) ...[
            Text('Real-Time Drift Scores',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'How far each app deviates from YOUR baseline today',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _buildDriftBarChart(drifts),
            const SizedBox(height: 24),
          ],

          // ── PER-APP USAGE CARDS ──
          Text('App Usage & Limits',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...apps.map((app) => _AppUsageCard(
                app: app,
                drift: drifts
                    .where((d) => d.packageName == app.packageName)
                    .firstOrNull,
              )),
          const SizedBox(height: 20),

          // ── ACCOUNTABILITY MESSAGE ──
          if (driftedCount > 0)
            Card(
              color: const Color(0xFF2D1B1B),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.privacy_tip,
                        color: Colors.orangeAccent, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You have $driftedCount app${driftedCount > 1 ? 's' : ''} '
                        'deviating from your normal pattern. '
                        'Stay mindful — your future self will thank you.',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (totalTracked == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.add_circle_outline,
                        size: 64, color: Colors.grey.shade600),
                    const SizedBox(height: 12),
                    const Text(
                      'No apps monitored yet.\nAdd apps to start tracking your behavior.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int driftedCount) {
    final auth = context.read<AuthService>();
    final name =
        auth.currentUser?.displayName?.split(' ').first ?? 'there';
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, $name',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          driftedCount > 0
              ? 'Your behavior is drifting. Time to recalibrate.'
              : 'You\'re on track. Keep it up.',
          style: TextStyle(
            color: driftedCount > 0 ? Colors.orangeAccent : Colors.greenAccent,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsBanner(BuildContext context) {
    final perms = context.watch<PermissionService>();
    
    // Only show on Android and if not all permissions granted
    if (Theme.of(context).platform != TargetPlatform.android || perms.allGranted) {
      return const SizedBox.shrink();
    }

    final missingPerms = <String>[];
    if (!perms.usageStatsGranted) missingPerms.add('Usage Stats');
    if (!perms.accessibilityGranted) missingPerms.add('Accessibility');
    if (!perms.overlayGranted) missingPerms.add('Overlay');

    return Container(
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_outlined, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${missingPerms.length} permission${missingPerms.length > 1 ? 's' : ''} needed',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            missingPerms.join(', '),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final scaffold = ScaffoldMessenger.of(context);
                scaffold.showSnackBar(
                  const SnackBar(
                    content: Text('Use the Settings button (⚙️) in the top-right to grant permissions'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text(
                'Grant Permissions',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriftBarChart(List<RealtimeDrift> drifts) {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 2.0,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, gi, rod, ri) {
                final d = drifts[group.x.toInt()];
                return BarTooltipItem(
                  '${d.packageName.split('.').last}\n'
                  '${(d.driftScore * 100).toStringAsFixed(0)}% drift',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (v, _) => Text(
                        '${(v * 100).toInt()}%',
                        style:
                            const TextStyle(fontSize: 9, color: Colors.grey),
                      )),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i >= drifts.length) return const SizedBox.shrink();
                  final label = drifts[i]
                      .packageName
                      .split('.')
                      .last;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label.length > 8 ? '${label.substring(0, 7)}…' : label,
                      style:
                          const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: List.generate(drifts.length, (i) {
            final d = drifts[i];
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: d.driftScore.clamp(0, 2),
                width: 18,
                color: d.isDrifted ? Colors.redAccent : Colors.greenAccent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

// ── Summary card widget ──
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Per-app usage card ──
class _AppUsageCard extends StatelessWidget {
  final MonitoredApp app;
  final RealtimeDrift? drift;

  const _AppUsageCard({required this.app, this.drift});

  @override
  Widget build(BuildContext context) {
    final usedMin = app.todayUsageSeconds / 60.0;
    final ratio = app.usageRatio.clamp(0.0, 1.0);
    final isWarn = ratio >= 0.8 && !app.isLimitExceeded;
    final isBlocked = app.isLimitExceeded || app.isBlocked;

    Color barColor;
    if (isBlocked) {
      barColor = Colors.red;
    } else if (isWarn) {
      barColor = Colors.orangeAccent;
    } else {
      barColor = Colors.greenAccent;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isBlocked
                      ? Icons.block
                      : (isWarn ? Icons.warning_amber : Icons.check_circle),
                  color: barColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    app.appName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Text(
                  '${usedMin.toStringAsFixed(0)}/${app.dailyLimitMinutes} min',
                  style: TextStyle(
                      color: isBlocked ? Colors.red : Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: Colors.grey.shade800,
                color: barColor,
              ),
            ),
            if (isBlocked)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '⛔ BLOCKED – Limit exceeded. You chose this boundary.',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
            if (isWarn && !isBlocked)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '⚠ ${app.remainingMinutes} minutes remaining. '
                  'Consider wrapping up.',
                  style: const TextStyle(
                      color: Colors.orangeAccent, fontSize: 12),
                ),
              ),
            if (drift != null && drift!.isDrifted)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '📊 ${drift!.explanation}',
                  style: const TextStyle(
                      color: Colors.amber, fontSize: 11, height: 1.3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
