import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String apiUrl = 'http://10.0.2.2/smartFinance/register.php'; // PHP 文件的 URL
  static const String loginUrl = 'http://10.0.2.2/smartFinance/login.php';


  static Future<bool> login(String userName, String password) async {
    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        body: {
          'user_name': userName,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return data['message'] == 'login_success'; // 对应 login.php 中的返回
      } else {
        return false;
      }
    } catch (e) {
      print("Login error: $e");
      return false;
    }
  }

  static Future<bool> register(String userName, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'user_name': userName,
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        return data['message'] == '注册成功！';
      } else {
        return false;
      }
    } catch (e) {
      print("Error: $e");
      return false;
    }
  }
}
