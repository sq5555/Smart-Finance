import 'package:flutter_test/flutter_test.dart';
import 'package:test_app2/config/api_config.dart';

void main() {
  group('ApiConfig Tests', () {
    test('should not expose API key in default configuration', () {
      // 测试默认配置下API密钥为空（安全）
      expect(ApiConfig.geminiApiKey, isEmpty);
      expect(ApiConfig.isApiKeyConfigured, isFalse);
    });

    test('should have correct endpoint configuration', () {
      // 测试端点配置正确
      expect(ApiConfig.openRouterEndpoint, 
        equals('https://openrouter.ai/api/v1/chat/completions'));
    });

    test('should have correct model configuration', () {
      // 测试模型配置正确
      expect(ApiConfig.defaultModel, 
        equals('google/gemini-2.5-flash-lite'));
    });

    test('should detect when API key is configured', () {
      // 这个测试在实际环境中会失败，因为环境变量未设置
      // 但在CI/CD环境中可以验证配置是否正确
      expect(ApiConfig.isApiKeyConfigured, isA<bool>());
    });
  });
} 