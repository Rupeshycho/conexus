import 'package:flutter/material.dart';

class EditProfile extends StatefulWidget {
  final String currentName;
  final String currentUsername;
  final String currentBio;

  const EditProfile({
    super.key,
    required this.currentName,
    required this.currentUsername,
    required this.currentBio,
  });

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  late TextEditingController nameController;
  late TextEditingController usernameController;
  late TextEditingController bioController;

  @override
  void initState() {
    super.initState();

    nameController =
        TextEditingController(text: widget.currentName);

    usernameController =
        TextEditingController(text: widget.currentUsername);

    bioController =
        TextEditingController(text: widget.currentBio);
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
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            const SizedBox(height: 20),

            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.deepOrange,
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 50,
              ),
            ),

            const SizedBox(height: 35),

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
                onPressed: () {
                  Navigator.pop(context, {
                    "name": nameController.text,
                    "username": usernameController.text,
                    "bio": bioController.text,
                  });
                },

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),

                child: const Text(
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