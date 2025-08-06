import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditIncomePage extends StatefulWidget {
  const EditIncomePage({super.key});

  @override
  State<EditIncomePage> createState() => _EditIncomePageState();
}

class _EditIncomePageState extends State<EditIncomePage> {
  final Map<String, IconData> _categoryIcons = {
    'Salary Income': Icons.attach_money,
    'Investment Income': Icons.show_chart,
    'Business Income': Icons.handshake,
    'Rental Income': Icons.home_work,
    'Governance Benefits': Icons.account_balance,
    'Part-time Income': Icons.timelapse,
    'Donation Income': Icons.favorite,
    'Other Income': Icons.monetization_on,
  };

  List<DocumentSnapshot> _incomeDocs = [];
  
  String get userId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    return user.uid;
  }
  
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;
  List<DocumentSnapshot> _allIncomeDocs = [];

  @override
  void initState() {
    super.initState();
    _loadIncomeData();
  }

  Future<void> _loadIncomeData() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('financialData')
          .doc(userId)
          .collection('income')
          .orderBy('date', descending: true)
          .get();
      setState(() {
        _allIncomeDocs = querySnapshot.docs;
        _incomeDocs = querySnapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          final date = (data['date'] as Timestamp?)?.toDate();
          if (date == null) return false;
          return date.year == selectedYear && date.month == selectedMonth;
        }).toList();
      });
    } catch (e) {
      debugPrint('Error loading income data: $e');
    }
  }

  void _filterIncome() {
    setState(() {
      _incomeDocs = _allIncomeDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;
        final date = (data['date'] as Timestamp?)?.toDate();
        if (date == null) return false;
        return date.year == selectedYear && date.month == selectedMonth;
      }).toList();
    });
  }

  Future<void> _updateTotalIncome(double amount, bool isSubtract) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('financialData')
          .doc(userId)
          .get();

      double currentTotal = 0;
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        currentTotal = (data['income'] ?? 0).toDouble();
      }

      double newTotal = isSubtract ? currentTotal - amount : currentTotal + amount;

      await FirebaseFirestore.instance
          .collection('financialData')
          .doc(userId)
          .set({
        'income': newTotal,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating total income: $e');
    }
  }

  void _showEditDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return;
    
    final String category = data['category'] ?? '';
    final String currentAmount = (data['amount'] ?? 0.0).toStringAsFixed(2);
    final double originalAmount = (data['amount'] ?? 0.0).toDouble();
    final IconData icon = _categoryIcons[category] ?? Icons.error;

    final TextEditingController controller = TextEditingController(text: currentAmount);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 254, 199, 217),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.black, size: 50),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink[900],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
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
                          
                          await _updateTotalIncome(originalAmount, true);

                          
                          await doc.reference.update({
                            'amount': value,
                            'date': DateTime.now(),
                          });

                          
                          await _updateTotalIncome(value, false);

                          Navigator.pop(context);
                          _loadIncomeData();
                        } catch (e) {
                          debugPrint("Update error: $e");
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("Save"),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
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
            if (v != null) {
              setState(() => selectedYear = v);
              _filterIncome();
            }
          },
        ),
        const SizedBox(width: 10),
        DropdownButton<int>(
          value: selectedMonth,
          items: List.generate(12, (i) => i + 1)
              .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => selectedMonth = v);
              _filterIncome();
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDEEF3),
      appBar: AppBar(
        title: const Text('Income', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadIncomeData,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: [
            _buildYearMonthSelector(),
            Container(
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
                  Expanded(flex: 3, child: Center(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold)))),
                  Expanded(flex: 2, child: Center(child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
            Expanded(child: _buildIncomeTable()),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeTable() {
    final int totalRows = _incomeDocs.length;
    final int minRows = 8;

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey),
          right: BorderSide(color: Colors.grey),
          bottom: BorderSide(color: Colors.grey),
        ),
      ),
      child: ListView.builder(
        itemCount: totalRows > minRows ? totalRows : minRows,
        itemBuilder: (context, index) {
          if (index < totalRows) {
            final doc = _incomeDocs[index];
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return _buildDataRow(category: '', amount: '', date: '', isEmpty: true);
            final date = (data['date'] as Timestamp?)?.toDate();
            if (date == null) return _buildDataRow(category: '', amount: '', date: '', isEmpty: true);
            return _buildDataRow(
              category: data['category'] ?? '',
              amount: (data['amount'] ?? 0.0).toStringAsFixed(2),
              date: DateFormat('d/M/yyyy').format(date),
              onDelete: () async {
                await doc.reference.delete();
                _loadIncomeData();
                await _updateTotalIncome((data['amount'] ?? 0.0).toDouble(), true);
              },
              onEdit: () => _showEditDialog(doc),
            );
          } else {
            return _buildDataRow(category: '', amount: '', date: '', isEmpty: true);
          }
        },
      ),
    );
  }

  Widget _buildDataRow({
    required String category,
    required String amount,
    required String date,
    bool isEmpty = false,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return Container(
      height: 110,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Center(child: Text(category, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)))),
          Expanded(flex: 2, child: Center(child: Text(amount))),
          Expanded(flex: 3, child: Center(child: Text(date))),
          Expanded(
            flex: 2,
            child: isEmpty
                ? const SizedBox()
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: onEdit,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
                const SizedBox(height: 4),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
