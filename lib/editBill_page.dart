import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class EditBillPage extends StatefulWidget {
  const EditBillPage({super.key});

  @override
  State<EditBillPage> createState() => _EditBillPageState();
}

class _EditBillPageState extends State<EditBillPage> {
  final List<String> _billCategories = [
    'Electricity', 'Water', 'Internet', 'Phone'
  ];

  List<Map<String, dynamic>> _billDocs = [];
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late String userId;
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;
  List<Map<String, dynamic>> _allBillDocs = [];
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null) {
      userId = user.uid;
      _loadBillData();
    }
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _autoGenerateRecurringBills(List<Map<String, dynamic>> billsList) async {
    final now = DateTime.now();
    final recurringBills = billsList.where((b) => b['isRecurring'] == true).toList();
    
    final cancelledSnapshot = await _firestore
        .collection('financialData')
        .doc(userId)
        .collection('cancelledRecurringBills')
        .get();
    final cancelledIds = cancelledSnapshot.docs.map((d) => d.id).toSet();
    bool updated = false;
    for (var bill in recurringBills) {
      final dueDate = DateTime.parse(bill['dueDate']);
     
      if (dueDate.year == now.year && dueDate.month == now.month) continue;
      
      if (cancelledIds.contains(bill['recurringId'])) continue;
      
      final exists = billsList.any((b) =>
      b['recurringId'] == bill['recurringId'] &&
          DateTime.parse(b['dueDate']).year == now.year &&
          DateTime.parse(b['dueDate']).month == now.month
      );
      if (!exists) {
        
        final newBill = {
          ...bill,
          'dueDate': DateTime(now.year, now.month, dueDate.day).toIso8601String(),
          'paid': false,
          'paidDate': null,
        };
        billsList.add(newBill);
        updated = true;
      }
    }
    if (updated) {
      await _firestore.collection('financialData').doc(userId).update({'bills': billsList});
    }
  }

  Future<void> _loadBillData() async {
    try {
      DocumentSnapshot doc = await _firestore.collection('financialData').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final List<dynamic> bills = data['bills'] ?? [];
        List<Map<String, dynamic>> billsList = bills.map((bill) {
          if (bill is Map<String, dynamic>) {
            return {
              ...bill,
              'paid': bill['paid'] ?? false,
              'amount': bill['amount'] is int ? (bill['amount'] as int).toDouble() : bill['amount'],
            };
          } else {
            return <String, dynamic>{};
          }
        }).where((bill) => bill.isNotEmpty).toList();
        
        await _autoGenerateRecurringBills(billsList);
        
        DocumentSnapshot doc2 = await _firestore.collection('financialData').doc(userId).get();
        final List<dynamic> bills2 = (doc2.data() as Map<String, dynamic>)['bills'] ?? [];
        List<Map<String, dynamic>> billsList2 = bills2.map((bill) {
          if (bill is Map<String, dynamic>) {
            return {
              ...bill,
              'paid': bill['paid'] ?? false,
              'amount': bill['amount'] is int ? (bill['amount'] as int).toDouble() : bill['amount'],
            };
          } else {
            return <String, dynamic>{};
          }
        }).where((bill) => bill.isNotEmpty).toList();
        
        billsList2.sort((a, b) {
          final aDate = DateTime.parse(a['dueDate']);
          final bDate = DateTime.parse(b['dueDate']);
          return aDate.compareTo(bDate);
        });
        setState(() {
          _allBillDocs = billsList2;
          _billDocs = billsList2.where((b) {
            final d = DateTime.parse(b['dueDate']);
            return d.year == selectedYear && d.month == selectedMonth;
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading bill data: $e');
    }
  }

  void _filterBills() {
    setState(() {
      _billDocs = _allBillDocs.where((b) {
        final d = DateTime.parse(b['dueDate']);
        return d.year == selectedYear && d.month == selectedMonth;
      }).toList();
    });
  }

  Widget _buildYearMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DropdownButton<int>(
          value: selectedYear,
          items: List.generate(10, (i) => DateTime.now().year - 5 + i)
              .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
              .toList(),
          onChanged: (v) {
            setState(() => selectedYear = v!);
            _filterBills();
          },
        ),
        const SizedBox(width: 10),
        DropdownButton<int>(
          value: selectedMonth,
          items: List.generate(12, (i) => i + 1)
              .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
              .toList(),
          onChanged: (v) {
            setState(() => selectedMonth = v!);
            _filterBills();
          },
        ),
      ],
    );
  }

  Future<void> _showEditDialog(Map<String, dynamic> billData, int index) async {
    TextEditingController amountController = TextEditingController(text: billData['amount'].toStringAsFixed(2));
    String selectedCategory = billData['category'];
    DateTime selectedDate = DateTime.parse(billData['dueDate']);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Color.fromARGB(255, 247, 189, 210),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Edit Bill", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                      items: _billCategories.map((category) =>
                          DropdownMenuItem(value: category, child: Text(category))
                      ).toList(),
                      onChanged: (value) => setState(() => selectedCategory = value!),
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                  SizedBox(height: 15),
                  Text("Due Date:"),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.black38),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                          Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
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
                          double? parsedAmount = double.tryParse(amountController.text);
                          if (parsedAmount != null) {
                            
                            final allBillIndex = _allBillDocs.indexWhere((b) =>
                            b['category'] == billData['category'] &&
                                b['amount'] == billData['amount'] &&
                                b['dueDate'] == billData['dueDate']
                            );

                            if (allBillIndex != -1) {
                              _allBillDocs[allBillIndex] = {
                                ...billData,
                                'category': selectedCategory,
                                'amount': parsedAmount,
                                'dueDate': selectedDate.toIso8601String(),
                              };
                            }

                            
                            await _firestore.collection('financialData').doc(userId).update({
                              'bills': _allBillDocs
                            });

                           
                            _loadBillData();

                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Bill updated successfully!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 1),
                              ),
                            );

                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: Text("Save"),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showPaidConfirmationDialog(Map<String, dynamic> billData, int index) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color.fromARGB(255, 247, 189, 210),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            "Confirm Payment",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 195, 98, 138),
            ),
          ),
          content: Text(
            "Are you sure you want to mark this bill as paid?\n\n"
                "Category: ${billData['category']}\n"
                "Amount: RM ${billData['amount'].toStringAsFixed(2)}\n"
                "Due Date: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(billData['dueDate']))}\n\n"
                "This action will:\n"
                "• Mark the bill as paid\n"
                "• Add the amount to your expenditures\n"
                "• Stop payment reminders for this bill",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                "Cancel",
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _markBillAsPaid(billData, index);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _markBillAsPaid(Map<String, dynamic> billData, int index) async {
    try {
      
      final allBillIndex = _allBillDocs.indexWhere((b) =>
      b['category'] == billData['category'] &&
          b['amount'] == billData['amount'] &&
          b['dueDate'] == billData['dueDate']
      );
      if (allBillIndex != -1) {
        _allBillDocs[allBillIndex] = {
          ...billData,
          'paid': true,
          'paidDate': DateTime.now().toIso8601String(),
        };
      }

      
      await _firestore.collection('financialData').doc(userId).update({
        'bills': _allBillDocs
      });

      
      await _addToExpenditures(billData);

      
      await cancelBillReminders(billData);

      
      _loadBillData();

      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bill marked as paid successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error marking bill as paid: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking bill as paid'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addToExpenditures(Map<String, dynamic> billData) async {
    try {
      
      await _firestore
          .collection('financialData')
          .doc(userId)
          .collection('expenditure')
          .add({
        'category': billData['category'],
        'amount': billData['amount'],
        'date': Timestamp.now(),
        'description': 'Bill payment - ${billData['category']}',
        'type': 'bill_payment',
      });
    } catch (e) {
      print('Error adding to expenditures: $e');
    }
  }

  Future<void> scheduleBillReminders(Map<String, dynamic> bill) async {
    if (bill['paid'] == true) return;
    final dueDate = DateTime.parse(bill['dueDate']);
    final now = DateTime.now();
    for (int i = 7; i >= 1; i--) {
      final remindDate = dueDate.subtract(Duration(days: i));
      if (remindDate.isAfter(now)) {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          bill.hashCode + i, // unique id
          'Bill Reminder',
          'Your ${bill['category']} bill is due on ${dueDate.month}/${dueDate.day}. Please pay if not yet paid.',
          tz.TZDateTime.from(remindDate, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails('bill_reminder', 'Bill Reminders', importance: Importance.max, priority: Priority.high),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dateAndTime,
        );
      }
    }
  }

  Future<void> cancelBillReminders(Map<String, dynamic> bill) async {
    for (int i = 7; i >= 1; i--) {
      await flutterLocalNotificationsPlugin.cancel(bill.hashCode + i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDEEF3),
      appBar: AppBar(
        title: const Text('Bills', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: [
            _buildYearMonthSelector(),
            _buildHeader(),
            Expanded(child: _buildDataTable()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFE8B4C3),
        border: Border(
          top: BorderSide(color: Colors.grey),
          left: BorderSide(color: Colors.grey),
          right: BorderSide(color: Colors.grey),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Center(child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 2, child: Center(child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 3, child: Center(child: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(flex: 2, child: Center(child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey),
          right: BorderSide(color: Colors.grey),
          bottom: BorderSide(color: Colors.grey),
        ),
      ),
      child: ListView.builder(
        itemCount: _billDocs.length,
        itemBuilder: (context, index) {
          final bill = _billDocs[index];
          final date = DateTime.parse(bill['dueDate']);
          return _buildDataRow(
            category: bill['category'],
            amount: bill['amount'].toStringAsFixed(2),
            date: DateFormat('d/M/yyyy').format(date),
            billData: bill,
            index: index,
            onEdit: () => _showEditDialog(bill, index),
            onDelete: () async {
              
              if (bill['isRecurring'] == true && bill['recurringId'] != null) {
                await _firestore
                    .collection('financialData')
                    .doc(userId)
                    .collection('cancelledRecurringBills')
                    .doc(bill['recurringId'])
                    .set({'cancelled': true});
              }

              
              _allBillDocs.remove(bill);

              
              await _firestore.collection('financialData').doc(userId).update({
                'bills': _allBillDocs
              });

              
              _loadBillData();
            },
          );
        },
      ),
    );
  }

  Widget _buildDataRow({
    required String category,
    required String amount,
    required String date,
    required Map<String, dynamic> billData,
    required int index,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    final bool isPaid = billData['paid'] ?? false;

    return Container(
      height: 135, 
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Center(child: Text(category, textAlign: TextAlign.center))),
          Expanded(flex: 2, child: Center(child: Text(amount))),
          Expanded(flex: 3, child: Center(child: Text(date))),
          Expanded(
            flex: 2,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(maxHeight: 28, maxWidth: 28),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(maxHeight: 28, maxWidth: 28),
                  ),
                  SizedBox(
                    height: 24, width: 48,
                    child: ElevatedButton(
                      onPressed: isPaid ? null : () => _showPaidConfirmationDialog(billData, index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPaid ? Colors.grey : Colors.blue,
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size(24, 24),
                        maximumSize: Size(48, 24),
                      ),
                      child: Text(
                        'paid',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: isPaid ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}





