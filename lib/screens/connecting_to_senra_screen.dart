import 'package:flutter/material.dart';

class ConnectingToSenraScreen extends StatefulWidget {
  const ConnectingToSenraScreen({super.key});

  @override
  State<ConnectingToSenraScreen> createState() => _ConnectingToSenraScreenState();
}

class _ConnectingToSenraScreenState extends State<ConnectingToSenraScreen> {
  @override
  void initState() {
    super.initState();

    // After 2 seconds → go to Wi-Fi Config Screen
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushNamed(context, "/wifi-config");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // BLUE LOADING SPINNER (same as Figma)
              const SizedBox(
                width: 46,
                height: 46,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: Color(0xFF33B5FF),
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                "Connecting to Senra...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                "Your phone will now temporarily connect\n"
                "to Senra's Wi-Fi. No internet needed yet.\n"
                "Please wait...",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
