import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AllSetScreen extends StatelessWidget {
  const AllSetScreen({super.key});

  Future<void> _finishSetup(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    // Mark onboarding as completed so user won't be redirected again
    await prefs.setBool("onboarding_complete", true);

    // Go directly to dashboard, remove history
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        "/dashboard",
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // ====== CHECK ICON ======
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF162233),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF33B5FF).withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 50,
                ),
              ),

              const SizedBox(height: 40),

              // ===== TITLE =====
              const Text(
                "You're All Set ✨",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 12),

              // ===== SUBTEXT =====
              const Text(
                "Senra is now connected and keeping\nwatch.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 50),

              // ===== BUTTON =====
              GestureDetector(
                onTap: () => _finishSetup(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF33B5FF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Center(
                    child: Text(
                      "Go to Dashboard",
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
