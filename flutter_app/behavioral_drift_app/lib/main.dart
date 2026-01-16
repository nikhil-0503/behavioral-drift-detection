// import 'package:flutter/material.dart';

// void main() {
//   runApp(const BehavioralDriftApp());
// }

// class BehavioralDriftApp extends StatelessWidget {
//   const BehavioralDriftApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Behavioral Drift Detection',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: const HomePage(),
//     );
//   }
// }

// class HomePage extends StatefulWidget {
//   const HomePage({super.key});

//   @override
//   State<HomePage> createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   int _currentIndex = 0;

//   final List<Widget> _screens = const [
//     DashboardScreen(),
//     TrendsScreen(),
//     AlertsScreen(),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Behavioral Drift Detection"),
//       ),
//       body: _screens[_currentIndex],
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _currentIndex,
//         onTap: (index) {
//           setState(() {
//             _currentIndex = index;
//           });
//         },
//         items: const [
//           BottomNavigationBarItem(
//             icon: Icon(Icons.dashboard),
//             label: 'Dashboard',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.show_chart),
//             label: 'Trends',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.notifications),
//             label: 'Alerts',
//           ),
//         ],
//       ),
//     );
//   }
// }

// class DashboardScreen extends StatelessWidget {
//   const DashboardScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             "Today's Overview",
//             style: TextStyle(
//               fontSize: 22,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 16),

//           Card(
//             elevation: 4,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: const [
//                   Text(
//                     "Behavior Status",
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                   SizedBox(height: 8),

//                   Text(
//                     "Normal",
//                     style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.green,
//                     ),
//                   ),

//                   Divider(height: 24),

//                   Text(
//                     "Screen Time: 4.5 hrs",
//                     style: TextStyle(fontSize: 16),
//                   ),
//                   SizedBox(height: 6),

//                   Text(
//                     "Unlock Count: 68",
//                     style: TextStyle(fontSize: 16),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }




// class TrendsScreen extends StatelessWidget {
//   const TrendsScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const Center(
//       child: Text(
//         "Trends Screen",
//         style: TextStyle(fontSize: 20),
//       ),
//     );
//   }
// }

// class AlertsScreen extends StatelessWidget {
//   const AlertsScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const Center(
//       child: Text(
//         "Alerts Screen",
//         style: TextStyle(fontSize: 20),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';

import 'screens/login_page.dart';
import 'screens/stats_page.dart';
import 'screens/logs_page.dart';
import 'screens/about_page.dart';

void main() {
  runApp(const TimeoApp());
}

class TimeoApp extends StatefulWidget {
  const TimeoApp({super.key});

  @override
  State<TimeoApp> createState() => _TimeoAppState();
}

class _TimeoAppState extends State<TimeoApp> {
  int _index = 0;
  bool isDark = true;

  final List<Widget> pages = const [
    StatsPage(), // MAIN
    LogsPage(),  // Logs / Summary
    AboutPage(), // About
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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

      initialRoute: "/",

      routes: {
        "/": (context) => const LoginPage(),

        "/home": (context) => Scaffold(
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
                  Switch(
                    value: isDark,
                    onChanged: (v) => setState(() => isDark = v),
                  ),
                ],
              ),

              body: pages[_index],

              bottomNavigationBar: BottomNavigationBar(
                currentIndex: _index,
                onTap: (i) => setState(() => _index = i),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.analytics),
                    label: "Stats",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.list),
                    label: "Logs",
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.info_outline),
                    label: "About",
                  ),
                ],
              ),
            ),
      },
    );
  }
}
