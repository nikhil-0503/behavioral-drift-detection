import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/permission_service.dart';
import 'services/monitoring_service.dart';
import 'services/drift_detection_service.dart';

import 'screens/login_page.dart';
import 'screens/permission_wizard.dart';
import 'screens/dashboard_page.dart';
import 'screens/stats_page.dart';
import 'screens/logs_page.dart';
import 'screens/about_page.dart';
import 'screens/app_management_page.dart';
import 'screens/unsupported_platform_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  runApp(const TimeoApp());
}

class TimeoApp extends StatefulWidget {
  const TimeoApp({super.key});

  @override
  State<TimeoApp> createState() => _TimeoAppState();
}

class _TimeoAppState extends State<TimeoApp> {
  bool isDark = true;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => PermissionService()),
        ChangeNotifierProvider(create: (_) => MonitoringService()),
        ChangeNotifierProvider(create: (_) => DriftDetectionService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,

        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,

        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.deepPurple,
          brightness: Brightness.light,
        ),

        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.deepPurple,
          brightness: Brightness.dark,
        ),

        initialRoute: '/',

        routes: {
          '/': (context) => const _AuthGate(),
          '/login': (context) => const LoginPage(),
          '/home': (context) => _HomeShell(
                onToggleTheme: (v) => setState(() => isDark = v),
                isDark: isDark,
              ),
          '/add_app': (context) =>
              _platformGuard(const AppManagementPage()),
          '/unsupported': (context) => const UnsupportedPlatformPage(),
        },
      ),
    );
  }

  /// Returns the child on Android; allows on web for testing.
  Widget _platformGuard(Widget child) {
    if (defaultTargetPlatform == TargetPlatform.android || kIsWeb) return child;
    return const UnsupportedPlatformPage();
  }
}

/// Decides initial route based on auth state.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isAvailable) {
      return _HomeShell(
        onToggleTheme: (_) {},
        isDark: true,
      );
    }
    // Always show login first, even on web
    // Only show dashboard after successful authentication
    if (auth.isSignedIn) {
      return _HomeShell(
        onToggleTheme: (_) {},
        isDark: true,
      );
    }
    // Always show login page when not signed in
    return const LoginPage();
  }
}

/// Main home shell with bottom navigation.
/// Keeps existing Stats, Logs, About pages and adds the new Dashboard tab.
class _HomeShell extends StatefulWidget {
  final ValueChanged<bool> onToggleTheme;
  final bool isDark;

  const _HomeShell({
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Initialise monitoring service on first load (Android only)
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final monitor = context.read<MonitoringService>();
        await monitor.init();
        context.read<PermissionService>().checkAll();
        // Auto-start foreground service for real-time blocking
        await monitor.startForegroundService();
      });
    }
  }

  void _showPermissionsDialog(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions not needed on this platform')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _PermissionsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardPage(), // Real-time dashboard
      const StatsPage(), // Existing offline drift stats
      const LogsPage(), // Existing drift logs
      const AboutPage(), // About
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Timeo",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.6,
          ),
        ),
        actions: [
          if (defaultTargetPlatform == TargetPlatform.android || kIsWeb)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add App',
              onPressed: () => Navigator.pushNamed(context, '/add_app'),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings & Permissions',
            onPressed: () => _showPermissionsDialog(context),
          ),
          Switch(
            value: widget.isDark,
            onChanged: widget.onToggleTheme,
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'signout') {
                await context.read<AuthService>().signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'signout', child: Text('Sign Out')),
            ],
          ),
        ],
      ),

      body: pages[_index],

      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Offline Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            selectedIcon: Icon(Icons.list_alt_rounded),
            label: 'Logs',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'About',
          ),
        ],
      ),
    );
  }
}
/// Permissions dialog for Android to request/check permissions
class _PermissionsDialog extends StatefulWidget {
  @override
  State<_PermissionsDialog> createState() => _PermissionsDialogState();
}

class _PermissionsDialogState extends State<_PermissionsDialog> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    context.read<PermissionService>().checkAll();
  }

  Future<void> _requestPermission(Future<void> Function() requestFn) async {
    setState(() => _loading = true);
    try {
      await requestFn();
      // Check again after requesting
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await context.read<PermissionService>().checkAll();
      }
    } catch (e) {
      debugPrint('Error requesting permission: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perms = context.watch<PermissionService>();
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    return AlertDialog(
      title: const Text('App Permissions'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Grant permissions to enable full functionality',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            // Usage Stats
            _PermissionTile(
              icon: Icons.bar_chart,
              title: 'Usage Stats Access',
              description: 'Monitor app usage patterns',
              granted: perms.usageStatsGranted,
              onRequest: _loading
                  ? null
                  : () => _requestPermission(
                        context.read<PermissionService>().requestUsageStats,
                      ),
            ),
            const SizedBox(height: 12),
            // Accessibility
            _PermissionTile(
              icon: Icons.accessibility,
              title: 'Accessibility Service',
              description: 'Detect active app & block overlays',
              granted: perms.accessibilityGranted,
              onRequest: _loading
                  ? null
                  : () => _requestPermission(
                        context.read<PermissionService>().requestAccessibility,
                      ),
            ),
            const SizedBox(height: 12),
            // Overlay
            _PermissionTile(
              icon: Icons.layers,
              title: 'Overlay Permission',
              description: 'Show blocking screen on limit',
              granted: perms.overlayGranted,
              onRequest: _loading
                  ? null
                  : () => _requestPermission(
                        context.read<PermissionService>().requestOverlay,
                      ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final VoidCallback? onRequest;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: granted ? Colors.green : Colors.grey.shade400,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: granted ? Colors.green : Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (granted)
            const Icon(Icons.check_circle, color: Colors.green)
          else
            ElevatedButton(
              onPressed: onRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text(
                'Grant',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}