import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = "di3lnc0c3";
  static const String uploadPreset = "conexus_upload";

  static Future<String?> uploadImage(File file) async {
    final uri = Uri.parse(
      "https://api.cloudinary.com/v1_1/$cloudName/image/upload",
    );

    var request = http.MultipartRequest("POST", uri);

    request.fields["upload_preset"] = uploadPreset;

    request.files.add(
      await http.MultipartFile.fromPath(
        "file",
        file.path,
      ),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      var body = await response.stream.bytesToString();
      var json = jsonDecode(body);
      return json["secure_url"];
    }

    return null;
  }
}