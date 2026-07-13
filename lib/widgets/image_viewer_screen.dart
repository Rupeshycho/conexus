// lib/widgets/image_viewer_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';

/// Full-screen, pinch-to-zoom image viewer.
/// Pass exactly one of [imageUrl] (network) or [imageFile] (local, e.g. a
/// freshly picked profile photo that hasn't been uploaded yet).
class ImageViewerScreen extends StatelessWidget {
  final String? imageUrl;
  final File? imageFile;

  const ImageViewerScreen({super.key, this.imageUrl, this.imageFile})
      : assert(
  imageUrl != null || imageFile != null,
  'ImageViewerScreen needs either imageUrl or imageFile',
  );

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
                  child: imageFile != null
                      ? Image.file(imageFile!, fit: BoxFit.contain)
                      : Image.network(
                    imageUrl!,
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
