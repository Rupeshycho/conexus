import 'package:flutter/material.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  static const Color orange = Color(0xFFB5651D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About Us"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 10),

            const CircleAvatar(
              radius: 45,
              child: Icon(
                Icons.people,
                size: 45,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              "Conexus",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              "Connect • Share • Discover",
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 10),

            Text(
              "Version 2.4.1 (Build 890)",
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),

            const SizedBox(height: 30),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "About",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Conexus is a social networking application designed to help users connect with friends, share updates, and manage their profiles through a secure and easy-to-use platform.",
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Features",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 10),
                    ListTile(
                      leading: Icon(Icons.check_circle, color: orange),
                      title: Text("User Authentication"),
                    ),
                    ListTile(
                      leading: Icon(Icons.check_circle, color: orange),
                      title: Text("Profile Management"),
                    ),
                    ListTile(
                      leading: Icon(Icons.check_circle, color: orange),
                      title: Text("Privacy Controls"),
                    ),
                    ListTile(
                      leading: Icon(Icons.check_circle, color: orange),
                      title: Text("Dark Mode"),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      "Developed By",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text("Team Phoenix"),
                    Text("Softwarica College"),
                    Text("Coventry University"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            Text(
              "© 2026 Conexus",
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}