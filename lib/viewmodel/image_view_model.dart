import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../repo/image_repo.dart';
import '../repo/image_repo_impl.dart';

class ImageViewModel extends ChangeNotifier {
  final ImageRepo _imageRepo = ImageRepoImpl();

  final ImagePicker _picker = ImagePicker();

  File? selectedImage;

  Future<void> pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (picked != null) {
      selectedImage = File(picked.path);
      notifyListeners();
    }
  }

  Future<String> uploadImage() async {
    if (selectedImage == null) {
      return "";
    }

    return await _imageRepo.uploadProfileImage(selectedImage!);
  }

  void clearImage() {
    selectedImage = null;
    notifyListeners();
  }
}