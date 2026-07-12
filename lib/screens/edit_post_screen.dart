import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditPostScreen extends StatefulWidget {
  const EditPostScreen({super.key});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late String postId;
  late String initialCaption;
  String? initialLocation;
  String? initialCrossPostMessage;
  late bool isImagePost;
  late TextEditingController _captionController;
  late TextEditingController _locationController;
  late TextEditingController _crossPostController;
  bool _isSaving = false;

  static const int _maxCaptionLength = 500;
  static const Color _orange = Color(0xFFFF5722);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    postId = args['postId'] as String;
    initialCaption = args['caption'] as String;
    initialLocation = args['location'] as String?;
    initialCrossPostMessage = args['crossPostMessage'] as String?;
    isImagePost = args['isImagePost'] as bool;
  }

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: initialCaption);
    _locationController = TextEditingController(text: initialLocation ?? '');
    _crossPostController = TextEditingController(
      text: initialCrossPostMessage ?? '',
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _crossPostController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final newCaption = _captionController.text.trim();
    if (newCaption.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Caption cannot be empty')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> updateData = {
        'caption': newCaption,
        'location': _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
      };
      if (isImagePost) {
        updateData['crossPostMessage'] =
            _crossPostController.text.trim().isEmpty
            ? null
            : _crossPostController.text.trim();
      }
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .update(updateData);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        actions: [
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveChanges,
            icon: const Icon(Icons.save, size: 20),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade400,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _captionController,
                    maxLines: 6,
                    maxLength: _maxCaptionLength,
                    decoration: const InputDecoration(
                      hintText: 'Edit caption...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(
                      hintText: 'Edit location (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  if (isImagePost) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _crossPostController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Edit cross‑post message (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.share),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
