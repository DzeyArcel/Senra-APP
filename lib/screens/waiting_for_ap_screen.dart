import 'dart:async';
import 'package:flutter/material.dart';

class WaitingForAP extends StatefulWidget {
  const WaitingForAP({super.key});

  @override
  State<WaitingForAP> createState() => _WaitingForAPState();
}

class _WaitingForAPState extends State<WaitingForAP> {

  @override
  void initState() {
    super.initState();

    // Wait longer for device AP
    Timer(const Duration(seconds: 30), () {

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, "/wifi-config");

    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF162233),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF33B5FF).withValues(alpha: 0.12),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [

              SizedBox(
                width: 54,
                height: 54,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: Color(0xFF33B5FF),
                  backgroundColor: Colors.white10,
                ),
              ),

              SizedBox(height: 22),

              Text(
                "Waiting for Senra device",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),

              SizedBox(height: 8),

              Text(
                "The device is switching to setup mode.\nThis usually takes a few seconds.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              SizedBox(height: 16),

              Text(
                "Please keep this screen open.",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}