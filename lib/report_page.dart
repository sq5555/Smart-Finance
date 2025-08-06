import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'widgets/base_page.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';


class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String selectedYear = DateTime.now().year.toString();
  String selectedMonth = DateFormat('MMMM').format(DateTime.now());
  final TextEditingController _fileNameController = TextEditingController(text: 'report.pdf');

  final List<String> years = List.generate(30, (index) => (2020 + index).toString());
  final List<String> months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  // 数据变量
  double totalIncome = 0.0;
  double totalExpenditure = 0.0;
  double totalSaving = 0.0;
  double budget = 0.0;
  double remainingBudget = 0.0;

  List<Map<String, dynamic>> incomeDetails = [];
  List<Map<String, dynamic>> expenditureDetails = [];

  late String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      fetchReportData();
    }
  }

  Future<void> fetchReportData() async {
    try {
      // 获取选择的月份对应的数字
      final monthIndex = months.indexOf(selectedMonth) + 1;
      final year = int.parse(selectedYear);

      // 获取budget
      DocumentSnapshot budgetDoc = await _firestore.collection('financialData').doc(userId).get();
      if (budgetDoc.exists) {
        final data = budgetDoc.data() as Map<String, dynamic>;
        final budgets = data['budgets'] as Map<String, dynamic>?;
        final monthKey = '${year}_$selectedMonth';
        debugPrint("Looking for budget with key: $monthKey");
        debugPrint("Available budgets: $budgets");
        if (budgets != null && budgets[monthKey] != null) {
          budget = (budgets[monthKey] as num).toDouble();
          debugPrint("Found budget: $budget");
        } else {
          debugPrint("Budget not found for monthKey: $monthKey");
          budget = 0.0;
        }
      }

      // 获取该月的income数据
      double income = 0;
      Map<String, double> incomeCategories = {};
      QuerySnapshot incomeSnapshot = await _firestore
          .collection('financialData')
          .doc(userId)
          .collection('income')
          .get();

      for (var doc in incomeSnapshot.docs) {
        final incomeData = doc.data() as Map<String, dynamic>;
        final date = (incomeData['date'] as Timestamp).toDate();
        if (date.month == monthIndex && date.year == year) {
          final amount = (incomeData['amount'] ?? 0).toDouble();
          final category = incomeData['category'] ?? 'Other Income';

          income += amount;
          incomeCategories[category] = (incomeCategories[category] ?? 0) + amount;
        }
      }

      // 获取该月的expenditure数据
      double expenditure = 0;
      Map<String, double> expenditureCategories = {};
      QuerySnapshot expenditureSnapshot = await _firestore
          .collection('financialData')
          .doc(userId)
          .collection('expenditure')
          .get();

      for (var doc in expenditureSnapshot.docs) {
        final expenditureData = doc.data() as Map<String, dynamic>;
        final date = (expenditureData['date'] as Timestamp).toDate();
        if (date.month == monthIndex && date.year == year) {
          final amount = (expenditureData['amount'] ?? 0).toDouble();
          final category = expenditureData['category'] ?? 'Others';

          expenditure += amount;
          expenditureCategories[category] = (expenditureCategories[category] ?? 0) + amount;
        }
      }

      // 获取该月的saving数据
      double saving = 0;
      if (budgetDoc.exists) {
        final data = budgetDoc.data() as Map<String, dynamic>;
        final savingHistory = data['savingHistory'] as Map<String, dynamic>?;
        final savingMonthKey = '${year}_${monthIndex.toString().padLeft(2, '0')}';
        if (savingHistory != null && savingHistory[savingMonthKey] != null) {
          saving = (savingHistory[savingMonthKey]['amount'] ?? 0).toDouble();
        }
      }

      // 计算remaining budget
      double remaining = budget - expenditure - saving;

      // 转换数据格式
      List<Map<String, dynamic>> incomeList = incomeCategories.entries.map((entry) {
        return {
          'name': entry.key,
          'amount': 'RM ${entry.value.toStringAsFixed(2)}',
        };
      }).toList();

      List<Map<String, dynamic>> expenditureList = expenditureCategories.entries.map((entry) {
        return {
          'name': entry.key,
          'amount': 'RM ${entry.value.toStringAsFixed(2)}',
        };
      }).toList();

      setState(() {
        totalIncome = income;
        totalExpenditure = expenditure;
        totalSaving = saving;
        remainingBudget = remaining;
        incomeDetails = incomeList;
        expenditureDetails = expenditureList;
      });
    } catch (e) {
      debugPrint("Error fetching report data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      username: 'John Doe',
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 254, 199, 217),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // 标题和logo
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.fromARGB(255, 241, 166, 191),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Icon(
                        Icons.assessment,
                        size: 30,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        "Report",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 195, 98, 138),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20),

                // 年/月选择器 - 使用与viewSpendingAnalytics页面相同的样式
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.black38),
                      ),
                      child: DropdownButton<String>(
                        value: selectedYear,
                        underline: SizedBox(),
                        style: TextStyle(fontSize: 18, color: Colors.black),
                        items: years
                            .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                            .toList(),
                        onChanged: (value) {
                          setState(() => selectedYear = value!);
                          fetchReportData();
                        },
                      ),
                    ),
                    SizedBox(width: 20),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.black38),
                      ),
                      child: DropdownButton<String>(
                        value: selectedMonth,
                        underline: SizedBox(),
                        style: TextStyle(fontSize: 18, color: Colors.black),
                        items: months
                            .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                            .toList(),
                        onChanged: (value) {
                          setState(() => selectedMonth = value!);
                          fetchReportData();
                        },
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 25),

                // 报告白格
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade300,
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildOverviewItem('Total Income:', 'RM ${totalIncome.toStringAsFixed(2)}', const Color.fromARGB(255, 15, 15, 15)),
                          _buildOverviewItem('Total Expenditure:', 'RM ${totalExpenditure.toStringAsFixed(2)}', const Color.fromARGB(255, 17, 17, 17)),
                          _buildOverviewItem('Total Saving:', 'RM ${totalSaving.toStringAsFixed(2)}', const Color.fromARGB(255, 7, 7, 7)),
                          _buildOverviewItem('Budget:', 'RM ${budget.toStringAsFixed(2)}', const Color.fromARGB(255, 7, 7, 7)),
                          _buildOverviewItem('Remaining Budget:', 'RM ${remainingBudget.toStringAsFixed(2)}', const Color.fromARGB(255, 9, 9, 9)),

                          SizedBox(height: 25),

                          // 收入详情
                          if (incomeDetails.isNotEmpty)
                            Text('Income Details',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                          SizedBox(height: 15),
                          ...incomeDetails.map((item) => _buildDetailItem(item['name']!, item['amount']!)),

                          SizedBox(height: 25),

                          // 支出详情
                          if (expenditureDetails.isNotEmpty)
                            Text('Expenditure Details',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                          SizedBox(height: 15),
                          ...expenditureDetails.map((item) => _buildDetailItem(item['name']!, item['amount']!)),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // 导出按钮
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _showExportDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Export', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewItem(String title, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }

  void _showExportDialog() {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: const Color.fromARGB(255, 219, 170, 197),
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewInsets = MediaQuery.of(context).viewInsets;
            return AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: viewInsets.bottom + 20,
                left: 25,
                right: 25,
                top: 25,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Export Report',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _fileNameController,
                        decoration: InputDecoration(
                          hintText: 'File Name',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () async {
                          String fileName = _fileNameController.text.trim();
                          if (!fileName.toLowerCase().endsWith('.pdf')) {
                            fileName += '.pdf';
                          }
                          Navigator.of(context).pop();
                          await _exportReportAsPdf(fileName);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 214, 131, 179),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Download PDF',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}


 Future<void> _exportReportAsPdf(String fileName) async {
  try {
    final pdf = pw.Document();

    // 👉 在这里定义 _buildRow 方法
    pw.TableRow _buildRow(String title, String value) {
      return pw.TableRow(
        children: [
          pw.Container(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text(title, style: pw.TextStyle(fontSize: 12)),
          ),
          pw.Container(
            padding: pw.EdgeInsets.all(8),
            child: pw.Text(value, style: pw.TextStyle(fontSize: 12)),
          ),
        ],
      );
    }

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Financial Report',
                  style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800)),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.grey),
              pw.Text('Year: $selectedYear   Month: $selectedMonth',
                  style: pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 16),

              // 表格展示主要数据
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                columnWidths: {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(2),
                },
                children: [
                  _buildRow('Total Income', 'RM ${totalIncome.toStringAsFixed(2)}'),
                  _buildRow('Total Expenditure', 'RM ${totalExpenditure.toStringAsFixed(2)}'),
                  _buildRow('Total Saving', 'RM ${totalSaving.toStringAsFixed(2)}'),
                  _buildRow('Budget', 'RM ${budget.toStringAsFixed(2)}'),
                  _buildRow('Remaining Budget', 'RM ${remainingBudget.toStringAsFixed(2)}'),
                ],
              ),

              pw.SizedBox(height: 24),

              if (incomeDetails.isNotEmpty) ...[
                pw.Text('Income Details',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: incomeDetails.map((item) {
                    return pw.Text(
                      '${item['name']}: ${item['amount']}',
                      style: pw.TextStyle(fontSize: 12),
                    );
                  }).toList(),
                ),
                pw.SizedBox(height: 16),
              ],

              if (expenditureDetails.isNotEmpty) ...[
                pw.Text('Expenditure Details',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: expenditureDetails.map((item) {
                    return pw.Text(
                      '${item['name']}: ${item['amount']}',
                      style: pw.TextStyle(fontSize: 12),
                    );
                  }).toList(),
                ),
              ],
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final directory = Directory('/storage/emulated/0/Download');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved to Download folder as $fileName'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
}