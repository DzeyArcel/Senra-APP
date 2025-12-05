import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpNotifiedScreen extends StatelessWidget {
  final String location;
  final double? lat;
  final double? lng;
  final String sentTime;
  final List<Map<String, String>> contacts;

  const HelpNotifiedScreen({
    super.key,
    required this.location,
    this.lat,
    this.lng,
    this.sentTime = "Just now",
    this.contacts = const [],
  });

  // -------------------------------------------------------------
  // OPEN GOOGLE MAP
  // -------------------------------------------------------------
  void openMap(double? lat, double? lng) async {
    if (lat == null || lng == null) return;
    final url = "https://www.google.com/maps?q=$lat,$lng";
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: Center(
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white12, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.25),
                blurRadius: 35,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // SUCCESS ICON
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent.withOpacity(0.14),
                ),
                child: const Icon(
                  LucideIcons.checkCircle2,
                  size: 62,
                  color: Colors.greenAccent,
                ),
              ),

              const SizedBox(height: 20),

              // TITLE
              const Text(
                "Help Has Been Notified 💙",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 12),

              // INFO TEXT
              const Text(
                "Your emergency contacts have been alerted.\nLocation was sent successfully.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 20),

              // SENT TIME
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time,
                      size: 16, color: Colors.white60),
                  const SizedBox(width: 6),
                  Text(
                    "Sent at $sentTime",
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // MAP PREVIEW (FREE, NO API NEEDED)
              if (lat != null && lng != null)
                GestureDetector(
                  onTap: () => openMap(lat, lng),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 170,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white12),
                        color: Colors.black,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.network(
                            "https://maps.googleapis.com/maps/api/staticmap"
                            "?center=$lat,$lng"
                            "&zoom=16&size=600x300"
                            "&markers=color:red%7C$lat,$lng"
                            "&key=YOUR_API_KEY",
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) {
                              return const Center(
                                child: Text(
                                  "Map Preview",
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 12),
                                ),
                              );
                            },
                          ),
                          Container(
                            color: Colors.black26,
                            child: const Icon(
                              Icons.open_in_new_rounded,
                              size: 40,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 18),

              // LOCATION TEXT
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on,
                      size: 18, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 26),

              // CONTACT LIST
              if (contacts.isNotEmpty) ...[
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
                const SizedBox(height: 10),

                Column(
                  children: contacts.map((c) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone,
                              size: 16, color: Colors.lightBlueAccent),
                          const SizedBox(width: 12),

                          // CONTACT NAME & NUMBER
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['name'] ?? "Unknown",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  c['phone'] ?? "--",
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // SENT LABEL
                          const Text(
                            "✔ Sent",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.lightBlueAccent,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 30),

              // BACK BUTTON
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/dashboard');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Return to Dashboard",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.3,
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
