import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ImageStorageService {
  static final ImageStorageService _instance = ImageStorageService._internal();
  factory ImageStorageService() => _instance;
  ImageStorageService._internal();

  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;
  final ImagePicker _picker = ImagePicker();

  FirebaseFirestore get firestore {
    _firestore ??= FirebaseFirestore.instance;
    return _firestore!;
  }

  FirebaseStorage get storage {
    _storage ??= FirebaseStorage.instance;
    return _storage!;
  }

  
  Future<String?> uploadImageToStorage(File imageFile, String userId) async {
    try {
      print('开始上传图片到Firebase Storage...');
      print('用户ID: $userId');
      print('文件路径: ${imageFile.path}');

      
      final Reference storageRef = storage.ref().child('user_avatars/$userId.jpg');
      print('存储引用路径: ${storageRef.fullPath}');

      
      print('开始上传文件...');
      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      print('文件上传完成');

      
      print('获取下载URL...');
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      print('图片上传成功，下载URL: $downloadUrl');
      print('URL长度: ${downloadUrl.length}');

      
      print('使用用户ID作为头像标识符');
      return 'avatar_$userId';
    } catch (e) {
      print('上传图片到Firebase Storage失败: $e');
      print('错误详情: ${e.toString()}');
      return null;
    }
  }

  
  Future<bool> deleteImageFromStorage(String userId) async {
    try {
      final Reference storageRef = storage.ref().child('user_avatars/$userId.jpg');
      await storageRef.delete();
      return true;
    } catch (e) {
      print('删除Firebase Storage图片失败: $e');
      return false;
    }
  }

  
  Future<String?> uploadImageToFirestore(File imageFile, String userId) async {
    try {
      
      final List<int> imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      
      await firestore
          .collection('user_images')
          .doc(userId)
          .set({
        'imageData': base64Image,
        'uploadTime': FieldValue.serverTimestamp(),
        'fileSize': imageBytes.length,
      });

      return base64Image;
    } catch (e) {
      print('上传图片到Firestore失败: $e');
      return null;
    }
  }

 
  Future<String?> getImageFromFirestore(String userId) async {
    try {
      final DocumentSnapshot doc = await firestore
          .collection('user_images')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['imageData'];
      }
      return null;
    } catch (e) {
      print('从Firestore获取图片失败: $e');
      return null;
    }
  }

  
  Future<String?> uploadImageToExternalStorage(File imageFile, String userId) async {
    try {
      
      await firestore
          .collection('user_images')
          .doc(userId)
          .set({
        'imageUrl': 'https://example.com/images/$userId.jpg', 
        'uploadTime': FieldValue.serverTimestamp(),
      });

      return 'https://example.com/images/$userId.jpg';
    } catch (e) {
      print('上传图片到外部存储失败: $e');
      return null;
    }
  }

  
  Future<String?> uploadLargeImageToFirestore(File imageFile, String userId) async {
    try {
      final List<int> imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      
      const int chunkSize = 1000000; // 1MB per chunk
      final int totalChunks = (base64Image.length / chunkSize).ceil();

      for (int i = 0; i < totalChunks; i++) {
        final int start = i * chunkSize;
        final int end = (i + 1) * chunkSize > base64Image.length
            ? base64Image.length
            : (i + 1) * chunkSize;
        final String chunk = base64Image.substring(start, end);

        await firestore
            .collection('user_images')
            .doc(userId)
            .collection('chunks')
            .doc('chunk_$i')
            .set({
          'data': chunk,
          'chunkIndex': i,
          'totalChunks': totalChunks,
        });
      }

      
      await firestore
          .collection('user_images')
          .doc(userId)
          .set({
        'metadata': {
          'totalChunks': totalChunks,
          'fileSize': imageBytes.length,
          'uploadTime': FieldValue.serverTimestamp(),
        }
      });

      return 'chunked_$userId';
    } catch (e) {
      print('分块上传图片失败: $e');
      return null;
    }
  }

  
  Future<String?> getChunkedImageFromFirestore(String userId) async {
    try {
      final DocumentSnapshot metadataDoc = await firestore
          .collection('user_images')
          .doc(userId)
          .get();

      if (!metadataDoc.exists) return null;

      final data = metadataDoc.data() as Map<String, dynamic>;
      final int totalChunks = data['metadata']['totalChunks'];

      String fullImage = '';
      for (int i = 0; i < totalChunks; i++) {
        final DocumentSnapshot chunkDoc = await firestore
            .collection('user_images')
            .doc(userId)
            .collection('chunks')
            .doc('chunk_$i')
            .get();

        if (chunkDoc.exists) {
          final chunkData = chunkDoc.data() as Map<String, dynamic>;
          fullImage += chunkData['data'];
        }
      }

      return fullImage;
    } catch (e) {
      print('获取分块图片失败: $e');
      return null;
    }
  }

  
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
      print('选择图片失败: $e');
      return null;
    }
  }

  
  Future<bool> deleteImage(String userId) async {
    try {
      await firestore
          .collection('user_images')
          .doc(userId)
          .delete();

      
      final QuerySnapshot chunks = await firestore
          .collection('user_images')
          .doc(userId)
          .collection('chunks')
          .get();

      for (var doc in chunks.docs) {
        await doc.reference.delete();
      }

      return true;
    } catch (e) {
      print('删除图片失败: $e');
      return false;
    }
  }
}