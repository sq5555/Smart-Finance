# 🔐 安全注意事项

## API 密钥管理

### ⚠️ 重要提醒
- API 密钥目前存储在 `lib/config/api_config.dart` 中
- **生产环境部署前必须使用环境变量**

### 🛡️ 生产环境配置
```bash
# 设置环境变量
export GEMINI_API_KEY=your_actual_api_key_here
```

### 📝 最佳实践
1. 永远不要将API密钥提交到版本控制系统
2. 使用 `.env` 文件或环境变量管理敏感信息
3. 定期轮换API密钥
4. 监控API使用情况

### 🔄 当前状态
- ✅ API密钥已从 `gemini_service.dart` 移至配置文件
- ✅ 支持环境变量覆盖
- ⚠️ 开发环境仍包含硬编码密钥（仅用于开发）

## 下一步建议
1. 添加 `.env` 文件支持
2. 实施API密钥轮换策略
3. 添加使用量监控
