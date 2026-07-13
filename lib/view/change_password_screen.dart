import 'package:flutter/material.dart';
import 'package:conexus/services/settings_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final SettingsService? settingsService;

  const ChangePasswordScreen({super.key, this.settingsService});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  late final SettingsService _settingsService;

  final TextEditingController currentPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool hideCurrent = true;
  bool hideNew = true;
  bool hideConfirm = true;
  bool isSaving = false;
  String? statusMessage;

  static const Color orange = Color(0xFFB5651D);

  @override
  void initState() {
    super.initState();
    _settingsService = widget.settingsService ?? SettingsService();
  }

  Future<void> _submit() async {
    final current = currentPasswordController.text.trim();
    final newPass = newPasswordController.text.trim();
    final confirm = confirmPasswordController.text.trim();

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      setState(() => statusMessage = "All fields are required");
      return;
    }

    if (newPass.length < 6) {
      setState(() => statusMessage = "New password must be at least 6 characters");
      return;
    }

    if (newPass != confirm) {
      setState(() => statusMessage = "New passwords do not match");
      return;
    }

    if (newPass == current) {
      setState(() => statusMessage = "New password must be different from current password");
      return;
    }

    setState(() {
      isSaving = true;
      statusMessage = null;
    });

    final error = await _settingsService.changePassword(
      currentPassword: current,
      newPassword: newPass,
    );

    if (!mounted) return;

    if (error == null) {
      setState(() {
        isSaving = false;
        statusMessage = "Password changed successfully";
      });
      currentPasswordController.clear();
      newPasswordController.clear();
      confirmPasswordController.clear();
    } else {
      setState(() {
        isSaving = false;
        statusMessage = error;
      });
    }
  }

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool hide,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: hide,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: IconButton(
              icon: Icon(hide ? Icons.visibility_off : Icons.visibility),
              onPressed: onToggle,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Change Password"),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPasswordField(
              label: "Current Password",
              controller: currentPasswordController,
              hide: hideCurrent,
              onToggle: () => setState(() => hideCurrent = !hideCurrent),
            ),
            _buildPasswordField(
              label: "New Password",
              controller: newPasswordController,
              hide: hideNew,
              onToggle: () => setState(() => hideNew = !hideNew),
            ),
            _buildPasswordField(
              label: "Confirm New Password",
              controller: confirmPasswordController,
              hide: hideConfirm,
              onToggle: () => setState(() => hideConfirm = !hideConfirm),
            ),

            if (statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  statusMessage!,
                  style: TextStyle(
                    color: statusMessage == "Password changed successfully"
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  "Update Password",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}