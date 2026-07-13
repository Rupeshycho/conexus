import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../repo/notification_service.dart';
import '../repo/post_repo.dart';

class CreateTextPostScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUsername;
  final String? currentUserAvatar;
  final VoidCallback? onSwitchToImage;

  const CreateTextPostScreen({
    super.key,
    required this.currentUserId,
    required this.currentUsername,
    this.currentUserAvatar,
    this.onSwitchToImage,
  });

  @override
  State<CreateTextPostScreen> createState() => _CreateTextPostScreenState();
}

class _CreateTextPostScreenState extends State<CreateTextPostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  // Pulled from Provider — same PostRepo instance the rest of the app uses.
  late final PostRepo _postRepo;
  bool _isLoading = false;
  static const int _maxCaptionLength = 500;
  static const Color _orange = Color(0xFFFF5722);

  @override
  void initState() {
    super.initState();
    _postRepo = context.read<PostRepo>();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_isLoading) return;

    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      NotificationService.showSnackBar(context, 'Please write a caption');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _postRepo.createTextPost(
        authorId: widget.currentUserId,
        authorUsername: widget.currentUsername,
        authorPhotoUrl: widget.currentUserAvatar ?? '',
        caption: caption,
      );

      _captionController.clear();
      _locationController.clear();
      setState(() {});
      NotificationService.showSnackBar(context, 'Text post published!');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      NotificationService.showSnackBar(context, 'Failed to publish: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          if (_captionController.text.trim().isEmpty) {
            Navigator.pop(context);
            return;
          }
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Discard changes?'),
              content: const Text(
                  'You have unsaved text. Are you sure you want to go back?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Discard')),
              ],
            ),
          );
          if (shouldPop == true) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Text Post'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _publish,
              icon: const Icon(Icons.share, size: 20),
              label: const Text('Share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      autofocus: true,
                      controller: _captionController,
                      maxLines: 6,
                      maxLength: _maxCaptionLength,
                      buildCounter: (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$currentLength/$maxLength',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12),
                            textAlign: TextAlign.end,
                          ),
                        );
                      },
                      decoration: InputDecoration(
                        hintText: 'What\'s on your mind?...',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _captionController.clear(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        hintText: 'Add Location (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: widget.onSwitchToImage ??
                          () => Navigator.pushNamed(context, '/create_image'),
                      icon: const Icon(Icons.add_photo_alternate),
                      label: const Text('Create an Image Post instead'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
