import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conexus/model/post_model.dart';
import 'package:conexus/model/user_model.dart';
import 'package:conexus/repo/post_repo.dart';
import 'package:conexus/view/followers_list.dart';
import 'package:conexus/view/following_list.dart';
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:conexus/widgets/profile_post_grid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class OtherProfileScreen extends StatefulWidget {
  final String userId;

  const OtherProfileScreen({super.key, required this.userId});

  @override
  State<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen> {
  UserModel? user;
  bool isLoading = true;
  bool isFollowing = false;
  bool isBlockActionInFlight = false;
  String? errorMessage;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  // Pulled from Provider instead of constructed directly, so this screen
  // shares the same PostRepo instance (and its NotificationRepo) as the
  // rest of the app.
  late final PostRepo _postRepo;

  @override
  void initState() {
    super.initState();
    _postRepo = context.read<PostRepo>();
    _listenToOtherUser();
  }

  void _listenToOtherUser() {
    final firestore = FirebaseFirestore.instance;

    _userSubscription = firestore
        .collection('users')
        .doc(widget.userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final userData = snapshot.data()!;
        final updatedUser = UserModel.fromMap(userData);

        if (mounted) {
          final userVM = context.read<UserViewModel>();
          final following = userVM.currentUser?.following ?? [];

          setState(() {
            user = updatedUser;
            isFollowing = following.contains(widget.userId);
            isLoading = false;
            errorMessage = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = "User not found";
            isLoading = false;
          });
        }
      }
    }, onError: (error) {
      debugPrint("❌ Real-time listener error: $error");
      if (mounted) {
        setState(() {
          errorMessage = "Failed to load user profile";
          isLoading = false;
        });
      }
    });
  }

  Future<void> _toggleFollow() async {
    if (user == null) return;

    final userVM = context.read<UserViewModel>();

    try {
      if (isFollowing) {
        await userVM.unfollow(widget.userId);
        debugPrint("✅ Unfollowed user: ${widget.userId}");
      } else {
        await userVM.follow(widget.userId);
        debugPrint("✅ Followed user: ${widget.userId}");
      }

      setState(() {
        isFollowing = !isFollowing;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFollowing ? "Followed successfully" : "Unfollowed successfully",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Toggle follow error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmBlock({required bool currentlyBlocked}) async {
    if (user == null || isBlockActionInFlight) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(currentlyBlocked ? 'Unblock user?' : 'Block user?'),
        content: Text(
          currentlyBlocked
              ? '${user!.name} will be able to see your profile and follow you again.'
              : '${user!.name} won\'t be able to follow you or see your profile. '
              'You\'ll stop following each other.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              currentlyBlocked ? 'Unblock' : 'Block',
              style: TextStyle(color: currentlyBlocked ? Colors.deepOrange : Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final userVM = context.read<UserViewModel>();
    setState(() => isBlockActionInFlight = true);
    try {
      if (currentlyBlocked) {
        await userVM.unblock(widget.userId);
      } else {
        await userVM.block(widget.userId);
        // Blocking implies unfollowing — reflect that locally right away.
        if (isFollowing) setState(() => isFollowing = false);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentlyBlocked ? '${user!.name} unblocked' : '${user!.name} blocked'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isBlockActionInFlight = false);
    }
  }

  void _openProfileImageViewer() {
    if (user?.profileImage.isEmpty ?? true) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProfileImageViewer(imageUrl: user!.profileImage),
      ),
    );
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepOrange),
        ),
      );
    }

    if (errorMessage != null || user == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.deepOrange,
          title: const Text("Profile", style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                errorMessage ?? "User not found",
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    errorMessage = null;
                  });
                  _listenToOtherUser();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                child: const Text("Retry", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    final userVM = context.watch<UserViewModel>();
    final currentUser = userVM.currentUser;
    final isOwnProfile = currentUser?.uid == widget.userId;
    final isBlocked = userVM.isBlocked(widget.userId);
    final viewerId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return DefaultTabController(
      length: 1,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F4F4),
        appBar: AppBar(
          backgroundColor: Colors.deepOrange,
          title: const Text("Profile", style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (!isOwnProfile)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'block') _confirmBlock(currentlyBlocked: isBlocked);
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'block',
                    child: Text(isBlocked ? 'Unblock' : 'Block'),
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
                          colors: [Colors.orange.shade300, Colors.deepOrange],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -55,
                      child: GestureDetector(
                        onTap: _openProfileImageViewer,
                        child: CircleAvatar(
                          radius: 58,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: Colors.orange.shade100,
                            child: CircleAvatar(
                              radius: 54,
                              backgroundImage: user!.profileImage.isNotEmpty
                                  ? NetworkImage(user!.profileImage)
                                  : null,
                              child: user!.profileImage.isEmpty
                                  ? const Icon(Icons.person, size: 60, color: Colors.deepOrange)
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
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                user!.username.isEmpty ? "@username" : "@${user!.username.replaceAll("@", "")}",
                style: const TextStyle(color: Colors.deepOrange, fontSize: 16),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  StreamBuilder<List<PostModel>>(
                    stream: _postRepo.getUserPosts(user!.uid, viewerId),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return _buildStat(count.toString(), "Posts");
                    },
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FollowersList(followers: user!.followers),
                        ),
                      );
                    },
                    child: _buildStat(user!.followers.length.toString(), "Followers"),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FollowingList(following: user!.following),
                        ),
                      );
                    },
                    child: _buildStat(user!.following.length.toString(), "Following"),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  user!.bio.isEmpty ? "No Bio Yet" : user!.bio,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 16, height: 1.5),
                ),
              ),
              const SizedBox(height: 30),
              if (!isOwnProfile)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: isBlocked
                        ? OutlinedButton.icon(
                      onPressed: isBlockActionInFlight
                          ? null
                          : () => _confirmBlock(currentlyBlocked: true),
                      icon: const Icon(Icons.block, color: Colors.red),
                      label: const Text(
                        "Blocked · Tap to unblock",
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    )
                        : ElevatedButton(
                      onPressed: _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? Colors.grey : Colors.deepOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: Text(
                        isFollowing ? "Unfollow" : "Follow",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              const TabBar(
                labelColor: Colors.deepOrange,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.deepOrange,
                tabs: [Tab(icon: Icon(Icons.grid_on))],
              ),
              SizedBox(
                height: 500,
                child: TabBarView(
                  children: [
                    ProfilePostGrid(userId: user!.uid, postRepo: _postRepo),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String number, String label) {
    return Column(
      children: [
        Text(number, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.black54)),
      ],
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
                        child: CircularProgressIndicator(color: Colors.deepOrange),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.broken_image, color: Colors.white54, size: 60);
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
                  decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 26),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}