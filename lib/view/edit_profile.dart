import 'dart:io';
import 'package:conexus/repo/image_repo_impl.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../repo/image_repo.dart';

class EditProfile extends StatefulWidget {
  final String currentName;
  final String currentUsername;
  final String currentBio;
  final String currentImageUrl;

  const EditProfile({
    super.key,
    required this.currentName,
    required this.currentUsername,
    required this.currentBio,
    required this.currentImageUrl,
  });

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  late TextEditingController nameController;
  late TextEditingController usernameController;
  late TextEditingController bioController;

  File? profileImage;
  String? uploadedImageUrl;

  bool isLoading = false;

  final ImagePicker picker = ImagePicker();
  final ImageRepo imageRepo = ImageRepoImpl();

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.currentName);
    usernameController = TextEditingController(text: widget.currentUsername);
    bioController = TextEditingController(text: widget.currentBio);

    uploadedImageUrl = widget.currentImageUrl;
  }

  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        profileImage = File(pickedFile.path);
      });
    }
  }

  Future<String> uploadImageIfNeeded() async {
    if (profileImage == null) {
      return uploadedImageUrl ?? "";
    }

    final url = await imageRepo.uploadImage(profileImage!);
    return url;
  }

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  InputDecoration customDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Colors.deepOrange,
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            Stack(
              alignment: Alignment.bottomRight,
              children: [
                GestureDetector(
                  onTap: pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.deepOrange,
                    backgroundImage: profileImage != null
                        ? FileImage(profileImage!)
                        : (uploadedImageUrl != null &&
                        uploadedImageUrl!.isNotEmpty)
                        ? NetworkImage(uploadedImageUrl!)
                    as ImageProvider
                        : null,
                    child: (profileImage == null &&
                        (uploadedImageUrl == null ||
                            uploadedImageUrl!.isEmpty))
                        ? const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 50,
                    )
                        : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            TextButton.icon(
              onPressed: pickImage,
              icon: const Icon(
                Icons.photo_library,
                color: Colors.deepOrange,
              ),
              label: const Text(
                "Change Profile Picture",
                style: TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 25),

            TextField(
              controller: nameController,
              decoration: customDecoration("Full Name"),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: usernameController,
              decoration: customDecoration("Username"),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: bioController,
              maxLines: 5,
              decoration: customDecoration("Bio"),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  setState(() => isLoading = true);

                  final imageUrl = await uploadImageIfNeeded();

                  if (!context.mounted) return;

                  final result = {
                    "name": nameController.text,
                    "username": usernameController.text,
                    "bio": bioController.text,
                    "profileImageUrl": imageUrl,
                  };

                  setState(() => isLoading = false);

                  if (!context.mounted) return;

                  Navigator.of(context).pop(result);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  "Save Changes",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}