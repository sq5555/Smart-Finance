import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:test_app2/login_page.dart'; // 登录页
import 'package:test_app2/home_page.dart'; // 首页
import 'package:test_app2/register_page.dart'; // 注册页
import 'package:test_app2/manageFinancialData_page.dart'; // 财务管理页
import 'package:test_app2/setBudget_page.dart'; // 设置预算页
import 'package:test_app2/viewSpendingAnalytics_page.dart'; // 支出分析页
import 'package:test_app2/report_page.dart'; // 报告页
import 'package:test_app2/expensesSuggestion_page.dart'; // 支出建议页
import 'firebase_options.dart'; // 自动生成的配置文件
import 'userProfile_page.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

   // 初始化时区
  tz.initializeTimeZones();

  // 初始化通知设置
  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidInitSettings,
  );
final androidPlugin = flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

final granted = await androidPlugin?.requestPermission();
print("🔔 通知权限是否被授予: $granted");

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'bill_channel', // 和 zonedSchedule 中一致
  'Bill Reminders',
  description: 'Reminder for upcoming bills',
  importance: Importance.max,
);

await androidPlugin?.createNotificationChannel(channel);
  await flutterLocalNotificationsPlugin.initialize(initSettings);
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
 await FlutterDownloader.initialize(
    debug: true, // 设置为 true 会在 logcat 输出调试日志
    ignoreSsl: true, // 如果你使用的是 HTTP 或自签名 HTTPS，可以设为 true
  );
   
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Finance',
      debugShowCheckedModeBanner: false,
      initialRoute: '/login', // 设置初始路由
      routes: {
        '/login': (context) => LoginPage(),
        '/register': (context) => RegisterPage(),
        '/home': (context) => HomePage(),
        '/manage_financial_data': (context) => ManageFinancialData(),
        '/set_budget': (context) => SetBudgetPage(),
        '/view_spending_analytics': (context) => ViewSpendingAnalyticsPage(),
        '/report': (context) => ReportPage(),
        '/expenses_suggestion': (context) => ExpensesSuggestionPage(),
        '/user_profile': (context) => UserProfilePage(),
      },
    );
  }
}
