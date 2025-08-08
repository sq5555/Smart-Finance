import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:test_app2/login_page.dart'; 
import 'package:test_app2/home_page.dart'; 
import 'package:test_app2/register_page.dart'; 
import 'package:test_app2/manageFinancialData_page.dart'; 
import 'package:test_app2/setBudget_page.dart'; 
import 'package:test_app2/viewSpendingAnalytics_page.dart'; 
import 'package:test_app2/report_page.dart'; 
import 'package:test_app2/expensesSuggestion_page.dart'; 
import 'firebase_options.dart'; 
import 'userProfile_page.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;



final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
   
  tz.initializeTimeZones();

  
  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidInitSettings,
  );
final androidPlugin = flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

final granted = await androidPlugin?.requestPermission();
print("🔔 Notify whether permission has been granted: $granted");

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'bill_channel', 
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
    debug: true, 
    ignoreSsl: true, 
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
      initialRoute: '/login', 
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
