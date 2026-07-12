import 'dart:io';

abstract class ImageRepo {
  Future<String> uploadProfileImage(File image);
}