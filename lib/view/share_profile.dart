import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ShareProfileScreen extends StatelessWidget {
  final String name;
  final String username;
  final String bio;

  const ShareProfileScreen({
    super.key,
    required this.name,
    required this.username,
    required this.bio,
  });

  String get profileLink =>
      "conexus.app/profile/${username.replaceAll('@', '')}";

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: profileLink));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Profile link copied to clipboard!"),
        backgroundColor: Colors.deepOrange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F4),
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: const Text(
          "Share Profile",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      // ✅ FIX 1: Use withValues() instead of withOpacity
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      "QR Code",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),

                    QrImageView(
                      data: "https://$profileLink",
                      version: QrVersions.auto,
                      size: 180,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.deepOrange,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.deepOrange,
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Text(
                      "Scan to visit my profile",
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              GestureDetector(
                onTap: () => _copyLink(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    // ✅ FIX 2: Use withValues() instead of withOpacity
                    color: Colors.deepOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profileLink,
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.copy,
                        color: Colors.deepOrange,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}