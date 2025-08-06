import 'package:flutter/material.dart';
import '../services/user_service.dart';
import 'dart:convert';

class SideMenu extends StatefulWidget {
  final VoidCallback onClose;

  const SideMenu({
    super.key,
    required this.onClose,
  });

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  final UserService _userService = UserService();
  bool isLoading = true;
  ImageProvider? avatarImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      await _userService.loadUserData();

      // 尝试解析 avatarUrl（如果是 base64）
      if (_userService.avatarUrl.isNotEmpty) {
        try {
          final decoded = base64Decode(_userService.avatarUrl);
          setState(() {
            avatarImage = MemoryImage(decoded);
            isLoading = false;
          });
        } catch (e) {
          debugPrint("Invalid base64 avatar, fallback to default icon.");
          setState(() {
            avatarImage = null;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          avatarImage = null;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data in side menu: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: MediaQuery.of(context).size.height * 0.85,
      margin: EdgeInsets.symmetric(
          vertical: MediaQuery.of(context).size.height * 0.075),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            spreadRadius: 2,
            blurRadius: 10,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 顶部用户信息区域
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 253, 253, 253),
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // 头像和用户名
                      Row(
                        children: [
                          // 头像
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color.fromARGB(255, 199, 21, 133),
                              image: avatarImage != null
                                  ? DecorationImage(
                                      image: avatarImage!,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: avatarImage == null
                                ? Icon(
                                    Icons.person,
                                    size: 30,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          SizedBox(width: 15),
                          // 用户名
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userService.username,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 8),
                                // Edit Profile 按钮
                                GestureDetector(
                                  onTap: () async {
                                    await Navigator.pushNamed(
                                        context, '/user_profile');
                                    _loadUserData();
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color.fromARGB(
                                          255, 199, 21, 133),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Text(
                                      'Edit Profile',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 30),

                // 导航选项
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: Icons.home,
                          title: 'Home',
                          onTap: () {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/home',
                              (route) => false,
                            );
                          },
                        ),
                        SizedBox(height: 15),
                        _buildMenuItem(
                          icon: Icons.account_balance_wallet,
                          title: 'Manage Financial Data',
                          onTap: () {
                            Navigator.pushNamed(
                                context, '/manage_financial_data');
                          },
                        ),
                        SizedBox(height: 15),
                        _buildMenuItem(
                          icon: Icons.attach_money,
                          title: 'Set Budget',
                          onTap: () {
                            Navigator.pushNamed(context, '/set_budget');
                          },
                        ),
                        SizedBox(height: 15),
                        _buildMenuItem(
                          icon: Icons.bar_chart,
                          title: 'View Spending Analytics',
                          onTap: () {
                            Navigator.pushNamed(
                                context, '/view_spending_analytics');
                          },
                        ),
                        SizedBox(height: 15),
                        _buildMenuItem(
                          icon: Icons.lightbulb,
                          title: 'Expenses Suggestion',
                          onTap: () {
                            Navigator.pushNamed(
                                context, '/expenses_suggestion');
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // 底部退出按钮
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: widget.onClose,
                      icon: Icon(
                        Icons.close,
                        size: 40,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 254, 199, 217),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: const Color.fromARGB(255, 199, 21, 133),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
