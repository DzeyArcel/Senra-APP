import 'package:flutter/material.dart';

class WaitingForAP extends StatelessWidget {
  const WaitingForAP({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: Colors.teal),
            SizedBox(height: 20),
            Text(
              "Waiting for Senra device…",
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 6),
            Text(
              "Please wait while it switches to setup mode",
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
