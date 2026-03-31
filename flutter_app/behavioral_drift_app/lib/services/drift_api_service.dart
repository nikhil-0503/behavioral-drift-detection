import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/drift_day.dart';

class DriftApiService {
  Future<List<DriftDay>> fetchDriftDays({int? limit}) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/drift/days${limit != null ? '?limit=$limit' : ''}',
    );
    final response = await http.get(uri).timeout(ApiConfig.timeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to load drift days (${response.statusCode})');
    }

    final decoded = json.decode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid drift response format');
    }

    return decoded
        .map((e) => DriftDay.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
