import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Behavioral Drift Detection',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            Text(
              'Project Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),

            Text(
              'This project focuses on detecting behavioral drift in data over time. '
              'Behavioral drift occurs when patterns in user behavior or system activity '
              'change compared to historical data. Identifying this drift early helps '
              'improve model reliability and system decision-making.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),

            Text(
              'How It Works',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),

            Text(
              '• Drift metrics are generated using machine learning models.\n'
              '• The results are stored as structured JSON data.\n'
              '• The Flutter application visualizes these results in a user-friendly way.\n'
              '• Each day is marked as drifted or non-drifted based on analysis.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),

            Text(
              'Technology Stack',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),

            Text(
              '• Flutter (UI)\n'
              '• Dart\n'
              '• Machine Learning (backend analysis)\n'
              '• JSON-based data exchange',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 24),

            Text(
              'This app is designed for academic and research purposes.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
