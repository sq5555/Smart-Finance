import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'report_page.dart';
import 'widgets/base_page.dart';

class ViewSpendingAnalyticsPage extends StatefulWidget {
  const ViewSpendingAnalyticsPage({super.key});

  @override
  State<ViewSpendingAnalyticsPage> createState() =>
      _ViewSpendingAnalyticsPageState();
}

class _ViewSpendingAnalyticsPageState
    extends State<ViewSpendingAnalyticsPage> {
  int selectedYear = DateTime.now().year;
  String selectedMonth = DateFormat('MMMM').format(DateTime.now());

  List<String> months = List.generate(
      12, (index) => DateFormat('MMMM').format(DateTime(0, index + 1)));
  List<int> years = List.generate(30, (index) => 2020 + index);

  // 数据变量
  double totalIncome = 0.0;
  double totalExpenditure = 0.0;
  double balance = 0.0;
  double saving = 0.0;
  Map<String, double> categoryExpenditures = {};

  late String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      fetchData();
    }
  }

  Future<void> fetchData() async {
    try {
      // 获取选择的月份对应的数字
      final monthIndex = months.indexOf(selectedMonth) + 1;
      final monthKey = '${selectedYear}_${monthIndex.toString().padLeft(2, '0')}';

      // 获取该月的income数据
      double income = 0;
      QuerySnapshot incomeSnapshot = await _firestore
          .collection('financialData')
          .doc(userId)
          .collection('income')
          .get();

      for (var doc in incomeSnapshot.docs) {
        final incomeData = doc.data() as Map<String, dynamic>;
        final date = (incomeData['date'] as Timestamp).toDate();
        if (date.month == monthIndex && date.year == selectedYear) {
          income += (incomeData['amount'] ?? 0).toDouble();
        }
      }

      // 获取该月的expenditure数据
      double expenditure = 0;
      Map<String, double> categories = {};

      QuerySnapshot expenditureSnapshot = await _firestore
          .collection('financialData')
          .doc(userId)
          .collection('expenditure')
          .get();

      for (var doc in expenditureSnapshot.docs) {
        final expenditureData = doc.data() as Map<String, dynamic>;
        final date = (expenditureData['date'] as Timestamp).toDate();
        if (date.month == monthIndex && date.year == selectedYear) {
          final amount = (expenditureData['amount'] ?? 0).toDouble();
          final category = expenditureData['category'] ?? 'Others';

          expenditure += amount;
          categories[category] = (categories[category] ?? 0) + amount;
        }
      }

      // 获取该月saving
      double currentSaving = 0;
      DocumentSnapshot doc = await _firestore.collection('financialData').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final savingHistory = data['savingHistory'] as Map<String, dynamic>?;
        if (savingHistory != null && savingHistory[monthKey] != null) {
          currentSaving = (savingHistory[monthKey]['amount'] ?? 0).toDouble();
        }
      }

      setState(() {
        totalIncome = income;
        totalExpenditure = expenditure;
        saving = currentSaving;
        balance = income - expenditure - currentSaving;
        categoryExpenditures = categories;
      });
    } catch (e) {
      debugPrint("Error fetching data: $e");
    }
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.black38),
              ),
              child: DropdownButton<int>(
                value: selectedYear,
                underline: SizedBox(),
                style: TextStyle(fontSize: 16, color: Colors.black),
                isExpanded: true,
                items: years
                    .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedYear = value!);
                  fetchData(); // 获取新数据
                },
              ),
            ),
          ),
          SizedBox(width: 16),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.black38),
              ),
              child: DropdownButton<String>(
                value: selectedMonth,
                underline: SizedBox(),
                style: TextStyle(fontSize: 16, color: Colors.black),
                isExpanded: true,
                items: months
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedMonth = value!);
                  fetchData(); // 获取新数据
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    if (categoryExpenditures.isEmpty) {
      return [
        PieChartSectionData(
          color: Colors.grey,
          value: 1,
          title: 'No Data',
          radius: 120,
          titleStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ];
    }

    final colors = [
      Color.fromARGB(255, 45, 116, 152),
      Color.fromARGB(255, 117, 174, 220),
      Color.fromARGB(255, 76, 175, 155),
      Color.fromARGB(255, 134, 229, 255),
      Color.fromARGB(255, 64, 237, 225),
      Color.fromARGB(255, 255, 193, 7),
      Color.fromARGB(255, 156, 39, 176),
      Color.fromARGB(255, 255, 87, 34),
    ];

    final total = categoryExpenditures.values.reduce((a, b) => a + b);
    final entries = categoryExpenditures.entries.toList();

    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value.key;
      final amount = entry.value.value;
      final percentage = total > 0 ? (amount / total * 100).round() : 0;

      // 只显示百分比，不显示category名称
      final shouldShowText = percentage >= 1; // 显示1%以上的文字，让所有百分比都显示

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: amount,
        title: shouldShowText ? '$percentage%' : '', // 只显示百分比
        radius: 120,
        titleStyle: TextStyle(
          fontSize: 12, // 稍微增大字体
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titlePositionPercentageOffset: 0.6, // 调整文字位置
      );
    }).toList();
  }

  // 获取颜色列表（与饼图保持一致）
  List<Color> _getColors() {
    return [
      Color.fromARGB(255, 45, 116, 152),
      Color.fromARGB(255, 117, 174, 220),
      Color.fromARGB(255, 76, 175, 155),
      Color.fromARGB(255, 134, 229, 255),
      Color.fromARGB(255, 64, 237, 225),
      Color.fromARGB(255, 255, 193, 7),
      Color.fromARGB(255, 156, 39, 176),
      Color.fromARGB(255, 255, 87, 34),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      username: 'John Doe',
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 254, 199, 217),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 顶部间距（为BasePage的固定菜单留出空间）
                  SizedBox(height: 60),

                  // 标题
                   Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.analytics,
                        size: 30,
                        color: const Color.fromARGB(255, 199, 21, 133),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'View Spending Analytics',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 199, 21, 133),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Date selector
                  _buildDateSelector(),
                  SizedBox(height: 20),

                  // 饼图（更紧凑）
                  SizedBox(
                    height: 320,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 1,
                        centerSpaceRadius: 0,
                        sections: _buildPieChartSections(),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),

                  // 添加图例
                  if (categoryExpenditures.isNotEmpty) ...[
                    Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expenditure Categories:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 195, 98, 138),
                            ),
                          ),
                          SizedBox(height: 10),
                          ...categoryExpenditures.entries.toList().asMap().entries.map((entry) {
                            final index = entry.key;
                            final category = entry.value.key;
                            final amount = entry.value.value;
                            final total = categoryExpenditures.values.reduce((a, b) => a + b);
                            final percentage = total > 0 ? (amount / total * 100).round() : 0;
                            final colors = _getColors();

                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  // 颜色小圆圈
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: colors[index % colors.length],
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black, width: 1),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  // Category名称
                                  Expanded(
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  // 金额和百分比
                                  Flexible(
                                    child: Text(
                                      'RM ${amount.toStringAsFixed(2)} ($percentage%)',
                                      textAlign: TextAlign.right,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color.fromARGB(255, 195, 98, 138),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    SizedBox(height: 15),
                  ],

                  // 信息框
                  _buildInfoBox('Total Income:', 'RM ${totalIncome.toStringAsFixed(2)}', Colors.green),
                  SizedBox(height: 8),
                  _buildInfoBox('Total Expenditure:', 'RM ${totalExpenditure.toStringAsFixed(2)}', Colors.red),
                  SizedBox(height: 8),
                  _buildInfoBox('Saving:', 'RM ${saving.toStringAsFixed(2)}', Colors.purple),
                  SizedBox(height: 8),
                  _buildInfoBox('Balance:', 'RM ${balance.toStringAsFixed(2)}', Colors.blue),
                  SizedBox(height: 15),

                  // 按钮
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ReportPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding:
                        EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Generate Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(String title, String value, Color valueColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            spreadRadius: 1.5,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
