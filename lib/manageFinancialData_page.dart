import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/base_page.dart';
import 'insertIncome_page.dart';
import 'insertExpenditure_page.dart';
import 'editBill_page.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class ManageFinancialData extends StatefulWidget {
  const ManageFinancialData({super.key});

  @override
  State<ManageFinancialData> createState() => _ManageFinancialDataState();
}

class _ManageFinancialDataState extends State<ManageFinancialData> {
  String income = "";
  String expenditure = "";
  String saving = "";
  String bill = "";

  late String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
      fetchFinancialData();
    } else {
      print("No user logged in.");
    }
  }

  Future<void> fetchFinancialData() async {
    try {
      DocumentSnapshot snapshot =
      await _firestore.collection('financialData').doc(userId).get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final List billsList = data['bills'] ?? [];
        final now = DateTime.now();
        double totalBill = 0;
        for (var billItem in billsList) {
          if (billItem['dueDate'] != null) {
            final dueDate = DateTime.parse(billItem['dueDate']);
            if (dueDate.year == now.year && dueDate.month == now.month) {
              totalBill += (billItem['amount'] ?? 0).toDouble();
            }
          }
        }

        double totalExpenditure = 0;
        QuerySnapshot expenditureSnapshot = await _firestore
            .collection('financialData')
            .doc(userId)
            .collection('expenditure')
            .get();

        for (var doc in expenditureSnapshot.docs) {
          final expenditureData = doc.data() as Map<String, dynamic>;
          final date = (expenditureData['date'] as Timestamp).toDate();
          if (date.month == now.month && date.year == now.year) {
            totalExpenditure += (expenditureData['amount'] ?? 0).toDouble();
          }
        }

        double totalIncome = 0;
        QuerySnapshot incomeSnapshot = await _firestore
            .collection('financialData')
            .doc(userId)
            .collection('income')
            .get();

        for (var doc in incomeSnapshot.docs) {
          final incomeData = doc.data() as Map<String, dynamic>;
          final date = (incomeData['date'] as Timestamp).toDate();
          if (date.month == now.month && date.year == now.year) {
            totalIncome += (incomeData['amount'] ?? 0).toDouble();
          }
        }

        double currentSaving = 0;
        final monthKey = '${now.year}_${now.month.toString().padLeft(2, '0')}';
        final savingHistory = data['savingHistory'] as Map<String, dynamic>?;
        if (savingHistory != null && savingHistory[monthKey] != null) {
          currentSaving = (savingHistory[monthKey]['amount'] ?? 0).toDouble();
        }

        setState(() {
          income = totalIncome.toStringAsFixed(2);
          expenditure = totalExpenditure.toStringAsFixed(2);
          saving = currentSaving.toStringAsFixed(2);
          bill = totalBill.toStringAsFixed(2);
        });
      }
    } catch (e) {
      print("Firebase fetch error: $e");
    }
  }

  Future<void> updateSavingWithMonth(double value) async {
    try {
      final now = DateTime.now();
      final monthKey = '${now.year}_${now.month.toString().padLeft(2, '0')}';
      await _firestore.collection('financialData').doc(userId).set({
        'savingHistory': {
          monthKey: {'amount': value, 'date': now.toIso8601String()}
        }
      }, SetOptions(merge: true));
    } catch (e) {
      print("Firebase saving update error: $e");
    }
  }

  Future<void> _showEditSavingDialog() async {
    TextEditingController savingController =
    TextEditingController(text: saving);
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Color.fromARGB(255, 247, 189, 210),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: const [
                  Icon(Icons.savings, color: Colors.black),
                  SizedBox(width: 10),
                  Text("Saving",
                      style: TextStyle(
                          fontSize: 20,
                          color: Color.fromARGB(255, 195, 98, 138),
                          fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 20),
              TextField(
                controller: savingController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30)),
                  labelText: "RM",
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                onTap: () {
                  savingController.clear();
                },
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      double? parsedSaving =
                      double.tryParse(savingController.text);
                      if (parsedSaving != null) {
                        await updateSavingWithMonth(parsedSaving);
                        await fetchFinancialData();
                        Navigator.of(context).pop();
                      } else {
                        print("Invalid input");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green),
                    child: Text("Add"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditBillDialog() async {
    TextEditingController amountController = TextEditingController();
    String selectedCategory = "Electricity";
    DateTime? selectedDate;
    bool isRecurring = false;
    String recurringId = Uuid().v4();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Color.fromARGB(255, 247, 189, 210),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: Container(
            height: MediaQuery.of(context).size.height * 0.4, // 使用屏幕高度的60%
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.receipt_long, color: Colors.black),
                          SizedBox(width: 10),
                          Text("Bill",
                              style: TextStyle(
                                  fontSize: 20,
                                  color: Color.fromARGB(255, 195, 98, 138),
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      SizedBox(height: 20),
                      Text("Category:"),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.black38),
                        ),
                        child: DropdownButton<String>(
                          value: selectedCategory,
                          isExpanded: true,
                          underline: SizedBox(),
                          icon: Icon(Icons.arrow_drop_down),
                          items: <String>[
                            "Electricity",
                            "Water",
                            "Internet",
                            "Phone"
                          ].map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          )).toList(),
                          onChanged: (value) =>
                              setState(() => selectedCategory = value!),
                        ),
                      ),
                      SizedBox(height: 15),
                      Text("Amount:"),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                      SizedBox(height: 15),
                      Text("Due Date:"),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 15, vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.black38),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedDate == null
                                    ? "Select Date"
                                    : DateFormat('dd/MM/yyyy')
                                    .format(selectedDate!),
                              ),
                              Icon(Icons.calendar_today),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: isRecurring,
                            onChanged: (val) =>
                                setState(() => isRecurring = val!),
                          ),
                          Flexible(child: Text("Automatically generated monthly", style: TextStyle(fontSize: 13))),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                textStyle: TextStyle(fontSize: 14),
                              ),
                              child: Text("Cancel"),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                             onPressed: () async {
  double? parsedAmount = double.tryParse(amountController.text);

  if (parsedAmount == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Please enter a valid amount.")),
    );
    return;
  }

  if (selectedDate == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Please select a due date.")),
    );
    return;
  }

  final newBill = {
    'category': selectedCategory,
    'amount': parsedAmount,
    'dueDate': selectedDate!.toIso8601String(),
    'isRecurring': isRecurring,
    'recurringId': isRecurring ? recurringId : null,
  };

  // ⚠️ 确保 'bills' 字段存在
  final docRef = _firestore.collection('financialData').doc(userId);
  final docSnapshot = await docRef.get();
  if (!docSnapshot.exists || !(docSnapshot.data()?['bills'] is List)) {
    await docRef.set({'bills': []}, SetOptions(merge: true));
  }

  // ⏰ 设置通知（提前 1 分钟）
  try {
  final now = DateTime.now();
  final scheduledDate = now.add(Duration(minutes: 1));
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      'Upcoming Bill',
      'Your $selectedCategory bill is due on ${DateFormat('dd MMM').format(selectedDate!)}',
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bill_channel',
          'Bill Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  } catch (e) {
    print("Notification error: $e");
  }

  // ✅ 添加账单
  try {
    await docRef.update({
      'bills': FieldValue.arrayUnion([newBill])
    });
    print("✅ Bill added to Firestore.");
    Navigator.of(context).pop();
    fetchFinancialData();
  } catch (e) {
    print("❌ Firestore update error: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to save bill.")),
    );
  }
},

                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: EdgeInsets.symmetric(vertical: 8),
                                textStyle: TextStyle(fontSize: 14),
                              ),
                              child: Text("Save"),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => EditBillPage()),
                                ).then((_) => fetchFinancialData());
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: EdgeInsets.symmetric(vertical: 8),
                                textStyle: TextStyle(fontSize: 14),
                              ),
                              child: Text("Edit"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStyledDateBox(String text, {bool isYear = false}) {
    return Container(
      width: isYear ? 100 : 140,
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Color.fromARGB(255, 241, 166, 191),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 3),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black,
          fontSize: isYear ? 20 : 16,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDataSection(
      String label, String value, VoidCallback? onEditPressed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 35, vertical: 28),
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 247, 189, 210),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('RM $value',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: onEditPressed,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 35, vertical: 28),
                backgroundColor: Color.fromARGB(255, 250, 180, 200),
                foregroundColor: Colors.black,
                side: BorderSide(color: Colors.black),
                textStyle:
                TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              child: Text("Add"),
            ),
          ],
        ),
        SizedBox(height: 15),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = DateFormat('MMMM').format(now);

    return BasePage(
      username: 'John Doe',
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 255, 229, 236),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部间距（为BasePage的固定菜单留出空间）
                  SizedBox(height: 50),
                  
                  // Title
                  Padding(
                    padding: EdgeInsets.only(right: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_wallet,
                            size: 30, color: Colors.black),
                        SizedBox(width: 8),
                        Text('Manage Financial Data',
                            style: TextStyle(
                                color: Color.fromARGB(255, 199, 21, 133),
                                fontWeight: FontWeight.bold,
                                fontSize: 22)),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      _buildStyledDateBox(year, isYear: true),
                      SizedBox(width: 20),
                      _buildStyledDateBox(month, isYear: false),
                      SizedBox(width: 60),
                    ],
                  ),
                  SizedBox(height: 20),
                  _buildDataSection("Income :", income, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => IncomePage()),
                    ).then((_) => fetchFinancialData());
                  }),
                  _buildDataSection("Expenditure :", expenditure, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ExpenditurePage()),
                    ).then((_) => fetchFinancialData());
                  }),
                  _buildDataSection("Saving :", saving, _showEditSavingDialog),
                  _buildDataSection("Bill :", bill, _showEditBillDialog),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
