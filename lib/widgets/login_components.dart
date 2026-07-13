import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:conexus/viewmodel/theme_view_model.dart';

// ---------------------------------------------------------

// WIDGETS
// ---------------------------------------------------------

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeViewModel>().isDarkMode;

    return Stack(
      children: [
        // Base Color
        Container(
          color: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF0F4F8),
        ),
        // Floating Sphere 1
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              top: MediaQuery.of(context).size.height * 0.1 + (math.sin(_controller.value * 2 * math.pi) * 50),
              left: MediaQuery.of(context).size.width * 0.1 + (math.cos(_controller.value * 2 * math.pi) * 30),
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.orange.withOpacity(isDark ? 0.4 : 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        // Floating Sphere 2
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              bottom: MediaQuery.of(context).size.height * 0.1 + (math.cos(_controller.value * 2 * math.pi) * 50),
              right: MediaQuery.of(context).size.width * 0.1 + (math.sin(_controller.value * 2 * math.pi) * 30),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.deepOrangeAccent.withOpacity(isDark ? 0.3 : 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        // Glass Blur Filter
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}

class GlassLoginCard extends StatelessWidget {
  final Widget child;
  const GlassLoginCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeViewModel>().isDarkMode;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.4),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class AnimatedLogo extends StatelessWidget {
  const AnimatedLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Colors.orange, Colors.deepOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      child: const Icon(
        Icons.forum_rounded,
        size: 50,
        color: Colors.white,
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scaleXY(end: 1.05, duration: 1500.ms, curve: Curves.easeInOut)
        .boxShadow(
      end: BoxShadow(
        color: Colors.orange.withOpacity(0.6),
        blurRadius: 30,
        spreadRadius: 10,
      ),
      duration: 1500.ms,
    );
  }
}

class ModernTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isDark;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleVisibility;
  final String? Function(String?)? validator;

  const ModernTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.isDark,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleVisibility,
    this.validator,
  });

  @override
  State<ModernTextField> createState() => _ModernTextFieldState();
}

class _ModernTextFieldState extends State<ModernTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _isFocused = hasFocus);
        if (hasFocus) HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isFocused
              ? [BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)]
              : [],
        ),
        child: TextFormField(
          controller: widget.controller,
          obscureText: widget.obscureText,
          validator: widget.validator,
          style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
          cursorColor: Colors.orange,
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(
              color: _isFocused ? Colors.orange : (widget.isDark ? Colors.white54 : Colors.black54),
            ),
            prefixIcon: Icon(
              widget.icon,
              color: _isFocused ? Colors.orange : (widget.isDark ? Colors.white54 : Colors.black54),
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
              icon: Icon(
                widget.obscureText ? Icons.visibility_off : Icons.visibility,
                color: widget.isDark ? Colors.white54 : Colors.black54,
              ),
              onPressed: widget.onToggleVisibility,
            )
                : null,
            filled: true,
            fillColor: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.orange, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class ModernButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final VoidCallback onPressed;

  const ModernButton({super.key, required this.text, required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Colors.orange, Colors.deepOrange],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(isLoading ? 0.2 : 0.4),
              blurRadius: isLoading ? 10 : 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
          )
              : Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class SocialButton extends StatefulWidget {
  final Widget iconWidget;
  final bool isDark;
  final Color color;

  const SocialButton({super.key, required this.iconWidget, required this.isDark, required this.color});

  @override
  State<SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<SocialButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => HapticFeedback.mediumImpact(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isDark ? Colors.white.withOpacity(0.1) : Colors.black12,
              width: 1,
            ),
            boxShadow: _isHovered
                ? [BoxShadow(color: widget.color.withOpacity(0.3), blurRadius: 15, spreadRadius: 2)]
                : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: widget.iconWidget,
        ),
      ),
    );
  }
}


