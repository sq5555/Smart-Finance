import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'editExpenditure_page.dart';
import 'widgets/base_page.dart';

class ExpenditurePage extends StatelessWidget {
  final Color backgroundColor = const Color.fromARGB(255, 255, 226, 233);
  final Color cardColor = const Color.fromARGB(255, 254, 199, 217);
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  final List<Map<String, dynamic>> expenditureItems = [
    {'icon': Icons.fastfood, 'label': 'Food Expenses'},
    {'icon': Icons.movie, 'label': 'Entertainment Expenses'},
    {'icon': Icons.home_outlined, 'label': 'Household Expenses'},
    {'icon': Icons.directions_bus, 'label': 'Transportation Expenses'},
    {'icon': Icons.health_and_safety, 'label': 'Insurance Cost'},
    {'icon': Icons.trending_up, 'label': 'Interest Cost'},
    {'icon': Icons.flight, 'label': 'Travel Expenses'},
    {'icon': Icons.flash_on, 'label': 'Unexpected Expenses'},
  ];

  ExpenditurePage({super.key});

  // 更新总支出金额的方法
  Future<void> _updateTotalExpenditure(double newAmount) async {
    try {
      // 获取当前总支出
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('financialData')
          .doc(userId)
          .get();

      double currentTotal = 0;
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        currentTotal = (data['expenditure'] ?? 0).toDouble();
      }

      // 更新总支出
      await FirebaseFirestore.instance
          .collection('financialData')
          .doc(userId)
          .set({
        'expenditure': currentTotal + newAmount,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating total expenditure: $e');
    }
  }

  void _showInputDialog(BuildContext context, String label, IconData icon) {
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus(); // 点击对话框外部收回键盘
        },
        child: AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Container(
            height: MediaQuery.of(context).size.height * 0.20, // 固定高度
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: Colors.black, size: 50),
                      const SizedBox(width: 15), // 减少间距
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 22, // 减小字体
                            fontWeight: FontWeight.bold,
                            color: Colors.pink[900],
                          ),
                          maxLines: 2, // 允许最多2行
                          overflow: TextOverflow.ellipsis, // 超出显示省略号
                          softWrap: true, // 启用软换行
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'RM 0.00',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Colors.black),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text("Cancel", style: TextStyle(color: Colors.black)),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final value = double.tryParse(controller.text);
                          if (value != null && value > 0) {
                            try {
                              // 更新支出数据
                              await FirebaseFirestore.instance
                                  .collection('financialData')
                                  .doc(userId)
                                  .collection('expenditure')
                                  .add({
                                'amount': value,
                                'category': label,
                                'date': Timestamp.now(),
                              });

                              // 更新总支出金额
                              await _updateTotalExpenditure(value);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Successfully saved $label: RM ${value.toStringAsFixed(2)}'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                ),
                              );

                              Navigator.pop(context, true);
                            } catch (e) {
                              // 显示错误提示
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error saving data: $e'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          } else {
                            // 显示输入错误提示
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid amount greater than 0'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text("Add"),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: backgroundColor,
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 120), // 预留按钮空间
                child: Column(
                  children: [
                    const SizedBox(height: 25),
                    const Text(
                      "Expenditure",
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 40),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 15,
                            crossAxisSpacing: 5,
                            childAspectRatio: 0.8,
                          ),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: expenditureItems.length,
                          itemBuilder: (context, index) {
                            final item = expenditureItems[index];
                            return GestureDetector(
                              onTap: () =>
                                  _showInputDialog(
                                    context,
                                    item['label'],
                                    item['icon'],
                                  ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(item['icon'], size: 50,
                                      color: Colors.black),
                                  const SizedBox(height: 8),
                                  Flexible(
                                    child: Text(
                                      item['label'],
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.black),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              // 固定右下角按钮（不随键盘浮动）
              Positioned(
                bottom: 20,
                right: 20,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EditExpenditurePage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Edit Records", style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}