import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class StorageService {
  static const String _cloudName = 'di5nziauv';
  static const String _uploadPreset = 'campus';

  // Upload any file and return URL
Future<String> uploadFile(File file, String folder) async {
  final url = Uri.parse(
    'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload',
  );

  final request = http.MultipartRequest('POST', url);
  request.fields['upload_preset'] = _uploadPreset;
  request.fields['folder'] = folder;
  request.fields['resource_type'] = 'auto';
  request.files.add(
    await http.MultipartFile.fromPath('file', file.path),
  );

  final response = await request.send();
  final responseBody = await response.stream.bytesToString();
  final json = jsonDecode(responseBody);

  if (response.statusCode == 200) {
    return json['secure_url'] as String;
  } else {
    throw Exception('Upload failed: ${json['error']['message']}');
  }
}

  // Upload image specifically (for announcements)
  Future<String> uploadImage(File imageFile, String folder) async {
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', url);
    request.fields['upload_preset'] = _uploadPreset;
    request.fields['folder'] = folder;
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    final json = jsonDecode(responseBody);

    if (response.statusCode == 200) {
      return json['secure_url'] as String;
    } else {
      throw Exception('Image upload failed: ${json['error']['message']}');
    }
  }

  Future<void> deleteImage(String imageUrl) async {
    // Skipped — requires server-side secret
  }
}