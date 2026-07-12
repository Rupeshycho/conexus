import 'package:flutter/material.dart';
import 'package:conexus/services/settings_service.dart';
import 'package:conexus/view/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:conexus/view/personal_info_screen.dart';
import 'package:conexus/services/app_settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();

  bool publicProfile = true;
  bool darkMode = false;
  String selectedLanguage = "English (US)";
  bool isLoading = true;

  static const Color orange = Color(0xFFB5651D);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final profile = await _settingsService.getPublicProfile();
    final dark = await _settingsService.getDarkMode();
    final lang = await _settingsService.getLanguage();
    if (!mounted) return;
    setState(() {
      publicProfile = profile;
      darkMode = dark;
      selectedLanguage = lang;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("ACCOUNT DETAILS"),
              _card(context, [
                _settingTile(
                  icon: Icons.person_outline,
                  title: "Personal Info",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PersonalInfoScreen()),
                    );
                  },
                ),
                _divider(),
                _settingTile(
                  icon: Icons.lock_outline,
                  title: "Change Password",
                  onTap: () {
                    // TODO: Navigate to Change Password screen
                  },
                ),
                _divider(),
                _settingTile(
                  icon: Icons.visibility_outlined,
                  title: "Public Profile",
                  subtitle: "Allow others to see your feed",
                  trailing: Switch(
                    value: publicProfile,
                    activeColor: Colors.white,
                    activeTrackColor: orange,
                    onChanged: (val) async {
                      setState(() => publicProfile = val);
                      await _settingsService.setPublicProfile(val);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              _sectionTitle("PRIVACY & CONNECTIONS"),
              _card(context, [
                _settingTile(
                  icon: Icons.block,
                  title: "Blocked Users",
                  onTap: () {
                    // TODO: Navigate to Blocked Users screen
                  },
                ),
                _divider(),
                _settingTile(
                  icon: Icons.dark_mode_outlined,
                  title: "Dark Mode",
                  trailing: Switch(
                    value: darkMode,
                    activeColor: Colors.white,
                    activeTrackColor: orange,
                    onChanged: (val) async {
                      setState(() => darkMode = val);
                      await context.read<AppSettingsProvider>().setDarkMode(val);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              _sectionTitle("GENERAL"),
              _card(context, [
                _settingTile(
                  icon: Icons.language,
                  title: "Language",
                  subtitle: selectedLanguage,
                  trailing: const Icon(Icons.keyboard_arrow_down, color: orange),
                  onTap: () => _showLanguagePicker(context),
                ),
                _divider(),
                _settingTile(
                  icon: Icons.info_outline,
                  title: "About Us",
                  onTap: () {
                    // TODO: Navigate to About Us screen
                  },
                ),
              ]),
              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextButton.icon(
                  onPressed: () async {
                    await _settingsService.logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                            (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text(
                    "Logout",
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: Text(
                  "Version 2.4.1 (Build 890)",
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(
      title,
      style: TextStyle(
        color: Colors.grey[600],
        fontWeight: FontWeight.bold,
        fontSize: 12,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _card(BuildContext context, List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(children: children),
  );

  Widget _divider() => const Divider(height: 1, indent: 56, endIndent: 16);

  Widget _settingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: orange),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final languages = ["English (US)", "Hindi", "Spanish", "French"];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages
                .map((lang) => ListTile(
              title: Text(lang),
              trailing: lang == selectedLanguage
                  ? const Icon(Icons.check, color: orange)
                  : null,
              onTap: () {
                setState(() => selectedLanguage = lang);
                context.read<AppSettingsProvider>().setLanguage(lang);
                Navigator.pop(context);
              },
            ))
                .toList(),
          ),
        );
      },
    );
  }
}