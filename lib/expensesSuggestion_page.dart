import 'package:flutter/material.dart';
import 'widgets/base_page.dart';
import 'gemini_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class ExpensesSuggestionPage extends StatefulWidget {
  const ExpensesSuggestionPage({super.key});

  @override
  State<ExpensesSuggestionPage> createState() => _ExpensesSuggestionPageState();
}

class _ExpensesSuggestionPageState extends State<ExpensesSuggestionPage> {
  String advice = 'Please enter your question and get financial advice!';
  final GeminiService geminiService = GeminiService();
  final TextEditingController _controller = TextEditingController();
  bool isLoading = false;
  String username = 'User';
  List<Map<String, dynamic>> chatHistory = [];
  bool showHistory = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.displayName != null) {
      username = user.displayName!;
    }
    loadChatHistory();
  }

  Future<void> loadChatHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('financialData')
            .doc(user.uid)
            .collection('chatHistory')
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get();

        setState(() {
          chatHistory = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'question': data['question'] ?? '',
              'answer': data['answer'] ?? '',
              'timestamp': data['timestamp'] ?? Timestamp.now(),
              'id': doc.id,
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  Future<void> saveToHistory(String question, String answer) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('financialData')
            .doc(user.uid)
            .collection('chatHistory')
            .add({
          'question': question,
          'answer': answer,
          'timestamp': Timestamp.now(),
        });

        // Reload history
        await loadChatHistory();
      }
    } catch (e) {
      debugPrint('Error saving to history: $e');
    }
  }

  void fetchAdviceWithData(String userQuestion) async {
    // 如果没有输入问题，自动用默认prompt
    final String actualQuestion = userQuestion.trim().isEmpty
        ? 'Please give me advice based on my financial situation.'
        : userQuestion;
    if (actualQuestion.isEmpty) {
      setState(() {
        advice = 'Please enter a question.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      advice = 'Generating advice...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;

      if (userId == null) {
        setState(() {
          advice = 'Error: User not logged in.';
          isLoading = false;
        });
        return;
      }

      // Fetch all financial data from database
      final doc = await FirebaseFirestore.instance.collection('financialData').doc(userId).get();
      final data = doc.data() ?? {};

      // Get current month data
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;
      final monthName = DateFormat('MMMM').format(now);
      final monthKey = '${currentYear}_$monthName';
      final savingMonthKey = '${currentYear}_${currentMonth.toString().padLeft(2, '0')}';

      // Get budget data
      double currentBudget = 0;
      if (doc.exists) {
        final budgets = data['budgets'] as Map<String, dynamic>?;
        if (budgets != null && budgets[monthKey] != null) {
          currentBudget = (budgets[monthKey] as num).toDouble();
        }
      }

      // Get expenditure data for current month
      double totalExpenditure = 0;
      QuerySnapshot expenditureSnapshot = await FirebaseFirestore.instance
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

      // Get income data for current month
      double totalIncome = 0;
      QuerySnapshot incomeSnapshot = await FirebaseFirestore.instance
          .collection('financialData')
          .doc(userId)
          .collection('income')
          .get();

      for (var doc in incomeSnapshot.docs) {
        final incomeData = doc.data() as Map<String, dynamic>;
            final date = (incomeData['date'] as Timestamp).toDate();
            if (date.month == currentMonth && date.year == currentYear) {
          totalIncome += (incomeData['amount'] ?? 0).toDouble();
        }
      }

      // Get saving data
      double currentSaving = 0;
      if (doc.exists) {
        final savingHistory = data['savingHistory'] as Map<String, dynamic>?;
        if (savingHistory != null && savingHistory[savingMonthKey] != null) {
          currentSaving = (savingHistory[savingMonthKey]['amount'] ?? 0).toDouble();
        }
      }

      // Get category budgets and expenses
      final categoryBudgets = data['categoryBudgets'] is Map
          ? Map<String, dynamic>.from(data['categoryBudgets'])
          : <String, dynamic>{};
      final categoryExpenses = data['categoryExpenses'] is Map
          ? Map<String, dynamic>.from(data['categoryExpenses'])
          : <String, dynamic>{};

      // Get user goal
      final userGoal = data['goal'] ?? '';

      String prompt = '''
You are a helpful financial advisor. The user has asked: "$actualQuestion"

Here is the user's current financial data for ${DateFormat('MMMM yyyy').format(now)}:

*Income & Expenses:*
- Total Income: RM $totalIncome
- Total Expenditure: RM $totalExpenditure
- Current Budget: RM $currentBudget
- Current Savings: RM $currentSaving
- Remaining Budget: RM ${currentBudget - totalExpenditure - currentSaving}

*Category Breakdown:*
${categoryBudgets.entries.map((e) => '- ${e.key}: Budget RM ${e.value}, Spent RM ${categoryExpenses[e.key] ?? 0}').join('\n')}

*Financial Goal:* $userGoal

Please provide personalized financial advice based on this data. If the user asked in Chinese, respond in Chinese. If in English, respond in English. 

Focus on:
1. Overall budget status (over/under/on track)
2. Category-specific insights and recommendations
3. Actionable tips to improve financial health
4. Progress toward their financial goal

Keep the response concise and mobile-friendly with clear formatting.
Do not use any asterisk or * in your answer.
''';

      final result = await geminiService.getFinancialAdvice(prompt);

      // Save to history
      await saveToHistory(actualQuestion, result);
      
      setState(() {
        advice = result.replaceAll('*', '');
        isLoading = false;
      });
      // 移除自动清空输入框逻辑
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   _controller.clear();
      // });

    } catch (e) {
      debugPrint('Sorry, I couldn\'t generate advice at the moment. Please try again later.');
      setState(() {
        advice = 'Sorry, I couldn\'t generate advice at the moment. Please try again later.';
        isLoading = false;
      });
    }
  }

  void showHistoryDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Chat History'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
                  child: chatHistory.isEmpty
                      ? Center(
                          child: Text(
                'No chat history yet.\nStart asking questions to see your history here!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          itemCount: chatHistory.length,
                          itemBuilder: (context, index) {
                final item = chatHistory[index];
                final timestamp = (item['timestamp'] as Timestamp).toDate();
                            return Card(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(
                      item['question'],
                      style: TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                        Text(
                          item['answer'],
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                                    Text(
                                      DateFormat('MMM dd, yyyy HH:mm').format(timestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                      ],
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        advice = item['answer'];
                        _controller.text = item['question'];
                      });
                    },
                              ),
                            );
                          },
                        ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      username: username,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Listener(
            onPointerDown: (_) {
              // 收起键盘
              FocusScope.of(context).unfocus();
            },
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 52),
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
                        child: Icon(Icons.lightbulb, size: 30, color: Colors.black),
                      ),
                      SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          "Expenses Suggestion",
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 199, 21, 133),
                          ),
                        ),
                      ),
                      // History button
                      IconButton(
                        onPressed: showHistoryDialog,
                        icon: Icon(
                          Icons.history,
                          size: 24,
                          color: Color.fromARGB(255, 195, 98, 138),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: 'Ask your financial question... (e.g. How can I save more?)',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () {
                          // 收回键盘
                          FocusScope.of(context).unfocus();
                          final question = _controller.text.trim();
                          fetchAdviceWithData(question);
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Color.fromARGB(255, 195, 98, 138),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                        child: isLoading
                            ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : Icon(Icons.send),
                      ),
                      SizedBox(width: 6),
                      // 智能建议按钮
                      IconButton(
                        tooltip: 'Get smart advice',
                        icon: Icon(Icons.tips_and_updates, color: Color.fromARGB(255, 195, 98, 138), size: 28),
                        onPressed: isLoading
                            ? null
                            : () {
                          // 收回键盘
                          FocusScope.of(context).unfocus();
                          fetchAdviceWithData('');
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  // AI对话框
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.35,
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Color.fromARGB(255, 195, 98, 138), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color.fromRGBO(0, 0, 0, 0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 对话框头部
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Color.fromARGB(255, 195, 98, 138),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(18),
                                      topRight: Radius.circular(18),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.smart_toy,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'AI Financial Advisor',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // 对话框内容
                                Expanded(
                                  child: Container(
                                    padding: EdgeInsets.all(16),
                                    child: Scrollbar(
                                      thumbVisibility: true,
                                      child: ListView(
                                        children: [
                                          isLoading
                                              ? Center(child: CircularProgressIndicator())
                                              : Text(
                                            advice,
                                            style: GoogleFonts.notoSans(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 对话框尾巴
                        Container(
                          margin: EdgeInsets.only(right: 20),
                          child: CustomPaint(
                            size: Size(20, 15),
                            painter: DialogTailPainter(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  // 底部logo
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      width: 80,
                      height: 80,
                      margin: EdgeInsets.only(right: 0, bottom: 0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: ClipOval(
                        child: Transform.scale(
                          scaleX: -1,
                          child: Image.asset(
                            'assets/images/logo.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: Icon(Icons.image, size: 40, color: Colors.grey[600]),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color.fromARGB(255, 247, 189, 210)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class DialogTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Color.fromARGB(255, 195, 98, 138)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}