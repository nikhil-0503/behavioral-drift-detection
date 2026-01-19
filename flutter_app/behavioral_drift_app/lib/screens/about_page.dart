// import 'package:flutter/material.dart';

// class AboutPage extends StatelessWidget {
//   const AboutPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('About'),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: const [
//             Text(
//               'Behavioral Drift Detection',
//               style: TextStyle(
//                 fontSize: 26,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             SizedBox(height: 16),

//             Text(
//               'Project Overview',
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             SizedBox(height: 8),

//             Text(
//               'This project focuses on detecting behavioral drift in data over time. '
//               'Behavioral drift occurs when patterns in user behavior or system activity '
//               'change compared to historical data. Identifying this drift early helps '
//               'improve model reliability and system decision-making.',
//               style: TextStyle(fontSize: 16),
//             ),
//             SizedBox(height: 16),

//             Text(
//               'How It Works',
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             SizedBox(height: 8),

//             Text(
//               '• Drift metrics are generated using machine learning models.\n'
//               '• The results are stored as structured JSON data.\n'
//               '• The Flutter application visualizes these results in a user-friendly way.\n'
//               '• Each day is marked as drifted or non-drifted based on analysis.',
//               style: TextStyle(fontSize: 16),
//             ),
//             SizedBox(height: 16),

//             Text(
//               'Technology Stack',
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.w600,
//               ),
//             ),
//             SizedBox(height: 8),

//             Text(
//               '• Flutter (UI)\n'
//               '• Dart\n'
//               '• Machine Learning (backend analysis)\n'
//               '• JSON-based data exchange',
//               style: TextStyle(fontSize: 16),
//             ),
//             SizedBox(height: 24),

//             Text(
//               'This app is designed for academic and research purposes.',
//               style: TextStyle(
//                 fontSize: 14,
//                 color: Colors.grey,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("•  ", style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("About Timeo")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              "Timeo – Behavioral Drift Detection",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Timeo is a behavioral monitoring system that detects changes "
              "in a user's daily smartphone usage patterns using Machine Learning. "
              "It helps identify deviations from normal behavior over time.",
              style: TextStyle(fontSize: 15),
            ),

            _sectionTitle("📊 What does Timeo analyze?"),
            _bullet("Daily smartphone usage patterns"),
            _bullet("App usage behavior"),
            _bullet("Aggregated behavioral features"),
            _bullet("Long-term deviations from normal behavior"),

            _sectionTitle("🧠 How does it work?"),
            _bullet("Daily features are extracted from raw usage data"),
            _bullet("Multiple drift detection techniques are applied"),
            _bullet("Results are fused into a final drift decision"),
            _bullet("Detected drift is visualized in this app"),

            _sectionTitle("⚙️ Machine Learning Techniques"),
            _bullet("Isolation Forest (unsupervised anomaly detection)"),
            _bullet("Autoencoder (deep learning reconstruction error)"),
            _bullet("Statistical drift detection"),
            _bullet("Fusion logic for final decision"),

            _sectionTitle("🛠️ Tech Stack"),
            _bullet("Flutter & Dart (Mobile UI)"),
            _bullet("Python (Machine Learning pipeline)"),
            _bullet("Pandas, Scikit‑Learn, TensorFlow"),
            _bullet("Offline JSON‑based data integration"),

            const SizedBox(height: 20),

            const Text(
              "This application visualizes the output of a Machine Learning "
              "pipeline and does not collect live user data.",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
