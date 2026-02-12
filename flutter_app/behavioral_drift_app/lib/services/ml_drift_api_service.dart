import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/ml_drift_result.dart';

class MlDriftApiService {
  Future<List<MlDriftResult>> computeDriftForApps(
    List<Map<String, dynamic>> apps,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/ml/drift/apps');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'apps': apps}),
        )
        .timeout(ApiConfig.timeout);

    if (response.statusCode != 200) {
      throw Exception('ML drift API failed (${response.statusCode})');
    }

    final decoded = json.decode(response.body);
    if (decoded is! List) {
      throw Exception('Invalid ML drift response format');
    }

    return decoded
        .map((e) => MlDriftResult.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
