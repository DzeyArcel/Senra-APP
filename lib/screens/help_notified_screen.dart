import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HelpNotifiedScreen extends StatelessWidget {
  const HelpNotifiedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // SAFE ARGUMENTS
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final String location = args?["location"] ?? "Unknown";
    final String sentTime = args?["sentTime"] ?? "Just now";
    final List<Map<String, String>> contacts =
        (args?["contacts"] as List<dynamic>? ?? [])
            .map((e) => Map<String, String>.from(e))
            .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B1424),
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF111C2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.15),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // CHECK ICON
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2563EB).withOpacity(0.15),
                ),
                child: const Icon(
                  LucideIcons.check,
                  color: Color(0xFF4FC3F7),
                  size: 42,
                ),
              ),

              const SizedBox(height: 18),

              // TITLE
              const Text(
                "Help Has Been Notified",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                "Your emergency contacts have been\nnotified and the location has been shared.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 26),

              // SENT TIME
              Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.white54, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    "Sent at: $sentTime",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // LOCATION
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white54, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Location: $location",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // CONTACTS NOTIFIED TITLE
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Contacts Notified:",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // CONTACT LIST
              ...contacts.map((c) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2942),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone, color: Color(0xFF4FC3F7), size: 18),
                      const SizedBox(width: 14),

                      // NAME + NUMBER
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c['name'] ?? "Unknown",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              c['phone'] ?? "--",
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // SENT LABEL
                      const Text(
                        "✓ Sent",
                        style: TextStyle(
                          color: Color(0xFF4FC3F7),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              const SizedBox(height: 22),

              // RETURN BUTTON
              GestureDetector(
                onTap: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    "/dashboard",
                    (route) => false,
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4FC3F7),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Text(
                      "Return to Dashboard",
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
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
