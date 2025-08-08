import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'config/api_config.dart';

class GeminiService {
  
  final String apiKey = ApiConfig.geminiApiKey;
  final String endpoint = ApiConfig.openRouterEndpoint;
  final String model = ApiConfig.defaultModel;

  Future<String> getFinancialAdvice(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          "model": model,
          "messages": [
            {"role": "system", "content": "You are a helpful financial advisor. Provide clear, actionable advice based on the user's financial data."},
            {"role": "user", "content": prompt}
          ],
          "max_tokens": 1000,
          "temperature": 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data['choices'] != null &&
            data['choices'].isNotEmpty &&
            data['choices'][0]['message'] != null) {

          String content = data['choices'][0]['message']['content'];

          if (content.isNotEmpty) {
            return content;
          } else {
            throw Exception('API returned empty content');
          }
        } else {
          throw Exception('Invalid API response format');
        }
      } else {
        throw Exception('API request failed (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('GeminiService error: $e');
      if (e is FormatException) {
        throw Exception('Response data format error: $e');
      } else if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Unknown error: $e');
      }
    }
  }
}
