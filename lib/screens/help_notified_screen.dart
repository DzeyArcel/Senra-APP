import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HelpNotifiedScreen extends StatelessWidget {
  const HelpNotifiedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};

    final String location =
        args["location"]?.toString() ?? "Location unavailable";

    final String address =
        args["address"]?.toString() ?? "Address unavailable";

    final String sentTime =
        args["sentTime"]?.toString() ?? "Just now";

    final List<Map<String, String>> contacts =
        (args["contacts"] as List<dynamic>? ?? [])
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
            children: [
              // ✔ SUCCESS ICON
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

              const Text(
                "Emergency Alert Sent",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Your alert has been successfully dispatched to registered caregivers.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 26),

              _infoRow(Icons.access_time, "Dispatched at", sentTime),
              const SizedBox(height: 14),
              _infoRow(Icons.location_on, "Location", location),
              const SizedBox(height: 10),
              _infoRow(Icons.map_outlined, "Address", address, subtle: true),

              const SizedBox(height: 28),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Notified Contacts",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              if (contacts.isEmpty)
                const Text(
                  "No emergency contacts available.",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                )
              else
                ...contacts.map((c) => _contactTile(c)),

              const SizedBox(height: 18),

              const Text(
                "Delivery time may vary depending on network conditions.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),

              const SizedBox(height: 22),

              // RETURN
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      "/dashboard",
                      (_) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4FC3F7),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    "Return to Dashboard",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
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

  // ============================================================
  // UI HELPERS
  // ============================================================

  static Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    bool subtle = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            "$label: $value",
            style: TextStyle(
              color: subtle ? Colors.white54 : Colors.white70,
              fontSize: subtle ? 12 : 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _contactTile(Map<String, String> c) {
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
          const Text(
            "Notified",
            style: TextStyle(
              color: Color(0xFF4FC3F7),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
