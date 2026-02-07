import 'package:flutter/material.dart';

/// Shown on iOS, web, and desktop to inform the user that
/// real-time monitoring is Android-only for now.
class UnsupportedPlatformPage extends StatelessWidget {
  const UnsupportedPlatformPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phonelink_erase,
                  size: 80, color: Colors.grey.shade500),
              const SizedBox(height: 24),
              const Text(
                'Platform Not Supported Yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Real-time behavioral monitoring requires Android system APIs '
                  '(UsageStatsManager, Accessibility Service).\n\n'
                  'iOS, web, and desktop support is planned for a future release.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, height: 1.5),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                ),
                onPressed: () => Navigator.maybePop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
