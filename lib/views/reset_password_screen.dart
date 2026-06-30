import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart'; // adjust import to your actual login screen file
class ResetPasswordScreen extends StatefulWidget {
  final String oobCode;

  const ResetPasswordScreen({super.key, required this.oobCode});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _newPassCtrl  = TextEditingController();
  final TextEditingController _confPassCtrl = TextEditingController();

  bool _isLoading    = false;
  bool _hideNew      = true;
  bool _hideConf     = true;
  bool _isDone       = false;
  bool _isExpired    = false;

  String _strengthLabel = '';
  double _strengthValue = 0;
  Color  _strengthColor = Colors.transparent;

  // ── Password strength ──────────────────────────────────────────────────────
  void _checkStrength(String val) {
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

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _updatePassword() async {
    final newPass  = _newPassCtrl.text.trim();
    final confPass = _confPassCtrl.text.trim();

    if (newPass.isEmpty || confPass.isEmpty) {
      _showSnack('Please fill all fields', Colors.red);
      return;
    }
    if (newPass.length < 6) {
      _showSnack('Password must be at least 6 characters', Colors.red);
      return;
    }
    if (newPass != confPass) {
      _showSnack('Passwords do not match', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: newPass,
      );
      setState(() => _isDone = true);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'expired-action-code' || e.code == 'invalid-action-code') {
        setState(() => _isExpired = true);
      } else if (e.code == 'weak-password') {
        _showSnack('Password is too weak. Use at least 6 characters.', Colors.red);
      } else {
        _showSnack(e.message ?? 'Something went wrong.', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen()),
          (_) => false,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 30),

              // ── Brand ──
              const Text(
                'Conexus',
                style: TextStyle(
                  color: Colors.deepOrange,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),

              const SizedBox(height: 40),

              // ── Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 12),
                  ],
                ),
                child: _isExpired
                    ? _buildExpiredState()
                    : _isDone
                    ? _buildSuccessState()
                    : _buildFormState(),
              ),

              const SizedBox(height: 24),

              // ── Back to login link ──
              if (!_isDone && !_isExpired)
                GestureDetector(
                  onTap: _goToLogin,
                  child: RichText(
                    text: const TextSpan(
                      text: 'Back to ',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                      children: [
                        TextSpan(
                          text: 'Login',
                          style: TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.bold,
                          ),
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

  // ── Form state ─────────────────────────────────────────────────────────────
  Widget _buildFormState() {
    return Column(
      children: [
        // Icon
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.deepOrange.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_reset, size: 44, color: Colors.deepOrange),
        ),

        const SizedBox(height: 20),

        const Text(
          'Set new password',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 6),

        const Text(
          'Create a strong new password for your account',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),

        const SizedBox(height: 28),

        // ── New password ──
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'New password',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _newPassCtrl,
          obscureText: _hideNew,
          onChanged: _checkStrength,
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 2),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_hideNew ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _hideNew = !_hideNew),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.deepOrange),
            ),
          ),
        ),

        // ── Strength bar ──
        if (_newPassCtrl.text.isNotEmpty) ...[
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
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _strengthLabel,
              style: TextStyle(fontSize: 12, color: _strengthColor),
            ),
          ),
        ],

        const SizedBox(height: 18),

        // ── Confirm password ──
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Confirm password',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confPassCtrl,
          obscureText: _hideConf,
          decoration: InputDecoration(
            hintText: '••••••••',
            hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 2),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_hideConf ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _hideConf = !_hideConf),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.deepOrange),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // ── Submit button ──
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              disabledBackgroundColor: Colors.deepOrange.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: _isLoading ? null : _updatePassword,
            child: _isLoading
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
                : const Text(
              'Update password',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Success state ──────────────────────────────────────────────────────────
  Widget _buildSuccessState() {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline, size: 44, color: Colors.green),
        ),

        const SizedBox(height: 20),

        const Text(
          'Password updated!',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 6),

        const Text(
          'Your password has been changed successfully.\nYou can now log in to Conexus.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),

        const SizedBox(height: 30),

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
            onPressed: _goToLogin,
            child: const Text(
              'Go to login',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Expired / invalid link state ───────────────────────────────────────────
  Widget _buildExpiredState() {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.link_off_rounded, size: 44, color: Colors.red),
        ),

        const SizedBox(height: 20),

        const Text(
          'Link expired',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFFC62828),
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'This reset link has expired or has already been used.\nRequest a new one from the app.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),

        const SizedBox(height: 30),

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
            onPressed: _goToLogin,
            child: const Text(
              'Back to login',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confPassCtrl.dispose();
    super.dispose();
  }
}