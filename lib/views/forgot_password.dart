import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {

  // ── PUT YOUR EMAILJS KEYS HERE ──
  final String serviceId  = "service_trbjk5o";   // 👈 your Service ID
  final String templateId = "template_koinwec";  // 👈 your Template ID
  final String publicKey  = "5po448ty6vxdExARW";   // 👈 your Public Key

  TextEditingController emailController    = TextEditingController();
  TextEditingController otpController      = TextEditingController();


  String generatedOtp = "";
  bool otpSent        = false;
  bool otpVerified    = false;
  bool isLoading      = false;
  bool hidePass       = true;
  bool hideConfPass   = true;

  // Generate random 6 digit OTP
  String generateOtp() {
    Random random = Random();
    int otp = 100000 + random.nextInt(900000);
    return otp.toString();
  }

  // Send OTP via EmailJS
  Future<void> sendOtp() async {

    if (emailController.text.trim().isEmpty) {
      showSnack("Please enter your email", Colors.red);
      return;
    }

    setState(() => isLoading = true);

    generatedOtp = generateOtp();

    try {

      final response = await http.post(
        Uri.parse("https://api.emailjs.com/api/v1.0/email/send"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "service_id":  serviceId,
          "template_id": templateId,
          "user_id":     publicKey,
          "template_params": {
            "to_email": emailController.text.trim().toLowerCase(),
            "otp_code": generatedOtp,
          },
        }),
      );

      if (response.statusCode == 200) {
        setState(() => otpSent = true);
        showSnack("OTP sent to your email!", Colors.green);
      } else {
        showSnack("Failed to send OTP. Try again.", Colors.red);
      }

    } catch (e) {
      showSnack("Error: $e", Colors.red);
    }

    setState(() => isLoading = false);
  }

  // Verify OTP
  void verifyOtp() {
    if (otpController.text.trim() == generatedOtp) {
      setState(() => otpVerified = true);
      showSnack("OTP Verified!", Colors.green);
    } else {
      showSnack("Wrong OTP. Try again.", Colors.red);
    }
  }

  // Reset Password using Firebase
  Future<void> resetPassword() async {
    setState(() => isLoading = true);


    try {

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim().toLowerCase(),
      );

      showSnack(
        "Password reset email sent. Open your email and click the reset link.",
        Colors.green,
      );

      await Future.delayed(const Duration(seconds: 2));

      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      showSnack(e.message ?? "Error occurred", Colors.red);
    }

    setState(() => isLoading = false);
  }

  void showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0XFFF5F5F5),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.deepOrange,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [

              const SizedBox(height: 20),

              // Icon
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_reset,
                  size: 50,
                  color: Colors.deepOrange,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                otpVerified
                    ? "Set New Password"
                    : otpSent
                    ? "Enter OTP Code"
                    : "Forgot Password?",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                otpVerified
                    ? "Create a strong new password"
                    : otpSent
                    ? "We sent a 6-digit code to your email"
                    : "Enter your email to receive OTP code",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 30),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── STEP 1: Email ──
                    if (!otpSent) ...[

                      const Text(
                        "Email Address",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.brown,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: "example@gmail.com",
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                          ),
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.deepOrange,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: isLoading ? null : () async {
                            await sendOtp();
                          },
                          child: isLoading
                              ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                              : const Text(
                            "Send OTP",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // ── STEP 2: OTP ──
                    if (otpSent && !otpVerified) ...[

                      const Text(
                        "Enter OTP Code",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.brown,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                        ),
                        decoration: InputDecoration(
                          hintText: "000000",
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            letterSpacing: 8,
                          ),
                          counterText: "",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.deepOrange,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Resend OTP
                      Center(
                        child: GestureDetector(
                          onTap: () async {
                            await sendOtp();
                          },
                          child: const Text(
                            "Resend OTP",
                            style: TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: () {
                            verifyOtp();
                          },
                          child: const Text(
                            "Verify OTP",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // ── STEP 3: New Password ──
                    if (otpVerified) ...[

                      const SizedBox(height: 20),

                      const Text(
                        "OTP Verified Successfully",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        "Click below to receive a Firebase password reset link.",
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 25),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: isLoading
                              ? null
                              : () async {
                            await resetPassword();
                          },
                          child: isLoading
                              ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                              : const Text(
                            "Send Reset Link",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Remember your password? ",
                    style: TextStyle(color: Colors.grey),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      "Login",
                      style: TextStyle(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}