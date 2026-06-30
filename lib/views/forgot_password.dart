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

  // ── EmailJS keys ──
  final String serviceId  = "service_trbjk5o";
  final String templateId = "template_koinwec";
  final String publicKey  = "5po448ty6vxdExARW";

  final TextEditingController emailController   = TextEditingController();
  final TextEditingController otpController     = TextEditingController();
  final TextEditingController newPassController = TextEditingController();
  final TextEditingController confPassController= TextEditingController();

  String generatedOtp = "";
  bool otpSent        = false;
  bool otpVerified    = false;
  bool isDone         = false;
  bool isLoading      = false;
  bool hideNew        = true;
  bool hideConf       = true;

  String _strengthLabel = '';
  double _strengthValue = 0;
  Color  _strengthColor = Colors.transparent;

  // ── Generate OTP ──────────────────────────────────────────────────────────
  String generateOtp() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  // ── Send OTP via EmailJS ──────────────────────────────────────────────────
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
        headers: {"Content-Type": "application/json"},
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

  // ── Verify OTP ────────────────────────────────────────────────────────────
  void verifyOtp() {
    if (otpController.text.trim() == generatedOtp) {
      setState(() => otpVerified = true);
      showSnack("OTP Verified!", Colors.green);
    } else {
      showSnack("Wrong OTP. Try again.", Colors.red);
    }
  }

  // ── Password strength ─────────────────────────────────────────────────────
  void checkStrength(String val) {
    int score = 0;
    if (val.length >= 6)  score++;
    if (val.length >= 10) score++;
    if (val.contains(RegExp(r'[A-Z]')) && val.contains(RegExp(r'[a-z]'))) score++;
    if (val.contains(RegExp(r'[0-9]'))) score++;
    if (val.contains(RegExp(r'[^A-Za-z0-9]'))) score++;

    const labels = ['Too short', 'Weak', 'Fair', 'Good', 'Strong'];
    const colors = [
      Color(0xFFE53935),
      Color(0xFFFF5722),
      Color(0xFFFFA726),
      Color(0xFF66BB6A),
      Color(0xFF43A047),
    ];

    setState(() {
      if (val.isEmpty) {
        _strengthLabel = '';
        _strengthValue = 0;
        _strengthColor = Colors.transparent;
      } else {
        final idx = (score - 1).clamp(0, 4);
        _strengthLabel = labels[idx];
        _strengthValue = score / 5;
        _strengthColor = colors[idx];
      }
    });
  }

  // ── Trigger Firebase password reset email (sends the ACTUAL reset link) ───
  Future<void> updatePassword() async {
    final newPass  = newPassController.text.trim();
    final confPass = confPassController.text.trim();

    if (newPass.isEmpty || confPass.isEmpty) {
      showSnack("Please fill all fields", Colors.red);
      return;
    }
    if (newPass.length < 6) {
      showSnack("Password must be at least 6 characters", Colors.red);
      return;
    }
    if (newPass != confPass) {
      showSnack("Passwords do not match", Colors.red);
      return;
    }

    setState(() => isLoading = true);

    try {
      final email = emailController.text.trim().toLowerCase();

      // This is the ONLY Firebase-approved way to reset a password
      // for a user who is logged out. It sends a real reset link
      // containing an oobCode. The user must click that link, which
      // opens ResetPasswordScreen and calls confirmPasswordReset().
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      setState(() => isDone = true);
      showSnack("Reset link sent! Check your email.", Colors.green);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        showSnack("No account found with this email.", Colors.red);
      } else {
        showSnack(e.message ?? "Something went wrong.", Colors.red);
      }
    }

    setState(() => isLoading = false);
  }

  void showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.deepOrange),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),

            // ── Icon ──
            Container(
              height: 90,
              width: 90,
              decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDone
                    ? Icons.mark_email_read_outlined
                    : Icons.lock_reset,
                size: 46,
                color: isDone ? Colors.green : Colors.deepOrange,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              isDone
                  ? "Check Your Email"
                  : otpVerified
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
              isDone
                  ? "We sent a reset link to your email.\nClick it to finish setting your new password."
                  : otpVerified
                  ? "Create a strong new password"
                  : otpSent
                  ? "We sent a 6-digit code to your email"
                  : "Enter your email to receive OTP code",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),

            const SizedBox(height: 30),

            // ── Card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── STEP 1: Email ─────────────────────────────────────────
                  if (!otpSent && !isDone) ...[
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
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.email_outlined),
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
                        onPressed: isLoading ? null : sendOtp,
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
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

                  // ── STEP 2: OTP ───────────────────────────────────────────
                  if (otpSent && !otpVerified && !isDone) ...[
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
                          borderSide: const BorderSide(color: Colors.deepOrange),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: sendOtp,
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
                        onPressed: verifyOtp,
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

                  // ── STEP 3: New Password ──────────────────────────────────
                  if (otpVerified && !isDone) ...[

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
                      obscureText: hideNew,
                      onChanged: checkStrength,
                      decoration: InputDecoration(
                        hintText: "••••••••",
                        hintStyle: TextStyle(
                          color: Colors.grey.shade300,
                          letterSpacing: 2,
                        ),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            hideNew ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => hideNew = !hideNew),
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

                    // Strength bar
                    if (newPassController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _strengthValue,
                          minHeight: 4,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _strengthLabel,
                        style: TextStyle(fontSize: 12, color: _strengthColor),
                      ),
                    ],

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
                      obscureText: hideConf,
                      decoration: InputDecoration(
                        hintText: "••••••••",
                        hintStyle: TextStyle(
                          color: Colors.grey.shade300,
                          letterSpacing: 2,
                        ),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            hideConf ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => hideConf = !hideConf),
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

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          disabledBackgroundColor:
                          Colors.deepOrange.withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: isLoading ? null : updatePassword,
                        child: isLoading
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
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

                  // ── STEP 4: Success ───────────────────────────────────────
                  if (isDone) ...[
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
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Back to Login",
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

            if (!isDone)
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
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    otpController.dispose();
    newPassController.dispose();
    confPassController.dispose();
    super.dispose();
  }
}