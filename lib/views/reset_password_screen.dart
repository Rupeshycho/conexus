
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String oobCode; // code from Firebase email link

  const ResetPasswordScreen({super.key, required this.oobCode});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {

  TextEditingController newPassController  = TextEditingController();
  TextEditingController confPassController = TextEditingController();

  bool isLoading    = false;
  bool hidePass     = true;
  bool hideConfPass = true;
  bool isDone       = false;

  Future<void> updatePassword() async {

    if (newPassController.text.trim().isEmpty ||
        confPassController.text.trim().isEmpty) {
      showSnack("Please fill all fields", Colors.red);
      return;
    }

    if (newPassController.text.trim() != confPassController.text.trim()) {
      showSnack("Passwords do not match", Colors.red);
      return;
    }

    if (newPassController.text.trim().length < 6) {
      showSnack("Password must be at least 6 characters", Colors.red);
      return;
    }

    setState(() => isLoading = true);

    try {

      // ✅ This actually updates the password in Firebase
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: newPassController.text.trim(),
      );

      setState(() => isDone = true);
      showSnack("Password updated successfully!", Colors.green);

    } on FirebaseAuthException catch (e) {
      print("🔴 RESET CODE: ${e.code}");

      String message = "";
      switch (e.code) {
        case 'expired-action-code':
          message = "Reset link has expired. Please request a new one.";
          break;
        case 'invalid-action-code':
          message = "Reset link is invalid. Please request a new one.";
          break;
        case 'weak-password':
          message = "Password is too weak. Use at least 6 characters.";
          break;
        default:
          message = e.message ?? "Something went wrong.";
      }

      showSnack(message, Colors.red);
    }

    setState(() => isLoading = false);
  }

  void showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.deepOrange),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [

              const SizedBox(height: 20),

              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDone ? Icons.check_circle_outline : Icons.lock_reset,
                  size: 50,
                  color: Colors.deepOrange,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                isDone ? "Password Updated!" : "Set New Password",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                isDone
                    ? "Your password has been changed successfully"
                    : "Create a strong new password",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),

              const SizedBox(height: 30),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: isDone

                // ── SUCCESS STATE ──
                    ? Column(
                  children: [
                    const SizedBox(height: 10),
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
                          // Pop all screens and go back to login
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                        child: const Text(
                          "Go to Login",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                )

                // ── FORM STATE ──
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text(
                      "New Password",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: newPassController,
                      obscureText: hidePass,
                      decoration: InputDecoration(
                        hintText: "••••••••",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            hidePass ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => hidePass = !hidePass),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.deepOrange),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "Confirm Password",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: confPassController,
                      obscureText: hideConfPass,
                      decoration: InputDecoration(
                        hintText: "••••••••",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            hideConfPass ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => hideConfPass = !hideConfPass),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.deepOrange),
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
                          await updatePassword();
                        },
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          "Update Password",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}