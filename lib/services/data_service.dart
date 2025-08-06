import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;

class DataService {
  static Future<List<FlSpot>> getChartData(String username) async {
    final url = Uri.parse("http://10.0.2.2/smartFinance/get_chart_data.php");
    final response = await http.post(url, body: {"user_name": username});

    if (response.statusCode == 200) {
      List<dynamic> jsonData = json.decode(response.body);
      return jsonData.map((item) {
        double x = double.parse(item['day'].toString());
        double y = double.parse(item['amount'].toString());
        return FlSpot(x, y);
      }).toList();
    } else {
      throw Exception("Failed to load chart data");
    }
  }
}
