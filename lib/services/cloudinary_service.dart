import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  final CloudinaryPublic cloudinary = CloudinaryPublic(
    'di3lnc0c3',
    'conexus_upload',
    cache: false,
  );

  Future<String> uploadImage(File image) async {
    final response = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(image.path),
    );
    return response.secureUrl;
  }
}