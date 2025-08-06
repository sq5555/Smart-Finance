import 'package:flutter/material.dart';
import 'side_menu.dart';

class BasePage extends StatefulWidget {
  final Widget child;
  final String username;
  final String avatarUrl;

  const BasePage({
    super.key,
    required this.child,
    this.username = 'User',
    this.avatarUrl = '',
  });

  @override
  State<BasePage> createState() => _BasePageState();
}

class _BasePageState extends State<BasePage> {
  bool _isMenuOpen = false;

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  void _closeMenu() {
    setState(() {
      _isMenuOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
         
          widget.child,

          
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: IconButton(
              onPressed: _toggleMenu,
              icon: Icon(
                Icons.menu,
                size: 30,
                color: Colors.black87,
              ),
            ),
          ),

          
          if (_isMenuOpen)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: SideMenu(
                onClose: _closeMenu,
              ),
            ),
        ],
      ),
    );
  }
} 