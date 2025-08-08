class ApiConfig {
  // 从环境变量或安全存储中获取API密钥
  static String get geminiApiKey {
    // 优先从环境变量获取
    const String envApiKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envApiKey.isNotEmpty) {
      return envApiKey;
    }
    
    // 开发环境下的API密钥（生产环境应使用环境变量）
    return '';
  }

  // 检查API密钥是否已配置
  static bool get isApiKeyConfigured {
    return geminiApiKey.isNotEmpty;
  }

  // OpenRouter endpoint
  static const String openRouterEndpoint = 'https://openrouter.ai/api/v1/chat/completions';
  
  // 默认模型
  static const String defaultModel = 'google/gemini-2.5-flash-lite';
} 