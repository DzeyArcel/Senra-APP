import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool locationSharing = true;
  bool pushNotifications = true;
  bool emergencyVibration = true;

  String caregiverName = "";
  String caregiverPhone = "";
  String caregiverId = "";

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // =================================================================
  // 🔥 LOAD SETTINGS FROM FIRESTORE (REALTIME SNAPSHOT)
  // =================================================================
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    caregiverId = prefs.getString("caregiverId") ?? "";

    if (caregiverId.isEmpty) {
      setState(() => loading = false);
      return;
    }

    // REALTIME LISTENER
    FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;

      final data = doc.data()!;
      setState(() {
        caregiverName = data["name"] ?? "";
        caregiverPhone = data["phone"] ?? "";

        locationSharing = data["locationSharing"] ?? true;
        pushNotifications = data["pushNotifications"] ?? true;
        emergencyVibration = data["emergencyVibration"] ?? true;

        loading = false;
      });
    });
  }

  // =================================================================
  // 🔥 SAVE TOGGLES (MERGE)
  // =================================================================
  Future<void> _saveToggle(String key, bool value) async {
    if (caregiverId.isEmpty) return;

    await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(caregiverId)
        .set({key: value}, SetOptions(merge: true));
  }

  // =================================================================
  // 🔥 SIGN OUT — FirebaseAuth + Clear SharedPreferences
  // =================================================================
  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, "/welcome", (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to sign out."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // =================================================================
  // UI
  // =================================================================
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E1625),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF33B5FF))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ===========================================================
              // 🔙 HEADER
              // ===========================================================
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

              // ===========================================================
              // 🔧 DEVICE MANAGEMENT
              // ===========================================================
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title("Device", Icons.watch_outlined),
                    const SizedBox(height: 18),

                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, "/manage-device");
                      },
                      child: Row(
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
                              Text(
                                  "View device status &\nmanage your wearable",
                                  style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: Color(0xFF33B5FF)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              "Open",
                              style: TextStyle(
                                  color: Color(0xFF33B5FF),
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ===========================================================
              // 📍 LOCATION & PRIVACY
              // ===========================================================
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title("Privacy & Location", Icons.location_on_rounded),
                    const SizedBox(height: 18),

                    _toggle(
                      title: "Location Sharing",
                      subtitle:
                          "Automatically send location during emergencies",
                      value: locationSharing,
                      onChanged: (v) {
                        setState(() => locationSharing = v);
                        _saveToggle("locationSharing", v);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ===========================================================
              // 🔔 NOTIFICATIONS
              // ===========================================================
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _title("Notifications", Icons.notifications_active),
                    const SizedBox(height: 18),

                    _toggle(
                      title: "Push Notifications",
                      subtitle: "Receive fall alerts on this device",
                      value: pushNotifications,
                      onChanged: (v) {
                        setState(() => pushNotifications = v);
                        _saveToggle("pushNotifications", v);
                      },
                    ),

                    const SizedBox(height: 16),

                    _toggle(
                      title: "Emergency Vibration",
                      subtitle: "Vibrate when a fall alert is triggered",
                      value: emergencyVibration,
                      onChanged: (v) {
                        setState(() => emergencyVibration = v);
                        _saveToggle("emergencyVibration", v);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ===========================================================
              // 👤 ACCOUNT
              // ===========================================================
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _accountHeader(),

                    const SizedBox(height: 14),

                    _field("Name", caregiverName),
                    const SizedBox(height: 12),
                    _field("Phone Number", caregiverPhone),

                    const SizedBox(height: 16),
                    Container(height: 1, color: Colors.white12),
                    const SizedBox(height: 14),

                    Center(
                      child: GestureDetector(
                        onTap: _signOut,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF223247),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "Sign Out",
                            style: TextStyle(
                                color: Colors.white70, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ===========================================================
              // 📱 APP INFO
              // ===========================================================
              _card(
                Column(
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
                    Text(
                      "Your Safety, Always With You",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // =================================================================
  //  UI HELPERS
  // =================================================================

  Widget _card(Widget child) {
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

  Widget _title(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF33B5FF), size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _toggle({
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

  Widget _field(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700),
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
            Icon(Icons.person_outline,
                color: Color(0xFF33B5FF), size: 22),
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
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, "/edit-account"),
          child: const Text(
            "Edit",
            style: TextStyle(
              color: Color(0xFF33B5FF),
              fontWeight: FontWeight.w600,
              fontSize: 14),
          ),
        ),
      ],
    );
  }
}
