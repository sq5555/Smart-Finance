import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/user_service.dart';
import 'dart:convert';
import 'dart:io';
import 'local_image_storage.dart';
import 'widgets/base_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final LocalImageStorage _localStorage = LocalImageStorage();
  final UserService _userService = UserService();
  String? _selectedImageBase64;
  String? _userID;
  String? _username;
  String? _email;
  String? _registrationDate;
  bool _isLoading = false;
  bool _firebaseAvailable = false;

  late final TextEditingController _userIdController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _registrationDateController;

  @override
  void initState() {
    super.initState();
    _userIdController = TextEditingController();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _registrationDateController = TextEditingController();
    _checkFirebaseAvailability();
    _loadUserData();
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _registrationDateController.dispose();
    super.dispose();
  }

  Future<void> _checkFirebaseAvailability() async {
    debugPrint('Checking Firebase availability...');
    try {
      
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        debugPrint('Firebase Auth is available');
        setState(() {
          _firebaseAvailable = true;
        });
      } else {
        debugPrint('No user logged in');
        setState(() {
          _firebaseAvailable = false;
        });
      }
    } catch (e) {
      debugPrint('Firebase not available: $e');
      setState(() {
        _firebaseAvailable = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      
      await _userService.loadUserData();

      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        setState(() {
          _userID = currentUser.uid;
          _username = _userService.username;
          _email = _userService.email;
          _registrationDate = _userService.registrationDate;
          _userIdController.text = currentUser.uid;
          _usernameController.text = _userService.username;
          _emailController.text = _userService.email;
          _registrationDateController.text = _userService.registrationDate;
        });

        
        String? imageData = await _localStorage.getImageLocally(_userID!);
        if (imageData != null) {
          setState(() {
            _selectedImageBase64 = imageData;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('用户未登录')),
        );
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载用户信息失败: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPickImageDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.gallery);
              },
            ),
            if (_selectedImageBase64 != null)
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('Remove Avatar'),
                onTap: () async {
                  Navigator.pop(context);
                  if (_userID != null) {
                    await _localStorage.deleteImageLocally(_userID!);
                  }
                  setState(() {
                    _selectedImageBase64 = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage([ImageSource source = ImageSource.gallery]) async {
    try {
      final File? imageFile = await _localStorage.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (imageFile != null) {
        debugPrint('图片选择成功: ${imageFile.path}');

      
        String? imageData = await _localStorage.saveImageLocally(imageFile, _userID ?? 'temp');
        if (imageData != null) {
          debugPrint('图片保存到本地成功');
          setState(() {
            _selectedImageBase64 = imageData;
          });
        } else {
          debugPrint('图片保存到本地失败');
        }
      }
    } catch (e) {
      debugPrint('选择图片失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_userID == null || _userID!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter user ID')),
      );
      return;
    }

    debugPrint('Starting save profile for user: $_userID');
    debugPrint('Firebase available: $_firebaseAvailable');

    setState(() {
      _isLoading = true;
    });

    try {
     
      await _userService.updateUsername(_usernameController.text);

      
      await _userService.loadUserData();
      await _loadUserData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile saved successfully!')),
      );

      
    } catch (e) {
      debugPrint('Exception during save: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      debugPrint('Setting loading to false');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    if (_userID == null || _userID!.isEmpty) return;
    try {
      await _userService.loadUserData();

      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        setState(() {
          _username = _userService.username;
          _email = _userService.email;
          _registrationDate = _userService.registrationDate;
          _selectedImageBase64 = null; // 
          _userIdController.text = currentUser.uid;
          _usernameController.text = _userService.username;
          _emailController.text = _userService.email;
          _registrationDateController.text = _userService.registrationDate;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Load failed: $e')),
      );
    }
  }

  @override
Widget build(BuildContext context) {
  return BasePage(
    username: _username ?? 'User',
    avatarUrl: _selectedImageBase64 ?? (_userID != null ? '' : ''),
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('User Profile', style: TextStyle(color: Colors.black)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            if (!_firebaseAvailable)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Firebase unavailable, using local storage',
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            GestureDetector(
              onTap: _showPickImageDialog,
              child: CircleAvatar(
                radius: 80,
                backgroundColor: Colors.grey[300],
                backgroundImage: (_selectedImageBase64 != null)
                    ? MemoryImage(base64Decode(_selectedImageBase64!))
                    : null,
                child: (_selectedImageBase64 == null && _userService.avatarUrl.isEmpty)
                    ? Icon(Icons.person, size: 80, color: Colors.lightBlueAccent)
                    : null,
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.black38),
                    backgroundColor: Colors.blue.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: _showPickImageDialog,
                  child: Text(
                    "Edit Avatar",
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
            SizedBox(height: 32),

            // Username field
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Username',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: 250,
                  child: TextField(
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Username',
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.blue.shade100,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                    ),
                    controller: _usernameController,
                    onChanged: (value) {
                      setState(() {
                        _username = value;
                      });
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 25),

            // User ID field
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User ID',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: 250,
                  child: TextField(
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'User ID',
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.blue.shade100,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                    ),
                    controller: _userIdController,
                    enabled: false,
                    onChanged: (value) {
                      setState(() {
                        _userID = value;
                      });
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 25),

            // Email field
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: 250,
                  child: TextField(
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.blue.shade100,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                    ),
                    controller: _emailController,
                    enabled: false,
                    onChanged: (value) {
                      setState(() {
                        _email = value;
                      });
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 25),

            // Registration Date field
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registration Date',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: 250,
                  child: TextField(
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'Registration Date',
                      hintStyle: TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.blue.shade100,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                    ),
                    controller: _registrationDateController,
                    enabled: false,
                    onChanged: (value) {
                      setState(() {
                        _registrationDate = value;
                      });
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 32),

            // ✅ Save button now at bottom, scroll to see it
           // ✅ Save button at bottom
Align(
  alignment: Alignment.centerRight,
  child: OutlinedButton(
    style: OutlinedButton.styleFrom(
      side: BorderSide(color: Colors.black38),
      backgroundColor: Colors.blue.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    ),
    onPressed: _isLoading ? null : _saveProfile,
    child: _isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          )
        : Text(
            "Save",
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
  ),
),

SizedBox(height: 40), 
          ],
        ),
      ),
    ),
  );
}
}
