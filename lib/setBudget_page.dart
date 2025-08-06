import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/base_page.dart';

class SetBudgetPage extends StatefulWidget {
  const SetBudgetPage({super.key});

  @override
  State<SetBudgetPage> createState() => _SetBudgetPageState();
}

class _SetBudgetPageState extends State<SetBudgetPage> {
  int selectedYear = DateTime.now().year;
  String selectedMonth = DateFormat('MMMM').format(DateTime.now());
  int budget = 0;
  bool isLoading = false;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late String userId;

  List<String> months = List.generate(
      12, (index) => DateFormat('MMMM').format(DateTime(0, index + 1)));
  List<int> years = List.generate(30, (index) => 2020 + index);

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null) {
      userId = user.uid;
      fetchBudget();
    } else {
      print("No user logged in.");
    }
  }

  Future<void> fetchBudget() async {
    setState(() {
      isLoading = true;
    });

    try {
      final doc = await _firestore.collection('financialData').doc(userId).get();

      if (doc.exists) {
        final data = doc.data()!;
        final yearMonthKey = '${selectedYear}_$selectedMonth';

        if (data['budgets'] != null && data['budgets'][yearMonthKey] != null) {
          setState(() {
            budget = (data['budgets'][yearMonthKey] as num).toInt();
          });
        } else {
          setState(() {
            budget = 0;
          });
        }
      }
    } catch (e) {
      print("Fetch budget error: $e");
      setState(() {
        budget = 0;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> updateBudget() async {
    final yearMonthKey = '${selectedYear}_$selectedMonth';

    try {
      await _firestore.collection('financialData').doc(userId).set({
        'budgets': {
          yearMonthKey: budget,
        }
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Budget updated successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print("Update budget error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update budget. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showEditBudgetDialog() async {
    int tempBudget = budget;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Budget",
                    style: TextStyle(fontSize: 29, fontWeight: FontWeight.bold)),
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.pink[100],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text("RM $tempBudget",
                      style: TextStyle(fontSize: 33, fontWeight: FontWeight.bold)),
                ),
                SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: Size(70, 60)),
                      onPressed: () => setModalState(() {
                        if (tempBudget > 0) tempBudget -= 100;
                      }),
                      child: Text("-", style: TextStyle(fontSize: 31)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: Size(70, 60)),
                      onPressed: () => setModalState(() => tempBudget += 100),
                      child: Text("+", style: TextStyle(fontSize: 31)),
                    ),
                  ],
                ),
                SizedBox(height: 25),
                Align(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton(
                    onPressed: () async {
                      setState(() {
                        budget = tempBudget;
                      });
                      await updateBudget();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: CircleBorder(),
                        padding: EdgeInsets.all(18)),
                    child: Icon(Icons.check, color: Colors.white, size: 33),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      username: 'John Doe',
      child: Scaffold(
        backgroundColor: Color(0xFFFFE5EC),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              height: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet,
                          color: Colors.black, size: 35),
                      SizedBox(width: 12),
                      Text("Set Budget",
                          style: TextStyle(
                              color: Colors.pink[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 29))
                    ],
                  ),
                  SizedBox(height: 60),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Year:",
                          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w500)),
                      SizedBox(width: 15),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.pink[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButton<int>(
                          value: selectedYear,
                          underline: SizedBox(),
                          dropdownColor: Colors.pink[100],
                          style: TextStyle(fontSize: 25, color: Colors.black),
                          items: years
                              .map((y) =>
                              DropdownMenuItem(value: y, child: Text(y.toString())))
                              .toList(),
                          onChanged: (value) {
                            setState(() => selectedYear = value!);
                            fetchBudget();
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Month:",
                          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w500)),
                      SizedBox(width: 15),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.pink[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButton<String>(
                          value: selectedMonth,
                          underline: SizedBox(),
                          dropdownColor: Colors.pink[100],
                          style: TextStyle(fontSize: 25, color: Colors.black),
                          items: months
                              .map((m) =>
                              DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (value) {
                            setState(() => selectedMonth = value!);
                            fetchBudget();
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 50),
                  Text("Budget:",
                      style: TextStyle(fontSize: 27, fontWeight: FontWeight.w600)),
                  SizedBox(height: 15),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 45, vertical: 25),
                    decoration: BoxDecoration(
                      color: Colors.pink[200],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: isLoading
                        ? CircularProgressIndicator(color: Colors.pink[700])
                        : Text("RM $budget",
                        style: TextStyle(fontSize: 33, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(height: 35),
                  ElevatedButton(
                    onPressed: isLoading ? null : _showEditBudgetDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(horizontal: 60, vertical: 20),
                    ),
                    child: Text("Edit Budget",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
