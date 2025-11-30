import 'package:flutter/material.dart';

class DeviceConnectedScreen extends StatelessWidget {
  const DeviceConnectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625), // Exact dark navy
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [

                // ===== BACK + TITLE =====
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "Device Pairing",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 30),

                // ===== BIG CHECK ICON =====
                Container(
                  width: 125,
                  height: 125,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF33B5FF),
                      width: 4,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check,
                      size: 60,
                      color: Color(0xFF33B5FF),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ===== TITLE =====
                const Text(
                  "Connected Successfully!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 10),

                // ===== SUB TEXT =====
                const Text(
                  "Your Senra wearable is now connected and\nmonitoring.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 35),

                // ===== ICON FLOW (Device → Phone) =====
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock_outline,
                        color: Color(0xFF33B5FF), size: 42),
                    SizedBox(width: 20),
                    Icon(Icons.arrow_forward,
                        color: Colors.white38, size: 26),
                    SizedBox(width: 20),
                    Icon(Icons.smartphone,
                        color: Color(0xFF33B5FF), size: 42),
                  ],
                ),

                const SizedBox(height: 35),

                // ===== INFO CARD =====
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162233),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    "The device will now send fall alerts and location\nupdates to this app automatically.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ===== DEVICE STATUS CARD =====
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162233),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B2A3A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFF33B5FF),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            "134",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            "Connected & Active",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 35),

                // ===== CONTINUE SETUP BUTTON =====
           GestureDetector(
 onTap: () {
  Navigator.pushNamed(context, '/connecting-senra');
},

  child: Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF33B5FF),
      borderRadius: BorderRadius.circular(30),
    ),
    child: const Center(
      child: Text(
        "Continue Setup",
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
  ),
),


                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
