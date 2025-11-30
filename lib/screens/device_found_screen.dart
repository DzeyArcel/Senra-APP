import 'package:flutter/material.dart';

class DeviceFoundScreen extends StatefulWidget {
  const DeviceFoundScreen({super.key});

  @override
  State<DeviceFoundScreen> createState() => _DeviceFoundScreenState();
}

class _DeviceFoundScreenState extends State<DeviceFoundScreen> {

  @override
  void initState() {
    super.initState();

    // Auto navigate after delay (simulate pairing)
    Future.delayed(const Duration(seconds: 2), () {
  Navigator.pushNamed(context, '/device-connected');
});

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back button + Title
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      "Device Pairing",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 20),

                const Text(
                  "Device Found",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 6),
                const Text(
                  "Ready to connect to 134",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 25),

                // Device Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162233),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Device Icon
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B2A3A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.lock_outline,
                                color: Color(0xFF33B5FF), size: 26),
                          ),
                          const SizedBox(width: 15),

                          // Device ID
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "134",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18),
                              ),
                              SizedBox(height: 3),
                              Text(
                                "Device ID: 134",
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      Container(height: 1, color: Colors.white12),
                      const SizedBox(height: 20),

                      // Stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("🔋 Battery Level",
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                              SizedBox(height: 4),
                              Text("80%",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("📶 Signal Strength",
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                              SizedBox(height: 4),
                              Text("Medium",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),
                      const Text(
                        "Last Sync: Just now",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Device → Phone icons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock_outline,
                        color: Color(0xFF33B5FF), size: 42),
                    SizedBox(width: 16),
                    Icon(Icons.arrow_forward,
                        color: Colors.white38, size: 26),
                    SizedBox(width: 16),
                    Icon(Icons.smartphone,
                        color: Color(0xFF33B5FF), size: 42),
                  ],
                ),

                const SizedBox(height: 40),

                // Connecting text + progress
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Connecting...",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),

                const SizedBox(height: 8),

                // Progress Bar
                Column(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 200,
                            decoration: BoxDecoration(
                              color: const Color(0xFF33B5FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "60%",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
