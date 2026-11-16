import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/rpg_models.dart';

class ApiService {
  final String baseUrl;
  final String userId;

  ApiService({
    this.baseUrl = 'http://127.0.0.1:8000',
    this.userId = 'demo-user-001',
  });

  Future<Map<String, dynamic>?> fetchProfile() async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/v1/profile/$userId'))
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<QuestModel?> createQuestFromOneLineAi({
    required String prompt,
    QuestDifficulty? overrideDifficulty,
  }) async {
    try {
      final body = <String, dynamic>{
        'user_id': userId,
        'prompt': prompt,
      };
      if (overrideDifficulty != null) {
        body['override_difficulty'] = QuestModel.difficultyToApi(overrideDifficulty);
      }

      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/v1/quests/create-from-ai'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 6));

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        return QuestModel.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> completeQuest({
    required String questId,
    required double actualValue,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/v1/quests/$questId/complete'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'actual_value': actualValue,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> applyPreset(String presetCode) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/api/v1/onboarding/preset'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'username': 'Нео-Искатель',
              'preset': presetCode,
            }),
          )
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
