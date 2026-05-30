import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'edit_profile.dart';

class CreateProfile extends StatefulWidget {
  const CreateProfile({super.key});

  @override
  State<CreateProfile> createState() => _CreateProfileState();
}

class _CreateProfileState extends State<CreateProfile> {
  String name = "Sandip Rawal";
  String username = "@creative_sandip";

  String bio =
      "Visual Storyteller & Motion Designer.\n"
      "Creating digital experiences that pulse with energy.";

  File? profileImage;
  final ImagePicker picker = ImagePicker();

  Future<void> pickImage() async {
    final pickedFile =
    await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfile(
          currentName: name,
          currentUsername: username,
          currentBio: bio,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        name = result["name"];
        username = result["username"];
        bio = result["bio"];
      });
    }
  }

  void openViewProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("My Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.deepOrange,
                backgroundImage: profileImage != null
                    ? FileImage(profileImage!)
                    : null,
                child: profileImage == null
                    ? const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 40,
                )
                    : null,
              ),
            ),
            const SizedBox(height: 15),
            Text("Name: $name"),
            const SizedBox(height: 5),
            Text("Username: $username"),
            const SizedBox(height: 10),
            Text("Bio:\n$bio"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4F4),

        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "Conexus",
            style: TextStyle(
              color: Colors.deepOrange,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: const Icon(
            Icons.menu,
            color: Colors.grey,
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 15),
              child: Icon(
                Icons.chat_bubble_outline,
                color: Colors.deepOrange,
              ),
            ),
          ],
        ),

        body: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade300,
                            Colors.deepOrange,
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      bottom: -55,
                      child: CircleAvatar(
                        radius: 58,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 54,
                          backgroundColor: Colors.orange.shade100,

                          child: GestureDetector(
                            onTap: pickImage,
                            child: CircleAvatar(
                              radius: 54,
                              backgroundImage: profileImage != null
                                  ? FileImage(profileImage!)
                                  : null,
                              child: profileImage == null
                                  ? const Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.deepOrange,
                              )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 70),

              Text(
                name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                username,
                style: const TextStyle(
                  color: Colors.deepOrange,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  buildStat("142", "Posts"),
                  buildStat("12.8k", "Followers"),
                  buildStat("482", "Following"),
                ],
              ),

              const SizedBox(height: 30),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  bio,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: openEditProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "Edit Profile",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),

                  const SizedBox(width: 12),

                  OutlinedButton(
                    onPressed: openViewProfile,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 15,
                      ),
                      side: const BorderSide(color: Colors.deepOrange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      "View Own Profile",
                      style: TextStyle(color: Colors.deepOrange),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              const TabBar(
                labelColor: Colors.deepOrange,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.deepOrange,
                tabs: [
                  Tab(icon: Icon(Icons.grid_on)),
                  Tab(icon: Icon(Icons.video_collection)),
                  Tab(icon: Icon(Icons.person_pin)),
                ],
              ),

              SizedBox(
                height: 500,
                child: TabBarView(
                  children: [
                    buildGrid(),
                    buildGrid(),
                    buildGrid(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildStat(String number, String label) {
    return Column(
      children: [
        Text(
          number,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.deepOrange,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }

  Widget buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: 12,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade200,
                Colors.deepOrange.shade300,
              ],
            ),
          ),
          child: const Icon(
            Icons.image,
            color: Colors.white,
            size: 35,
          ),
        );
      },
    );
  }
}