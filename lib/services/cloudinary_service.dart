import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = "di3lnc0c3";
  static const String uploadPreset = "conexus_upload";

  static Future<String?> uploadFile(
      File file, {
        required String resourceType,
      }) async {
    final uri = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload",
    );

    final request = http.MultipartRequest("POST", uri)
      ..fields["upload_preset"] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath("file", file.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final body = await response.stream.bytesToString();
      final json = jsonDecode(body);
      return json["secure_url"] as String?;
    }

    return null;
  }

  static Future<String?> uploadImage(File file) async {
    return uploadFile(file, resourceType: "image");
  }

  static Future<String?> uploadVideo(File file) async {
    return uploadFile(file, resourceType: "video");
  }
}