import 'package:flutter/material.dart';
import 'manage_device_screen.dart'; // <-- You already have this

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool locationSharing = true;
  bool pushNotifications = true;
  bool emergencyVibration = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------- TOP BAR ----------------
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white70, size: 22),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Settings",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),
              const Text(
                "Configure your Senra experience",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),

              const SizedBox(height: 24),

              // =====================================================
              // 1) DEVICE CARD
              // =====================================================
              _settingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Device", Icons.watch_outlined),
                    const SizedBox(height: 18),

                    // Manage Device Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Manage Device",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            SizedBox(height: 3),
                            Text("View device status and\nmanage your Senra wearable",
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ],
                        ),

                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ManageDeviceScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF33B5FF)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              "Manage Device",
                              style: TextStyle(
                                  color: Color(0xFF33B5FF),
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // =====================================================
              // 2) PRIVACY & LOCATION CARD
              // =====================================================
              _settingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(
                        "Privacy & Location", Icons.location_on_rounded),
                    const SizedBox(height: 18),

                    _toggleRow(
                      title: "Location Sharing",
                      subtitle: "Share location during emergency alerts",
                      value: locationSharing,
                      onChanged: (v) => setState(() => locationSharing = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // =====================================================
              // 3) NOTIFICATIONS CARD
              // =====================================================
              _settingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle("Notifications", Icons.notifications_active),
                    const SizedBox(height: 18),

                    _toggleRow(
                      title: "Push Notifications",
                      subtitle: "Receive notifications on this device",
                      value: pushNotifications,
                      onChanged: (v) =>
                          setState(() => pushNotifications = v),
                    ),

                    const SizedBox(height: 16),

                    _toggleRow(
                      title: "Emergency Vibration",
                      subtitle: "Vibrate during emergency alerts",
                      value: emergencyVibration,
                      onChanged: (v) =>
                          setState(() => emergencyVibration = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // =====================================================
              // 4) ACCOUNT CARD
              // =====================================================
              _settingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _accountHeader(),
                    const SizedBox(height: 14),

                    const Text("Name",
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text("fda",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    const SizedBox(height: 12),

                    const Text("Phone Number",
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text("34",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    const SizedBox(height: 16),

                    Container(height: 1, color: Colors.white12),
                    const SizedBox(height: 14),

                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF223247),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text("Sign Out",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // =====================================================
              // 5) APP INFO CARD
              // =====================================================
              _settingsCard(
                child: Column(
                  children: const [
                    Text(
                      "Senra App",
                      style: TextStyle(
                          color: Color(0xFF33B5FF),
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 6),
                    Text("Version 1.0.0",
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    SizedBox(height: 8),
                    Text("Your Safety, Always With You",
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------- UI HELPERS ------------------------------

  Widget _settingsCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF162233),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF33B5FF), size: 22),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF33B5FF),
        ),
      ],
    );
  }

  Widget _accountHeader() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Row(
        children: [
          Icon(Icons.person_outline, color: Color(0xFF33B5FF), size: 22),
          SizedBox(width: 10),
          Text(
            "Account",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),

      // ---- EDIT BUTTON NOW WORKS ----
      GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, "/edit-account");
        },
        child: const Text(
          "Edit",
          style: TextStyle(
            color: Color(0xFF33B5FF),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    ],
  );
}

}
