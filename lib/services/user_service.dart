import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../local_image_storage.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  String _username = 'User';
  String _avatarUrl = '';
  String _email = '';
  String _registrationDate = '';

  // Getters
  String get username => _username;
  String get avatarUrl => _avatarUrl;
  String get email => _email;
  String get registrationDate => _registrationDate;

  // 加载用户数据
  Future<void> loadUserData() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _username = currentUser.displayName ?? 'User';
        _avatarUrl = currentUser.photoURL ?? '';
        _email = currentUser.email ?? '';
        _registrationDate = _formatDate(currentUser.metadata.creationTime);
        // 新增：加载本地头像
        try {
          // 只有 userId 存在时才加载
          final userId = currentUser.uid;
          final localImageStorage = LocalImageStorage();
          String? imageData = await localImageStorage.getImageLocally(userId);
          if (imageData != null && imageData.isNotEmpty) {
            _avatarUrl = imageData;
          }
        } catch (e) {
          print('Error loading local avatar: $e');
        }
      } else {
        _username = 'User';
        _avatarUrl = '';
        _email = '';
        _registrationDate = '';
      }
    } catch (e) {
      print('Error loading user data: $e');
      _username = 'User';
      _avatarUrl = '';
      _email = '';
      _registrationDate = '';
    }
  }

  // 更新用户名
  Future<void> updateUsername(String newUsername) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.updateDisplayName(newUsername);
        _username = newUsername;
      }
    } catch (e) {
      print('Error updating username: $e');
      rethrow;
    }
  }

  // 更新头像
  Future<void> updateAvatar(String avatarUrl) async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.updatePhotoURL(avatarUrl);
        _avatarUrl = avatarUrl;
      }
    } catch (e) {
      print('Error updating avatar: $e');
      rethrow;
    }
  }

  // 格式化日期
  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';

    String year = date.year.toString();
    String month = date.month.toString().padLeft(2, '0');
    String day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // 获取图片提供者
  ImageProvider getImageProvider(String imageUrl) {
    // 暂时返回透明图片，避免崩溃
    return MemoryImage(Uint8List.fromList(kTransparentImage));
  }
}

// 透明图片数据
const List<int> kTransparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82
]; 