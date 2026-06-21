import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'image_repo.dart';

class ImageRepoImpl implements ImageRepo {
  final cloudinary = CloudinaryPublic(
    "YOUR_CLOUD_NAME",
    "YOUR_UPLOAD_PRESET",
    cache: false,
  );

  @override
  Future<String> uploadImage(File file) async {
    final response = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(file.path),
    );

    return response.secureUrl;
  }
}