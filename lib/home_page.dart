
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'manageFinancialData_page.dart';
import 'setBudget_page.dart';
import 'viewSpendingAnalytics_page.dart';
import 'widgets/base_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  double remainingBudget = 0.0;
  List<Map<String, dynamic>> monthlyData = [];
  late String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String username = 'User';
  String avatarUrl = '';
  Future<void> checkAndShowBillNotifications() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final userId = user.uid;
  final firestore = FirebaseFirestore.instance;
  final now = DateTime.now();

  final doc = await firestore.collection('financialData').doc(userId).get();
  if (!doc.exists) return;

  final data = doc.data()!;
  final List billsList = data['bills'] ?? [];

  for (var bill in billsList) {
    if (bill['paid'] == true) continue;
    
    if (bill['dueDate'] == null) continue;

    final dueDate = DateTime.tryParse(bill['dueDate']);
    if (dueDate == null) continue;

    final difference = dueDate.difference(now).inDays;
    if (difference <= 3 && difference >=0) {
      // 如果两天后到期，立即提醒
      final category = bill['category'] ?? 'Unknown';
      final amount = bill['amount'] ?? 0;
      final formattedDate = DateFormat('dd MMM').format(dueDate);

      await flutterLocalNotificationsPlugin.show(
        dueDate.millisecondsSinceEpoch ~/ 1000, // ID 防重复
        'Upcoming Bill',
        'Your $category bill (RM $amount) is due on $formattedDate',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'bill_channel',
            'Bill Reminders',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  }
}

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      fetchHomeData();
      fetchUserProfile();
      checkAndShowBillNotifications();
    }
  }

  Future<void> fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('user_profiles').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          username = data['username'] ?? 'User';
          avatarUrl = data['profileImage'] ?? '';
        });
      }
    }
  }
  Future<void> fetchHomeData() async {
    try {
      // 获取当前月份的数据
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;
      final monthName = DateFormat('MMMM').format(now);
      final monthKey = '${currentYear}_$monthName';
      final savingMonthKey = '${currentYear}_${currentMonth.toString().padLeft(2, '0')}';

      // 获取budget - 从正确的路径
      DocumentSnapshot budgetDoc = await _firestore.collection('financialData').doc(userId).get();
      double currentBudget = 0;
      if (budgetDoc.exists) {
        final data = budgetDoc.data() as Map<String, dynamic>;
        final budgets = data['budgets'] as Map<String, dynamic>?;
        debugPrint("Budgets data: $budgets");
        debugPrint("Looking for monthKey: $monthKey");
        if (budgets != null && budgets[monthKey] != null) {
          currentBudget = (budgets[monthKey] as num).toDouble();
          debugPrint("Found budget: $currentBudget");
        } else {
          debugPrint("Budget not found for monthKey: $monthKey");
        }
      }

      // 获取当前月份的expenditures - 从collection
      double totalExpenditure = 0;
      QuerySnapshot expenditureSnapshot = await _firestore
          .collection('financialData')
          .doc(userId)
          .collection('expenditure')
          .get();

      for (var doc in expenditureSnapshot.docs) {
        final expenditureData = doc.data() as Map<String, dynamic>;
        final date = (expenditureData['date'] as Timestamp).toDate();
        if (date.month == currentMonth && date.year == currentYear) {
          totalExpenditure += (expenditureData['amount'] ?? 0).toDouble();
        }
      }

      // 获取当前月份的saving - 从savingHistory
      double currentSaving = 0;
      if (budgetDoc.exists) {
        final data = budgetDoc.data() as Map<String, dynamic>;
        final savingHistory = data['savingHistory'] as Map<String, dynamic>?;
        debugPrint("SavingHistory data: $savingHistory");
        debugPrint("Looking for savingMonthKey: $savingMonthKey");
        if (savingHistory != null && savingHistory[savingMonthKey] != null) {
          currentSaving = (savingHistory[savingMonthKey]['amount'] ?? 0).toDouble();
          debugPrint("Found saving: $currentSaving");
        } else {
          debugPrint("Saving not found for savingMonthKey: $savingMonthKey");
        }
      }

      // 计算remaining budget - 只减去expenditure和saving
      double remaining = currentBudget - totalExpenditure - currentSaving;

      // 调试信息
      debugPrint("Budget: $currentBudget");
      debugPrint("Expenditure: $totalExpenditure");
      debugPrint("Saving: $currentSaving");
      debugPrint("Remaining: $remaining");

      // 获取最近6个月的数据用于饼图
      List<Map<String, dynamic>> recentData = [];
      for (int i = 5; i >= 0; i--) {
        final targetDate = DateTime(currentYear, currentMonth - i, 1);
        final targetSavingMonthKey = '${targetDate.year}_${targetDate.month.toString().padLeft(2, '0')}';

        // 获取该月的expenditure
        double monthExpenditure = 0;
        for (var doc in expenditureSnapshot.docs) {
          final expenditureData = doc.data() as Map<String, dynamic>;
          final date = (expenditureData['date'] as Timestamp).toDate();
          if (date.month == targetDate.month && date.year == targetDate.year) {
            monthExpenditure += (expenditureData['amount'] ?? 0).toDouble();
          }
        }

        // 获取该月的saving
        double monthSaving = 0;
        if (budgetDoc.exists) {
          final data = budgetDoc.data() as Map<String, dynamic>;
          final savingHistory = data['savingHistory'] as Map<String, dynamic>?;
          if (savingHistory != null && savingHistory[targetSavingMonthKey] != null) {
            monthSaving = (savingHistory[targetSavingMonthKey]['amount'] ?? 0).toDouble();
          }
        }

        // 获取该月的income
        double monthIncome = 0;
        QuerySnapshot incomeSnapshot = await _firestore
            .collection('financialData')
            .doc(userId)
            .collection('income')
            .get();

        for (var doc in incomeSnapshot.docs) {
          final incomeData = doc.data() as Map<String, dynamic>;
          final date = (incomeData['date'] as Timestamp).toDate();
          if (date.month == targetDate.month && date.year == targetDate.year) {
            monthIncome += (incomeData['amount'] ?? 0).toDouble();
          }
        }

        recentData.add({
          'month': DateFormat('MMM').format(targetDate),
          'income': monthIncome,
          'expenditure': monthExpenditure,
          'saving': monthSaving,
        });
      }

      setState(() {
        remainingBudget = remaining;
        monthlyData = recentData;

        // 调试折线图数据
        debugPrint("=== 折线图数据 ===");
        for (int i = 0; i < recentData.length; i++) {
          final data = recentData[i];
          debugPrint("${data['month']}: Income=${data['income']}, Expenditure=${data['expenditure']}, Saving=${data['saving']}");
        }
      });
    } catch (e) {
      debugPrint("Error fetching home data: $e");
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ManageFinancialData()),
      ).then((_) => fetchHomeData());
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SetBudgetPage()),
      ).then((_) => fetchHomeData());
    }
    else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ViewSpendingAnalyticsPage()),
      ).then((_) => fetchHomeData());
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final year = now.year.toString();
    final monthName = DateFormat.MMMM().format(now);

    return BasePage(
      username: username,
      avatarUrl: avatarUrl,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 254, 199, 217),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 60),
                      Padding(
                        padding: const EdgeInsets.only(left: 20.0),
                        child: Row(
                          children: [
                            _buildDateBox(year, isYear: true),
                            SizedBox(width: 20),
                            _buildDateBox(monthName, isYear: false),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 100,
                          width: 230,
                          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          margin: EdgeInsets.only(left: 20),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 170, 231, 248),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black, width: 3),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Remaining Budget ：",
                                  style: TextStyle(
                                      color: Color.fromARGB(255, 61, 90, 120),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              SizedBox(height: 8),
                              Text("RM ${remainingBudget.toStringAsFixed(2)}",
                                  style: TextStyle(
                                      color: Color.fromARGB(255, 61, 90, 120),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                              child: Text(
                                'Amount (RM)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              height: 300,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Color.fromARGB(255, 204, 251, 255),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(8.0, 12.0, 12.0, 12.0),
                                child: LineChart(
                                  LineChartData(
                                    minY: 0,
                                    maxY: monthlyData.isEmpty ? 5000 : monthlyData.fold<double>(0, (max, data) {
                                      double maxValue = (data['income'] as double).clamp(0, double.infinity);
                                      maxValue = maxValue < (data['expenditure'] as double).clamp(0, double.infinity)
                                          ? (data['expenditure'] as double).clamp(0, double.infinity) : maxValue;
                                      maxValue = maxValue < (data['saving'] as double).clamp(0, double.infinity)
                                          ? (data['saving'] as double).clamp(0, double.infinity) : maxValue;
                                      return max < maxValue ? maxValue : max;
                                    }) * 1.2,
                                    backgroundColor: Color.fromARGB(255, 204, 251, 255),
                                    titlesData: FlTitlesData(
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: 1,
                                          getTitlesWidget: (value, _) {
                                            if (value >= 1 && value <= monthlyData.length) {
                                              return Text(monthlyData[value.toInt() - 1]['month']);
                                            } else {
                                              return Text('');
                                            }
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: 2000,
                                          reservedSize: 50,
                                          getTitlesWidget: (value, meta) {
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              space: 4,
                                              child: Text(
                                                '${(value / 1000).toInt()}k',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.black,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    gridData: FlGridData(show: true),
                                    borderData: FlBorderData(
                                      show: true,
                                      border: Border.all(color: Colors.black),
                                    ),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: monthlyData.asMap().entries.map((entry) {
                                          return FlSpot(entry.key + 1.0, (entry.value['income'] as double).clamp(0, double.infinity));
                                        }).toList(),
                                        isCurved: true,
                                        color: Colors.green,
                                        barWidth: 3,
                                        dotData: FlDotData(show: true),
                                      ),
                                      LineChartBarData(
                                        spots: monthlyData.asMap().entries.map((entry) {
                                          return FlSpot(entry.key + 1.0, (entry.value['expenditure'] as double).clamp(0, double.infinity));
                                        }).toList(),
                                        isCurved: true,
                                        color: Color.fromARGB(255, 25, 51, 200),
                                        barWidth: 3,
                                        dotData: FlDotData(show: true),
                                      ),
                                      LineChartBarData(
                                        spots: monthlyData.asMap().entries.map((entry) {
                                          return FlSpot(entry.key + 1.0, (entry.value['saving'] as double).clamp(0, double.infinity));
                                        }).toList(),
                                        isCurved: true,
                                        color: Color.fromARGB(255, 89, 241, 255),
                                        barWidth: 3,
                                        dotData: FlDotData(show: true),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 30, top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegend(Colors.green, 'Income'),
                            SizedBox(height: 8),
                            _buildLegend(Color.fromARGB(255, 25, 51, 200), 'Expenditure'),
                            SizedBox(height: 8),
                            _buildLegend(Color.fromARGB(255, 89, 241, 255), 'Saving'),
                          ],
                        ),
                      ),
                      SizedBox(height: 20), // 为底部导航栏留出空间
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          height: 100,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.black, width: 2)),
            color: Colors.white,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildNavItem(icon: Icons.account_balance_wallet, label: 'Manage\nFinance\nData', index: 0),
                VerticalDivider(width: 2, thickness: 2, color: Colors.black),
                _buildNavItem(icon: Icons.attach_money, label: 'Set\nBudget', index: 1),
                VerticalDivider(width: 2, thickness: 2, color: Colors.black),
                _buildNavItem(icon: Icons.bar_chart, label: 'View\nSpending\nAnalytics', index: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateBox(String text, {bool isYear = false}) {
    return Container(
      width: isYear ? 80 : 120, // 年份格子变短，月份格子变长
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Color.fromARGB(255, 197, 114, 141),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 3),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black, 
          fontSize: isYear ? 20 : 18, // 年份字体稍大，月份字体稍小
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ✅ 替换原本的 _buildLegend 函数
  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }


  // ✅ 替换原本的 _buildNavItem 函数
  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected
                    ? const Color.fromARGB(255, 168, 105, 152)
                    : const Color.fromARGB(255, 168, 105, 152),
              ),
              const SizedBox(height: 6), // 图标和文字之间的间距
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color.fromARGB(255, 8, 8, 8),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}









