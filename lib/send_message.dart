import 'package:flutter/material.dart';
<<<<<<< HEAD

=======
>>>>>>> 2826b703fc03a019fddbac9323b4d749d666f210
class SendMessage extends StatefulWidget {
  const SendMessage({super.key});

  @override
  State<SendMessage> createState() => _SendMessageState();
}

class _SendMessageState extends State<SendMessage> {
  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: AppBar(
        backgroundColor: Colors.white24,
        elevation: 1,

        iconTheme: const IconThemeData(
          color: Colors.white12,
        ),

        title: const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Conexus",
            style: TextStyle(
              color: Color(0xFFF5B727),
              fontWeight: FontWeight.bold,
              fontSize: 26,
            ),
          ),
        ),
      ),

      body: const Center(
        child: Text(
          "Send Message Screen",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
=======
    return const Placeholder();
>>>>>>> 2826b703fc03a019fddbac9323b4d749d666f210
  }
}
