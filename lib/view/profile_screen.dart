import 'package:conexus/model/post_model.dart';
import 'package:conexus/model/user_model.dart';
import 'package:conexus/repo/post_repo.dart';
import 'package:conexus/view/followers_list.dart';
import 'package:conexus/view/following_list.dart';
import 'package:conexus/view/share_profile.dart';
import 'package:conexus/view/edit_profile.dart';
import 'package:conexus/view/notification_screen.dart';
import 'package:conexus/viewmodel/notification_viewmodel.dart';
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:conexus/widgets/image_viewer_screen.dart';
import 'package:conexus/widgets/profile_post_grid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  /// If null, shows the signed-in user's own profile (Edit/Share buttons).
  /// If set and different from the signed-in user, shows that user's
  /// profile instead (Follow/Unfollow + Block/Unblock menu).
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? user;
  bool isLoading = true;
  bool isFollowActionInFlight = false;
  // Pulled from Provider instead of constructed directly, so this screen
  // shares the same PostRepo instance (and its NotificationRepo) as the
  // rest of the app.
  late final PostRepo _postRepo;

  bool get _isOwnProfile {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return widget.userId == null || widget.userId == myUid;
  }

  @override
  void initState() {
    super.initState();
    _postRepo = context.read<PostRepo>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadProfile();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      context.read<NotificationViewModel>().listenToNotifications(uid);
    });
  }

  Future<void> loadProfile() async {
    final vm = context.read<UserViewModel>();

    if (_isOwnProfile) {
      await vm.loadCurrentUser();
      if (!mounted) return;
      setState(() {
        user = vm.currentUser;
        isLoading = false;
      });
    } else {
      // Make sure the current user is loaded too, so follow/block state
      // (which lives on the current user's document) is available.
      if (vm.currentUser == null) {
        await vm.loadCurrentUser();
      }
      final otherUser = await vm.getUser(widget.userId!);
      if (!mounted) return;
      setState(() {
        user = otherUser;
        isLoading = false;
      });
    }
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
        user = user!.copyWith(
          name: result["name"] ?? user!.name,
          username: result["username"] ?? user!.username,
          bio: result["bio"] ?? user!.bio,
          profileImage: result["profileImageUrl"] ?? user!.profileImage,
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
        builder: (_) => ImageViewerScreen(imageUrl: user!.profileImage),
      ),
    );
  }

  Future<void> _toggleFollow() async {
    if (user == null || isFollowActionInFlight) return;
    final vm = context.read<UserViewModel>();
    final alreadyFollowing = vm.isFollowing(user!.id);

    setState(() => isFollowActionInFlight = true);
    try {
      if (alreadyFollowing) {
        await vm.unfollow(user!.id);
      } else {
        await vm.follow(user!.id);
      }
      await loadProfile(); // refresh follower counts
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isFollowActionInFlight = false);
    }
  }

  Future<void> _confirmBlock() async {
    if (user == null) return;
    final vm = context.read<UserViewModel>();
    final alreadyBlocked = vm.isBlocked(user!.id);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(alreadyBlocked ? 'Unblock user?' : 'Block user?'),
        content: Text(
          alreadyBlocked
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
              alreadyBlocked ? 'Unblock' : 'Block',
              style: TextStyle(color: alreadyBlocked ? Colors.deepOrange : Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      if (alreadyBlocked) {
        await vm.unblock(user!.id);
      } else {
        await vm.block(user!.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(alreadyBlocked ? '${user!.name} unblocked' : '${user!.name} blocked'),
          ),
        );
        await loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
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

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not found")),
      );
    }

    final vm = context.watch<UserViewModel>();
    final unreadCount = context
        .watch<NotificationViewModel>()
        .notifications
        .where((n) => !n.isRead)
        .length;
    final isFollowing = !_isOwnProfile && vm.isFollowing(user!.id);
    final isBlocked = !_isOwnProfile && vm.isBlocked(user!.id);
    final viewerId = FirebaseAuth.instance.currentUser?.uid ?? '';

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
            style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
          ),
          leading: _isOwnProfile ? null : null, // default back button on other profiles
          automaticallyImplyLeading: !_isOwnProfile,
          actions: [
            if (_isOwnProfile)
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.deepOrange, size: 28),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationScreen()),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                    ),
                ],
              )
            else
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.deepOrange),
                onSelected: (value) {
                  if (value == 'block') _confirmBlock();
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
                        onTap: openProfileImageViewer,
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
                      return buildStat(count.toString(), "Posts");
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
                    child: buildStat(user!.followers.length.toString(), "Followers"),
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
                    child: buildStat(user!.following.length.toString(), "Following"),
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
              if (_isOwnProfile)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: openEditProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text("Edit Profile", style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: openShareProfile,
                      icon: const Icon(Icons.share, color: Colors.deepOrange),
                      label: const Text("Share Profile", style: TextStyle(color: Colors.deepOrange)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                        side: const BorderSide(color: Colors.deepOrange),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isBlocked)
                      OutlinedButton.icon(
                        onPressed: _confirmBlock,
                        icon: const Icon(Icons.block, color: Colors.red),
                        label: const Text("Blocked · Tap to unblock", style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: isFollowActionInFlight ? null : _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing ? Colors.grey.shade300 : Colors.deepOrange,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: isFollowActionInFlight
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : Text(
                          isFollowing ? "Following" : "Follow",
                          style: TextStyle(color: isFollowing ? Colors.black87 : Colors.white),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 30),
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

  Widget buildStat(String number, String label) {
    return Column(
      children: [
        Text(number, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}