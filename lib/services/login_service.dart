import 'package:http/http.dart' as http;

class LoginService {
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
        var data = response.body.trim();
        return data == 'login_success';
      } else {
        return false;
      }
    } catch (e) {
      print('Login Error: $e');
      return false;
    }
  }
}