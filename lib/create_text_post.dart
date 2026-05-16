import 'package:flutter/material.dart';

class CreateTextPostScreen extends StatefulWidget {
  final Function(String caption, String? location) onPostCreated;

  const CreateTextPostScreen({super.key, required this.onPostCreated});

  @override
  State<CreateTextPostScreen> createState() => _CreateTextPostScreenState();
}

class _CreateTextPostScreenState extends State<CreateTextPostScreen> {
  final TextEditingController _captionCtrl = TextEditingController();
  final TextEditingController _locationCtrl = TextEditingController();

  void _publish() {
    final caption = _captionCtrl.text.trim();
    if (caption.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please write something')));
      return;
    }
    final location = _locationCtrl.text.trim().isEmpty
        ? null
        : _locationCtrl.text.trim();
    widget.onPostCreated(caption, location);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Text Post'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _publish,
            child: const Text(
              'Post',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _captionCtrl,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: "What's on your mind? #Conexus",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                hintText: '📍 Add location (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
