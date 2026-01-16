import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/drift_day.dart';

class DriftRepository {
  static Future<List<DriftDay>> load() async {
    final jsonStr = await rootBundle.loadString(
      'assets/drift_results.json',
    );

    final List data = json.decode(jsonStr);
    return data.map((e) => DriftDay.fromJson(e)).toList();
  }
}
