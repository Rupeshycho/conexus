import 'package:flutter/material.dart';
class SendMessage extends StatefulWidget {
  const SendMessage({super.key});

  @override
  State<SendMessage> createState() => _SendMessageState();
}

class _SendMessageState extends State<SendMessage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFFFae42),
        elevation: 2,

        centerTitle: false, // title moves to left

        title: const Text("Conexus", style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            decoration: TextDecoration.underline,
            decorationThickness: 1.5, // thickness of underline
            decorationColor: Colors.white,

        ),
        ),

        actions: [

          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          const SizedBox(width: 10),

          GestureDetector(
            onTap: (){
              //required action
            },
            child: CircleAvatar(
              radius:20,
              backgroundImage: AssetImage("Assets/Image/profile_pic.png"),
            ),
          ),
          const SizedBox(width:10),
        ],


      ),
        body: const Center(
        child: Text(
          "Send Message Screen",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
