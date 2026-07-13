import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditPostScreen extends StatefulWidget {
  final String postId;
  final String initialCaption;
  final String? initialLocation;
  final String? initialCrossPostMessage;
  final bool isImagePost;

  const EditPostScreen({
    super.key,
    required this.postId,
    required this.initialCaption,
    this.initialLocation,
    this.initialCrossPostMessage,
    required this.isImagePost,
  });

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _captionController;
  late TextEditingController _locationController;
  late TextEditingController _crossPostController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.initialCaption);
    _locationController =
        TextEditingController(text: widget.initialLocation ?? '');
    _crossPostController =
        TextEditingController(text: widget.initialCrossPostMessage ?? '');
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caption cannot be empty')),
      );
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
      if (widget.isImagePost) {
        updateData['crossPostMessage'] =
            _crossPostController.text.trim().isEmpty
                ? null
                : _crossPostController.text.trim();
      }
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update(updateData);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
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
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade400,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
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
                    maxLength: 500,
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
                  if (widget.isImagePost) ...[
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
