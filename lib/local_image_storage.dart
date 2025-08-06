import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalImageStorage {
  static final LocalImageStorage _instance = LocalImageStorage._internal();
  factory LocalImageStorage() => _instance;
  LocalImageStorage._internal();

  final ImagePicker _picker = ImagePicker();
  static const String _keyPrefix = 'user_image_';
  static const String _profilePrefix = 'user_profile_';

  
  Future<File?> pickImage({
    ImageSource source = ImageSource.gallery,
    double maxWidth = 512,
    double maxHeight = 512,
    int imageQuality = 80,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Failed to select image: $e');
      return null;
    }
  }

 
  Future<String?> saveImageLocally(File imageFile, String userId) async {
    try {
      final List<int> imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_keyPrefix$userId', base64Image);

      return base64Image;
    } catch (e) {
      print('Failed to save image locally: $e');
      return null;
    }
  }

  
  Future<String?> getImageLocally(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_keyPrefix$userId');
    } catch (e) {
      print('Failed to get image from local: $e');
      return null;
    }
  }

  
  Future<bool> saveUserProfile(String userId, Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String profileJson = json.encode(profile);
      await prefs.setString('$_profilePrefix$userId', profileJson);
      return true;
    } catch (e) {
      print('Failure to save user information: $e');
      return false;
    }
  }

  
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? profileJson = prefs.getString('$_profilePrefix$userId');
      if (profileJson != null) {
        return json.decode(profileJson) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Failed to get user information: $e');
      return null;
    }
  }

  
  Future<bool> deleteImageLocally(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyPrefix$userId');
      return true;
    } catch (e) {
      print('Failed to delete local image: $e');
      return false;
    }
  }

  
  Future<bool> deleteUserProfile(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_profilePrefix$userId');
      await prefs.remove('$_keyPrefix$userId');
      return true;
    } catch (e) {
      print('Failed to delete user profile: $e');
      return false;
    }
  }

  
  Future<List<String>> getAllUserIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Set<String> keys = prefs.getKeys();
      final List<String> userIds = [];

      for (String key in keys) {
        if (key.startsWith(_profilePrefix)) {
          final String userId = key.substring(_profilePrefix.length);
          userIds.add(userId);
        }
      }

      return userIds;
    } catch (e) {
      print('Failed to get all user IDs: $e');
      return [];
    }
  }

  
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Set<String> keys = prefs.getKeys();
      int totalSize = 0;
      int imageCount = 0;
      int profileCount = 0;

      for (String key in keys) {
        if (key.startsWith(_keyPrefix)) {
          final String? imageData = prefs.getString(key);
          if (imageData != null) {
            totalSize += imageData.length;
            imageCount++;
          }
        } else if (key.startsWith(_profilePrefix)) {
          profileCount++;
        }
      }

      return {
        'totalSize': totalSize,
        'imageCount': imageCount,
        'profileCount': profileCount,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      print('Failed to get storage information: $e');
      return {
        'totalSize': 0,
        'imageCount': 0,
        'profileCount': 0,
        'totalSizeMB': '0.00',
      };
    }
  }

  
  Future<bool> cleanupOldData({int maxAgeDays = 30}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Set<String> keys = prefs.getKeys();
      final DateTime now = DateTime.now();
      int cleanedCount = 0;

      for (String key in keys) {
        if (key.startsWith(_profilePrefix)) {
          final String? profileJson = prefs.getString(key);
          if (profileJson != null) {
            try {
              final Map<String, dynamic> profile = json.decode(profileJson);
              final String? lastUpdated = profile['lastUpdated'];
              if (lastUpdated != null) {
                final DateTime updatedTime = DateTime.parse(lastUpdated);
                final int daysDiff = now.difference(updatedTime).inDays;

                if (daysDiff > maxAgeDays) {
                  final String userId = key.substring(_profilePrefix.length);
                  await prefs.remove(key);
                  await prefs.remove('$_keyPrefix$userId');
                  cleanedCount++;
                }
              }
            } catch (e) {
              
              await prefs.remove(key);
              cleanedCount++;
            }
          }
        }
      }

      print('Cleaned up $cleanedCount Expired data');
      return true;
    } catch (e) {
      print('Failed to clear expired data: $e');
      return false;
    }
  }
} 