import 'dart:io';

abstract class ImageRepo {
  Future<String> uploadImage(File file);
}