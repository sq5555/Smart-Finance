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

  
  Future<void> loadUserData() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        _username = currentUser.displayName ?? 'User';
        _avatarUrl = currentUser.photoURL ?? '';
        _email = currentUser.email ?? '';
        _registrationDate = _formatDate(currentUser.metadata.creationTime);
        
        try {
          
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

  
  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';

    String year = date.year.toString();
    String month = date.month.toString().padLeft(2, '0');
    String day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  
  ImageProvider getImageProvider(String imageUrl) {
    
    return MemoryImage(Uint8List.fromList(kTransparentImage));
  }
}


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