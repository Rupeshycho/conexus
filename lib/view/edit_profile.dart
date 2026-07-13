import 'dart:io';

import 'package:conexus/viewmodel/image_view_model.dart';
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:conexus/widgets/image_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

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

  bool isLoading = false;
  String imageUrl = "";

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.currentName);
    usernameController = TextEditingController(text: widget.currentUsername);
    bioController = TextEditingController(text: widget.currentBio);
    imageUrl = widget.currentImageUrl;
  }

  Future<void> chooseImage(ImageSource source) async {
    final imageVM = context.read<ImageViewModel>();
    await imageVM.pickImage(source);

    if (mounted) {
      setState(() {});
    }
  }

  void showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    "Choose Profile Picture",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.deepOrange),
                title: const Text("Camera"),
                onTap: () {
                  Navigator.pop(context);
                  chooseImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.deepOrange),
                title: const Text("Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  chooseImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void openImageViewer(File? localFile) {
    if (localFile == null && imageUrl.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(
          imageFile: localFile,
          // Only pass the network URL when there's no freshly-picked
          // local file — ImageViewerScreen expects exactly one source.
          imageUrl: localFile == null ? imageUrl : null,
        ),
      ),
    );
  }

  Future<void> saveProfile() async {
    setState(() => isLoading = true);

    final imageVM = context.read<ImageViewModel>();
    final userVM = context.read<UserViewModel>();

    String finalImageUrl = imageUrl;

    if (imageVM.selectedImage != null) {
      finalImageUrl = await imageVM.uploadImage();
    }

    final currentUser = userVM.currentUser;

    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to load user.")),
        );
      }
      setState(() => isLoading = false);
      return;
    }

    // copyWith carries every other field (contact, email, aboutMe,
    // fcmToken, isOnline, lastSeen, createdAt) forward untouched instead
    // of dropping them, which a manual UserModel(...) rebuild would do.
    final updatedUser = currentUser.copyWith(
      name: nameController.text.trim().isEmpty
          ? currentUser.name
          : nameController.text.trim(),
      username: usernameController.text.trim().isEmpty
          ? currentUser.username
          : usernameController.text.trim(),
      bio: bioController.text.trim().isEmpty
          ? currentUser.bio
          : bioController.text.trim(),
      profileImage:
      finalImageUrl.isEmpty ? currentUser.profileImage : finalImageUrl,
    );

    // UserViewModel exposes `editProfile`, not `updateProfile` — the
    // latter only exists on UserRepo. editProfile also updates `_user`
    // in place when the ids match, keeping other screens in sync.
    final success = await userVM.editProfile(updatedUser);

    if (!mounted) return;

    imageVM.clearImage();
    setState(() => isLoading = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userVM.error ?? "Failed to update profile")),
      );
      return;
    }

    Navigator.pop(context, {
      "name": updatedUser.name,
      "username": updatedUser.username,
      "bio": updatedUser.bio,
      "profileImageUrl": updatedUser.profileImage,
    });
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
        borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageVM = context.watch<ImageViewModel>();
    File? profileImage = imageVM.selectedImage;

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

            GestureDetector(
              onTap: () => openImageViewer(profileImage),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.deepOrange,
                backgroundImage: profileImage != null
                    ? FileImage(profileImage)
                    : imageUrl.isNotEmpty
                    ? NetworkImage(imageUrl)
                    : null,
                child: profileImage == null && imageUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 50)
                    : null,
              ),
            ),

            const SizedBox(height: 12),

            TextButton.icon(
              onPressed: showImagePickerOptions,
              icon: const Icon(Icons.photo_library, color: Colors.deepOrange),
              label: const Text(
                "Change Profile Picture",
                style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600),
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
                onPressed: isLoading ? null : saveProfile,
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
