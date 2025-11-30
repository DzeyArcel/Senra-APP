import 'package:flutter/material.dart';

class ManageDeviceScreen extends StatelessWidget {
  const ManageDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BACK + TITLE
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Manage Device",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                ],
              ),

              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 45),
                child: Text(
                  "Check status and manage your Senra wearable.",
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),

              const SizedBox(height: 20),

              // ---------------- DEVICE INFORMATION CARD ----------------
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
                    // Title Row
                    Row(
                      children: const [
                        Icon(Icons.watch_outlined,
                            color: Color(0xFF33B5FF), size: 22),
                        SizedBox(width: 10),
                        Text(
                          "Device Information",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      "Details about your connected Senra wearable",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),

                    const SizedBox(height: 18),
                    Container(height: 1, color: Colors.white12),
                    const SizedBox(height: 18),

                    // Device Name / ID
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        _InfoColumn(label: "Device Name", value: "Senra-001"),
                        _InfoColumn(label: "Device ID", value: "SN-34567"),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Battery / Last Sync
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        _InfoColumn(label: "Battery Level", value: "85%"),
                        _InfoColumn(label: "Last Sync", value: "2 min ago"),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // ---------------- CONNECTION STATUS ----------------
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
                      children: const [
                        Icon(Icons.wifi, color: Color(0xFF33B5FF), size: 22),
                        SizedBox(width: 10),
                        Text(
                          "Connection Status",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Text(
                      "Manage your device connection",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),

                    const SizedBox(height: 18),
                    Container(height: 1, color: Colors.white12),
                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("Connected",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        Text("Active",
                            style:
                                TextStyle(color: Colors.lightGreenAccent)),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF33B5FF),
                                  width: 1.5,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  "Change Wi-Fi Network",
                                  style: TextStyle(
                                    color: Color(0xFF33B5FF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: GestureDetector(
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.redAccent,
                                  width: 1.5,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  "Unlink Device",
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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

              // ---------------- DEVICE STATUS FOOTER CARD ----------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF162233),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: const [
                    Text(
                      "Device Status",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 18),

                    _InfoColumn(label: "Signal Strength", value: "Strong"),
                    SizedBox(height: 14),
                    _InfoColumn(label: "Firmware Version", value: "v2.1.0"),
                    SizedBox(height: 8),
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
}

// ---------------- REUSABLE LABEL+VALUE COLUMN ----------------
class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;

  const _InfoColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14)),
      ],
    );
  }
}
