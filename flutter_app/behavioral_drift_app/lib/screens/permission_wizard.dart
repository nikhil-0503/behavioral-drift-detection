import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import 'package:provider/provider.dart';

/// Onboarding wizard that gates dashboard access behind required permissions.
/// Fail-closed: user cannot proceed without granting all three permissions.
class PermissionWizard extends StatefulWidget {
  const PermissionWizard({super.key});

  @override
  State<PermissionWizard> createState() => _PermissionWizardState();
}

class _PermissionWizardState extends State<PermissionWizard>
    with WidgetsBindingObserver {
  int _step = 0;

  final _steps = const [
    _PermStep(
      title: 'Usage Access',
      description:
          'We need to read app usage statistics to monitor your behavior patterns. '
          'This is essential for drift detection.',
      icon: Icons.bar_chart_rounded,
      permissionKey: 'usageStats',
    ),
    _PermStep(
      title: 'Accessibility Service',
      description:
          'The accessibility service allows us to detect which app is in the foreground '
          'and block apps when your set limit is exceeded.',
      icon: Icons.accessibility_new_rounded,
      permissionKey: 'accessibility',
    ),
    _PermStep(
      title: 'Overlay Permission',
      description:
          'Overlay permission lets us show a blocking screen when an app exceeds '
          'its time limit, keeping you accountable.',
      icon: Icons.layers_rounded,
      permissionKey: 'overlay',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final perm = context.read<PermissionService>();
    await perm.checkAll();
    if (mounted && perm.allGranted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _requestCurrent() {
    final perm = context.read<PermissionService>();
    switch (_steps[_step].permissionKey) {
      case 'usageStats':
        perm.requestUsageStats();
        break;
      case 'accessibility':
        perm.requestAccessibility();
        break;
      case 'overlay':
        perm.requestOverlay();
        break;
    }
  }

  bool _isGranted(PermissionService perm, String key) {
    switch (key) {
      case 'usageStats':
        return perm.usageStatsGranted;
      case 'accessibility':
        return perm.accessibilityGranted;
      case 'overlay':
        return perm.overlayGranted;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PermissionService>(
      builder: (context, perm, _) {
        final step = _steps[_step];
        final granted = _isGranted(perm, step.permissionKey);

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    // Step indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_steps.length, (i) {
                        final done = _isGranted(perm, _steps[i].permissionKey);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _step ? 32 : 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: done
                                ? Colors.greenAccent
                                : (i == _step
                                    ? Colors.deepPurpleAccent
                                    : Colors.white24),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 48),
                    Icon(step.icon, size: 100, color: Colors.deepPurpleAccent),
                    const SizedBox(height: 32),
                    Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      step.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15, color: Colors.white70, height: 1.5),
                    ),
                    const Spacer(),
                    if (granted)
                      const Chip(
                        avatar: Icon(Icons.check_circle, color: Colors.green),
                        label: Text('Granted'),
                        backgroundColor: Color(0xFF1E3A1E),
                        labelStyle: TextStyle(color: Colors.greenAccent),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.settings),
                          label: const Text('Grant Permission'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurpleAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _requestCurrent,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_step > 0)
                          TextButton(
                            onPressed: () => setState(() => _step--),
                            child: const Text('Back',
                                style: TextStyle(color: Colors.white54)),
                          )
                        else
                          const SizedBox.shrink(),
                        if (_step < _steps.length - 1)
                          TextButton(
                            onPressed: granted
                                ? () => setState(() => _step++)
                                : null,
                            child: Text(
                              'Next',
                              style: TextStyle(
                                color: granted
                                    ? Colors.deepPurpleAccent
                                    : Colors.white24,
                              ),
                            ),
                          )
                        else if (perm.allGranted)
                          ElevatedButton(
                            onPressed: () => Navigator.pushReplacementNamed(
                                context, '/home'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent),
                            child: const Text('Continue',
                                style: TextStyle(color: Colors.black)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PermStep {
  final String title;
  final String description;
  final IconData icon;
  final String permissionKey;

  const _PermStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.permissionKey,
  });
}
