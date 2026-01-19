// import 'dart:convert';
// import 'package:flutter/services.dart';
// import '../models/drift_day.dart';

// class DriftRepository {
//   static Future<List<DriftDay>> load() async {
//     final jsonStr = await rootBundle.loadString(
//       'assets/drift_results.json',
//     );

//     final List data = json.decode(jsonStr);
//     return data.map((e) => DriftDay.fromJson(e)).toList();
//   }
// }
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/drift_day.dart';

class DriftRepository {
  static Future<List<DriftDay>> load() async {
    try {
      // 1. Load the string
      final jsonStr = await rootBundle.loadString('assets/drift_results.json');
      
      // 2. Decode
      final List data = json.decode(jsonStr);
      
      // 3. Map to objects
      return data.map((e) => DriftDay.fromJson(e)).toList();
    } catch (e, stacktrace) {
      // THIS WILL PRINT THE EXACT ERROR IN YOUR CONSOLE
      print("❌ Error loading drift_results.json: $e");
      print("❌ Stacktrace: $stacktrace");
      
      // Return an empty list so the UI knows to stop loading
      return []; 
    }
  }
}