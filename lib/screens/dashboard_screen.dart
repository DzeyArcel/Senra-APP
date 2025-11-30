import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -------------- TITLE + SETTINGS BUTTON --------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Dashboard",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Your safety monitoring center",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  // SETTINGS ICON BUTTON
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white70),
                    onPressed: () {
  Navigator.pushNamed(context, '/settings');
},

                  )
                ],
              ),

              const SizedBox(height: 20),

              // ---------------- DEVICE STATUS CARD (reduced height) ----------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF162233),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Row + Icon
                    Row(
                      children: const [
                        Icon(Icons.shield_outlined,
                            color: Color(0xFF33B5FF), size: 24),
                        SizedBox(width: 10),
                        Text(
                          "Device Status",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      "The Senra wearable detects falls and sends alerts to this app",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Connected Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          "Device Connected —\nMonitoring Active",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "• Online",
                          style: TextStyle(
                            color: Colors.lightGreenAccent,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Container(height: 1, color: Colors.white12),
                    const SizedBox(height: 12),

                    // Battery + Last Sync
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.battery_full_rounded,
                                color: Colors.lightGreenAccent, size: 16),
                            SizedBox(width: 6),
                            Text(
                              "Battery 85%",
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        Row(
                          children: const [
                            Icon(Icons.wifi, color: Colors.blueAccent, size: 16),
                            SizedBox(width: 6),
                            Text(
                              "Last Sync: 2 min ago",
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Tabs (Wearable & App)
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                              child: Text(
                                "● Wearable",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                              child: Text(
                                "● App",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ---------------- QUICK ACCESS CARD (reduced height) ----------------
            Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: const Color(0xFF162233),
    borderRadius: BorderRadius.circular(14),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "Quick Access",
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 16),

      // ---------- ACTIVITY LOG ----------
      _quickItem(
        icon: Icons.show_chart_rounded,
        title: "Activity Log",
        subtitle: "View history",
        onTap: () {
          Navigator.pushNamed(context, '/activity-history');
        },
      ),

      const SizedBox(height: 10),

      // ---------- EMERGENCY CONTACTS ----------
   _quickItem(
  icon: Icons.people_alt_rounded,
  title: "Emergency Contacts",
  subtitle: "Manage contacts",
  onTap: () {
    Navigator.pushNamed(context, '/emergency-contacts');
  },
),


      const SizedBox(height: 10),

      // ---------- LOCATION TRACKING ----------
      _quickItem(
        icon: Icons.location_on_rounded,
        title: "Location",
        subtitle: "Track location",
        onTap: () {
          Navigator.pushNamed(context, '/location-tracking');
        },
      ),

      const SizedBox(height: 40),
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

  // QUICK ACCESS ITEM ----------------
 Widget _quickItem({
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2A3A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF33B5FF), size: 24),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  
}
