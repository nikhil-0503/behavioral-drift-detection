import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/permission_service.dart';
import 'services/monitoring_service.dart';
import 'services/drift_detection_service.dart';
import 'services/user_config_sync_service.dart';
import 'services/device_binding_service.dart';

import 'screens/login_page.dart';
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
        ChangeNotifierProvider(create: (_) => UserConfigSyncService()),
        ChangeNotifierProvider(create: (_) => DeviceBindingService()),
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
    if (!auth.isAvailable || auth.isGuestMode) {
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
        // Refresh app names from PackageManager for accuracy
        await monitor.refreshAppNames();
        // Sync config from/to Firestore if signed in
        final auth = context.read<AuthService>();
        if (auth.isSignedIn) {
          final sync = context.read<UserConfigSyncService>();
          await sync.syncBidirectional();
          // Re-init monitoring after sync may have added new apps
          await monitor.init();
          // Verify device binding
          final binding = context.read<DeviceBindingService>();
          final ok = await binding.verifyDeviceBinding();
          if (!ok && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This account is bound to another device. '
                  'Some features may be restricted.',
                ),
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      });
    }
  }

  void _openNextMissingPermission(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions not needed on this platform')),
      );
      return;
    }

    final perms = context.read<PermissionService>();
    if (!perms.usageStatsGranted) {
      perms.requestUsageStats();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening Usage Stats settings…')),
      );
    } else if (!perms.accessibilityGranted) {
      perms.requestAccessibility();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening Accessibility settings…')),
      );
    } else if (!perms.overlayGranted) {
      perms.requestOverlay();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening Overlay settings…')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All permissions already granted ✓')),
      );
    }
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
            onPressed: () => _openNextMissingPermission(context),
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