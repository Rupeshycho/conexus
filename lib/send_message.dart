import 'dart:math';

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
            letterSpacing: 1.2,
            decoration: TextDecoration.underline,
            decorationThickness: 1, // thickness of underline
            decorationColor: Colors.black,

            ),
        ),

        actions: [

          GestureDetector(
            onTap: (){         //onTap:
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
      body:Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children:[
            Text("Messages",style:TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            letterSpacing: 1,
          )),
            SizedBox(height: 10), //height for vertical spacing and width for horizontal spacing
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children:[

                    Card(
                        color: Colors.white24,
                        elevation: 10,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child:Column(
                           children:[
                             Image.asset(
                               "Assets/Image/profile_pic.png",
                               height: 150,
                               width: 150,
                               fit: BoxFit.cover,
                             ),

                              Padding(
                                  padding: const EdgeInsets.all(12),
                                    child: Text(
                                        "Profile",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                              ),

                           ]
                        )
                    ),
                  SizedBox(width:8),
                  Card(
                      color: Colors.white24,
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child:Column(
                          children:[
                            Image.asset(
                              "Assets/Image/profile_pic.png",
                              height: 150,
                              width: 150,
                              fit: BoxFit.cover,
                            ),

                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                "Profile",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          ]
                      )
                  ),
                ]
              ),
            ),

          ]
        ),
      ),
    ) ;
  }
}
