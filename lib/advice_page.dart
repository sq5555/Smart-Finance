import 'package:flutter/material.dart';
import 'gemini_service.dart';  // 导入你写的服务文件
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdvicePage extends StatefulWidget {
  const AdvicePage({super.key});

  @override
  _AdvicePageState createState() => _AdvicePageState();
}

class _AdvicePageState extends State<AdvicePage> {
  final GeminiService geminiService = GeminiService();
  String advice = 'Loading advice...';

  @override
  void initState() {
    super.initState();
    fetchAdvice();
  }

  void fetchAdvice() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;
      if (userId == null) {
        setState(() { advice = 'User not logged in.'; });
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('financialData').doc(userId).get();
      final data = doc.data() ?? {};

      // 读取分类预算和支出
      final categoryBudgets = data['categoryBudgets'] is Map ? Map<String, dynamic>.from(data['categoryBudgets']) : {};
      final categoryExpenses = data['categoryExpenses'] is Map ? Map<String, dynamic>.from(data['categoryExpenses']) : {};

      // 读取目标、储蓄、债务
      final goal = data['goal'] ?? '';
      final debts = data['debts'] ?? 0;
      final savings = data['savings'] ?? 0;

      // 统计本月收入
      double totalIncome = 0;
      final incomeSnapshot = await FirebaseFirestore.instance.collection('financialData').doc(userId).collection('income').get();
      final now = DateTime.now();
      for (var doc in incomeSnapshot.docs) {
        final incomeData = doc.data();
        final date = (incomeData['date'] as Timestamp).toDate();
        if (date.month == now.month && date.year == now.year) {
          totalIncome += (incomeData['amount'] ?? 0).toDouble();
        }
      }

      // 统计本月支出
      double totalExpenditure = 0;
      final expenditureSnapshot = await FirebaseFirestore.instance.collection('financialData').doc(userId).collection('expenditure').get();
      for (var doc in expenditureSnapshot.docs) {
        final expData = doc.data();
        final date = (expData['date'] as Timestamp).toDate();
        if (date.month == now.month && date.year == now.year) {
          totalExpenditure += (expData['amount'] ?? 0).toDouble();
        }
      }

      // 拼接 prompt
      String prompt = '''
You are a helpful and expert financial advisor for a mobile finance management application. Your goal is to analyze user financial data and provide clear, actionable, and personalized advice or insights.

User's Financial Data for ${now.year}-${now.month}:
- Total Income: RM $totalIncome
- Total Expenditure: RM $totalExpenditure
- Total Savings: RM $savings
- Total Debts: RM $debts

Monthly Budget Categories:
${categoryBudgets.entries.map((e) => '${e.key}: RM ${e.value}').join('\n')}

Current Month's Actual Spending:
${categoryExpenses.entries.map((e) => '${e.key}: RM ${e.value}').join('\n')}

Financial Goals: $goal

Task:
1. Compare the user's actual spending against their budget for each category.
2. Identify categories where the user is over budget, under budget, or on track.
3. Calculate the overall budget surplus or deficit for the month.
4. Provide specific, actionable advice based on the comparison and the user's financial goals. Prioritize advice for areas where the user is over budget or could optimize spending for their goals.
5. Suggest general tips for improving financial health relevant to their situation.

Output Format:
Provide a concise, summary-style advice. Do NOT use JSON.
Start with an overall budget status. Then, for each category, provide a brief status (Over/Under/On Track) and a very short, actionable tip. Conclude with 2-3 general, actionable tips. Keep sentences short and direct for mobile display. Do not use any asterisk or * in your answer.
''';

      // 调用 Gemini
      String result = await geminiService.getFinancialAdvice(prompt);
      setState(() { advice = result.replaceAll('*', ''); });
    } catch (e) {
      setState(() { advice = 'Error getting advice: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Financial Advice')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(advice),
        ),
      ),
    );
  }
}
