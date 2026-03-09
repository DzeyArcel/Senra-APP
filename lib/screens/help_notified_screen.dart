import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpNotifiedScreen extends StatelessWidget {
  const HelpNotifiedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final String? location = args?["location"]?.toString();
    final String? address = args?["address"]?.toString();
    final String? sentTime = args?["sentTime"]?.toString();

    final List<Map<String, String>> contacts =
        (args?["contacts"] as List<dynamic>? ?? [])
            .map((e) => Map<String, String>.from(e))
            .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B1424),
      body: Center(
        child: Container(
          width: 390,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFF111C2E),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF33B5FF).withOpacity(0.15),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF33B5FF).withOpacity(0.15),
                ),
                child: const Icon(
                  LucideIcons.checkCircle,
                  color: Color(0xFF33B5FF),
                  size: 44,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                "Emergency Alert Sent",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Your emergency alert has been successfully sent to your registered contacts.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 26),

              if (sentTime != null)
                _infoRow(Icons.access_time, "Sent", sentTime),

              if (location != null) ...[
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => _openMap(context, location),
                  child: _infoRow(Icons.location_on, "Location", location),
                ),
              ],

              if (address != null) ...[
                const SizedBox(height: 10),
                _infoRow(Icons.map_outlined, "Address", address, subtle: true),
              ],

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
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    "No contacts were available at the time of this alert.",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                ...contacts.map(_contactTile),

              const SizedBox(height: 20),

              const Text(
                "Delivery time may vary depending on network conditions.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),

              const SizedBox(height: 22),

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
                    backgroundColor: const Color(0xFF33B5FF),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
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

  static Future<void> _openMap(BuildContext context, String location) async {
    try {
      final parts = location.split(',');

      if (parts.length != 2) {
        _showError(context, "Invalid location format.");
        return;
      }

      final lat = parts[0].trim();
      final lon = parts[1].trim();

      final url = Uri.parse(
          "https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=18/$lat/$lon");

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _showError(context, "Unable to open OpenStreetMap.");
      }
    } catch (e) {
      _showError(context, "Error opening the map.");
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

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
    final status = c['status'] ?? "Sending";

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
          const Icon(Icons.phone, color: Color(0xFF33B5FF), size: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['name'] ?? "Unknown contact",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  c['phone'] ?? "",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _statusIcon(status),
        ],
      ),
    );
  }

  static Widget _statusIcon(String status) {
    switch (status) {
      case "SMS Sent":
        return const Icon(Icons.check_circle, color: Colors.green, size: 18);
      case "Failed":
        return const Icon(Icons.cancel, color: Colors.red, size: 18);
      default:
        return const Icon(Icons.hourglass_top, color: Colors.orange, size: 18);
    }
  }
}