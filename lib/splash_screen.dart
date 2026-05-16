import 'dart:async';

import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    // Navigate after 3 seconds
    Timer(const Duration(seconds: 3), () {

      // CHANGE THIS SCREEN
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );

    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,

      body: Container(
        width: double.infinity,

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xff000000),
              Color(0xff111111),
              Color(0xff000000),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // LOGO
            ScaleTransition(
              scale: _animation,
              child: Container(
                height: 150,
                width: 150,

                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),

                  gradient: const LinearGradient(
                    colors: [
                      Color(0xffff9a44),
                      Color(0xffff4d6d),
                    ],
                  ),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.5),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ],
                ),

                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: Image.asset(
                   "assets/images/img.png",
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // APP NAME
            RichText(
              text: const TextSpan(
                children: [

                  TextSpan(
                    text: "Cone",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),

                  TextSpan(
                    text: "x",
                    style: TextStyle(
                      color: Color(0xffff7b54),
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  TextSpan(
                    text: "us",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // TAGLINE
            const Text(
              "CONNECT • CHAT • COLLABORATE",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 3,
                fontWeight: FontWeight.w400,
              ),
            ),

            const SizedBox(height: 80),

            // LOADING
            const SizedBox(
              height: 30,
              width: 30,
              child: CircularProgressIndicator(
                color: Color(0xffff7b54),
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}






// DEMO HOME SCREEN
// Replace with your LoginScreen()

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Conexus"),
      ),

      body: const Center(
        child: Text(
          "Home Screen",
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
          ),
        ),
      ),
    );
  }
}