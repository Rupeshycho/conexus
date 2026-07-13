import 'dart:io';

import 'package:conexus/repo/image_repo.dart';
import 'package:conexus/services/cloudinary_service.dart';

class ImageRepoImpl extends ImageRepo {
  @override
  Future<String> uploadProfileImage(File image) async {
    final url = await CloudinaryService.uploadImage(image);
    if (url == null) {
      throw Exception("Image upload failed");
    }
    return url;
  }
}