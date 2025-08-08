class ApiConfig {
  
  static String get geminiApiKey {
    
    const String envApiKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envApiKey.isNotEmpty) {
      return envApiKey;
    }
    
    
    return '';
  }

  
  static bool get isApiKeyConfigured {
    return geminiApiKey.isNotEmpty;
  }

  
  static const String openRouterEndpoint = 'https://openrouter.ai/api/v1/chat/completions';
  
  
  static const String defaultModel = 'google/gemini-2.5-flash-lite';
} 