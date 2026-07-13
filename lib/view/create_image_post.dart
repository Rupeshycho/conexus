import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../repo/notification_service.dart';
import '../repo/post_repo.dart';

class CreateImagePostScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUsername;
  final String? currentUserAvatar;
  final VoidCallback? onSwitchToText;

  const CreateImagePostScreen({
    super.key,
    required this.currentUserId,
    required this.currentUsername,
    this.currentUserAvatar,
    this.onSwitchToText,
  });

  @override
  State<CreateImagePostScreen> createState() => _CreateImagePostScreenState();
}

class _CreateImagePostScreenState extends State<CreateImagePostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _crossPostController = TextEditingController();
  // Pulled from Provider instead of constructed directly, so this screen
  // shares the same PostRepo instance (and its NotificationRepo) as the
  // rest of the app rather than spinning up a disconnected one.
  late final PostRepo _postRepo;
  File? _selectedImage;
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
    _crossPostController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeImage() => setState(() => _selectedImage = null);

  Future<void> _publish() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      NotificationService.showSnackBar(context, 'Please write a caption');
      return;
    }
    if (_selectedImage == null) {
      NotificationService.showSnackBar(context, 'Please select an image');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _postRepo.createImagePost(
        authorId: widget.currentUserId,
        authorUsername: widget.currentUsername,
        authorPhotoUrl: widget.currentUserAvatar ?? '',
        file: _selectedImage!,
        caption: caption,
      );

      _captionController.clear();
      _locationController.clear();
      _crossPostController.clear();
      _selectedImage = null;
      if (!mounted) return;
      setState(() {});
      NotificationService.showSnackBar(context, 'Image post published!');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        NotificationService.showSnackBar(context, 'Failed to publish: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Image Post'),
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
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _showImageSourceDialog,
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: _selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(_selectedImage!,
                                      fit: BoxFit.cover,
                                      width: double.infinity),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate,
                                        size: 48, color: Colors.grey.shade600),
                                    const SizedBox(height: 8),
                                    Text('Tap to upload image',
                                        style: TextStyle(
                                            color: Colors.grey.shade600)),
                                  ],
                                ),
                        ),
                      ),
                      if (_selectedImage != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                              onPressed: _removeImage,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              iconSize: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _captionController,
                    maxLines: 4,
                    maxLength: _maxCaptionLength,
                    decoration: const InputDecoration(
                      hintText: 'Write a caption...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      hintText: 'Add Location',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _crossPostController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Cross‑post to Instagram (optional caption)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.share),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: widget.onSwitchToText ??
                        () => Navigator.pushNamed(context, '/create_text'),
                    icon: const Icon(Icons.text_fields),
                    label: const Text('Create a Text Post instead'),
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
    );
  }
}
