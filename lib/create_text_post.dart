import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CreateTextPostScreen extends StatefulWidget {
  final Function(String userName, String caption)? onPostCreated;

  const CreateTextPostScreen({super.key, this.onPostCreated});

  @override
  State<CreateTextPostScreen> createState() => _CreateTextPostScreenState();
}

class _CreateTextPostScreenState extends State<CreateTextPostScreen> {
  final TextEditingController _captionController = TextEditingController();
  File? _coverImage;
  bool _isCrossPostEnabled = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _coverImage = File(pickedFile.path);
      });
    }
  }

  void _sharePost() {
    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something!')),
      );
      return;
    }

    widget.onPostCreated?.call('', caption);

    _captionController.clear();
    setState(() {
      _coverImage = null;
      _isCrossPostEnabled = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post shared!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Create New Post',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _sharePost,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1877F2),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            child: const Text('Share'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: _pickCoverImage,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                ),
                child: _coverImage == null
                    ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 44,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to upload cover',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
                    : ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(_coverImage!, fit: BoxFit.cover),
                      Container(color: Colors.black26),
                      const Center(
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _captionController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: "What's happening? #Conexus",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionTile(
              icon: Icons.location_on_outlined,
              label: 'Add Location',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Location picker coming soon')),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildOptionTile(
              icon: Icons.people_alt_outlined,
              label: 'Tag Friends',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tag friends feature coming soon')),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildOptionTile(
              icon: Icons.music_note,
              label: 'Add Music',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Music picker coming soon')),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildOptionTile(
              icon: Icons.public,
              label: 'Audience: Everyone',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Audience settings coming soon')),
                );
              },
            ),
            const SizedBox(height: 24),
            const Divider(),
            SwitchListTile(
              title: const Text('Cross-post to Instagram'),
              subtitle: const Text('Share automatically'),
              value: _isCrossPostEnabled,
              onChanged: (bool value) {
                setState(() {
                  _isCrossPostEnabled = value;
                });
              },
              secondary: const Icon(Icons.camera_alt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade700),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontSize: 16)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}