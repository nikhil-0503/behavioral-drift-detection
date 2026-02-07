import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/monitoring_service.dart';

/// Screen to add apps to the monitoring list.
/// Apps can only be ADDED — never removed (append-only).
class AppManagementPage extends StatefulWidget {
  const AppManagementPage({super.key});

  @override
  State<AppManagementPage> createState() => _AppManagementPageState();
}

class _AppManagementPageState extends State<AppManagementPage> {
  List<Map<String, String>> _installedApps = [];
  bool _loadingApps = true;
  final _searchController = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    final monitor = context.read<MonitoringService>();
    var apps = await monitor.getInstalledApps();
    
    // On web: add mock apps for testing
    if (kIsWeb && apps.isEmpty) {
      apps = [
        {'packageName': 'com.spotify.music', 'appName': 'Spotify'},
        {'packageName': 'com.netflix.mediaclient', 'appName': 'Netflix'},
        {'packageName': 'com.instagram.android', 'appName': 'Instagram'},
        {'packageName': 'com.twitter.android', 'appName': 'Twitter'},
        {'packageName': 'com.whatsapp', 'appName': 'WhatsApp'},
        {'packageName': 'com.facebook.katana', 'appName': 'Facebook'},
        {'packageName': 'com.youtube.android', 'appName': 'YouTube'},
        {'packageName': 'com.reddit.frontpage', 'appName': 'Reddit'},
      ];
    }
    
    if (mounted) {
      setState(() {
        _installedApps = apps;
        _loadingApps = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<MonitoringService>();
    final monitoredPkgs =
        monitor.apps.map((a) => a.packageName).toSet();

    final filtered = _installedApps.where((app) {
      final name = (app['appName'] ?? '').toLowerCase();
      return name.contains(_filter.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Apps to Monitor'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search installed apps…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
        ),
      ),
      body: _loadingApps
          ? const Center(child: CircularProgressIndicator())
          : filtered.isEmpty
              ? const Center(child: Text('No apps found'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final app = filtered[i];
                    final pkg = app['packageName'] ?? '';
                    final name = app['appName'] ?? pkg;
                    final alreadyAdded = monitoredPkgs.contains(pkg);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple.shade800,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text(pkg,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                      trailing: alreadyAdded
                          ? const Chip(
                              label: Text('Monitored',
                                  style: TextStyle(fontSize: 11)),
                              backgroundColor: Color(0xFF1E3A1E),
                              avatar: Icon(Icons.lock,
                                  size: 14, color: Colors.greenAccent),
                            )
                          : IconButton(
                              icon: const Icon(Icons.add_circle,
                                  color: Colors.deepPurpleAccent),
                              onPressed: () =>
                                  _showAddDialog(context, pkg, name),
                            ),
                    );
                  },
                ),
    );
  }

  Future<void> _showAddDialog(
      BuildContext context, String packageName, String appName) async {
    final limitController = TextEditingController(text: '30');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Monitor $appName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠ Once added, this app cannot be removed from monitoring. '
              'You can only reduce the time limit later, never increase it.\n\n'
              'Set your daily limit wisely.',
              style: TextStyle(fontSize: 13, color: Colors.orangeAccent),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: limitController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Daily limit (minutes)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent),
            child: const Text('Add & Lock'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final limit = int.tryParse(limitController.text) ?? 30;
      final monitor = context.read<MonitoringService>();
      final ok = await monitor.addApp(
        packageName: packageName,
        appName: appName,
        dailyLimitMinutes: limit.clamp(1, 1440),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? '$appName is now being monitored.'
              : '$appName is already monitored.'),
        ));
      }
    }
  }
}
