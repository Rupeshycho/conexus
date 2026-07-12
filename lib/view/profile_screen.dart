import 'package:conexus/model/user_model.dart';
import 'package:conexus/view/followers_list.dart';
import 'package:conexus/view/following_list.dart';
import 'package:conexus/view/share_profile.dart';
import 'package:conexus/view/edit_profile.dart';
import 'package:conexus/view/notifications_screen.dart';
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? user;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadProfile();
    });
  }

  Future<void> loadProfile() async {
    final vm = context.read<UserViewModel>();

    await vm.loadCurrentUser();

    if (!mounted) return;

    setState(() {
      user = vm.currentUser;
      isLoading = false;
    });
  }

  Future<void> openEditProfile() async {
    if (user == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfile(
          currentName: user!.name,
          currentUsername: user!.username,
          currentBio: user!.bio,
          currentImageUrl: user!.profileImage,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        user = UserModel(
          uid: user!.uid,
          name: result["name"] ?? user!.name,
          username: result["username"] ?? user!.username,
          bio: result["bio"] ?? user!.bio,
          profileImage: result["profileImageUrl"] ?? user!.profileImage,
          followers: user!.followers,
          following: user!.following,
        );
      });
    } else {
      await loadProfile();
    }
  }

  void openShareProfile() {
    if (user == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShareProfileScreen(
          name: user!.name,
          username: user!.username,
          bio: user!.bio,
        ),
      ),
    );
  }

  void openProfileImageViewer() {
    if (user == null || user!.profileImage.isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProfileImageViewer(
          imageUrl: user!.profileImage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.deepOrange,
          ),
        ),
      );
    }

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text("User not found"),
        ),
      );
    }

    return DefaultTabController(
      length: 1,
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
          // ❌ Menu icon REMOVED
          leading: null,
          actions: [
            // Notification Bell Icon
            Stack(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.deepOrange,
                    size: 28,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
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
                      child: GestureDetector(
                        onTap: openProfileImageViewer,
                        child: CircleAvatar(
                          radius: 58,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: Colors.orange.shade100,
                            child: CircleAvatar(
                              radius: 54,
                              backgroundImage:
                              user!.profileImage.isNotEmpty
                                  ? NetworkImage(user!.profileImage)
                                  : null,

                              child: user!.profileImage.isEmpty
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
                user!.name.isEmpty ? "No Name" : user!.name,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                user!.username.isEmpty
                    ? "@username"
                    : "@${user!.username.replaceAll("@", "")}",
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

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FollowersList(
                            followers: user!.followers,
                          ),
                        ),
                      );
                    },
                    child: buildStat(
                      user!.followers.length.toString(),
                      "Followers",
                    ),
                  ),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FollowingList(
                            following: user!.following,
                          ),
                        ),
                      );
                    },
                    child: buildStat(
                      user!.following.length.toString(),
                      "Following",
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  user!.bio.isEmpty ? "No Bio Yet" : user!.bio,
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
                  OutlinedButton.icon(
                    onPressed: openShareProfile,
                    icon: const Icon(
                      Icons.share,
                      color: Colors.deepOrange,
                    ),
                    label: const Text(
                      "Share Profile",
                      style: TextStyle(color: Colors.deepOrange),
                    ),
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
                ],
              ),

              SizedBox(
                height: 500,
                child: TabBarView(
                  children: [
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

class _ProfileImageViewer extends StatelessWidget {
  final String imageUrl;

  const _ProfileImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: Hero(
                  tag: "profileImage",
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.deepOrange,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 60,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: 40,
            right: 20,
            child: SafeArea(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}