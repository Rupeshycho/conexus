import 'dart:io';

import 'package:conexus/repo/image_repo.dart';
import 'package:conexus/services/cloudinary_service.dart';

class ImageRepoImpl extends ImageRepo {
  final CloudinaryService _cloudinaryService = CloudinaryService();

  @override
  Future<String> uploadProfileImage(File image) async {
    return await _cloudinaryService.uploadImage(image);
  }
}