import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityHistoryScreen extends StatelessWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: FutureBuilder<String?>(
          future: _getCaregiverId(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              );
            }

            final caregiverId = snap.data;
            if (caregiverId == null) {
              return const Center(
                child: Text("No caregiver account found",
                    style: TextStyle(color: Colors.white)),
              );
            }

            return _buildHistory(context, caregiverId);
          },
        ),
      ),
    );
  }

  Future<String?> _getCaregiverId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("caregiverId");
  }

  // ========================= MAIN FIRESTORE STREAM =========================
  Widget _buildHistory(BuildContext context, String caregiverId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("alerts")
          .where("caregiverId", isEqualTo: caregiverId)
          .orderBy("timestamp", descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          );
        }

        final docs = snap.data!.docs;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER -----------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white70, size: 22),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "Activity &\nHistory",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),

                  if (docs.isNotEmpty)
                    GestureDetector(
                      onTap: () => _showClearAllDialog(context, caregiverId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF33B5FF)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 16, color: Color(0xFF33B5FF)),
                            SizedBox(width: 6),
                            Text(
                              "Clear All",
                              style: TextStyle(
                                color: Color(0xFF33B5FF),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          ],
                        ),
                      ),
                    )
                ],
              ),

              const SizedBox(height: 6),
              const Text(
                "Timeline of events and alerts",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),

              const SizedBox(height: 22),

              if (docs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Text(
                      "No activity yet.",
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ),
                ),

              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final timestamp = _formatTimestamp(data["timestamp"]);
                final location = data["location"] ?? "Unknown location";

                final type = data["fallType"] ?? "Fall Detected";

                return Column(
                  children: [
                    _activityCard(
                      context,
                      docId: doc.id,
                      type: type,
                      status: "Fall Alert",
                      time: timestamp,
                      address: location,
                      lat: data["lat"],
                      lng: data["lng"],
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  // ========================= TIMESTAMP FORMATTER =========================
  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate();
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  "
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
    return "Unknown time";
  }

  // ========================= ACTIVITY CARD =========================
  Widget _activityCard(
    BuildContext context, {
    required String docId,
    required String type,
    required String status,
    required String time,
    required String address,
    double? lat,
    double? lng,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF162233),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.redAccent, size: 22),
                  const SizedBox(width: 10),
                  Text(type,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              GestureDetector(
                onTap: () => _showDeleteDialog(context, docId),
                child: const Icon(Icons.delete_outline,
                    color: Colors.white54, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(status,
              style: const TextStyle(
                color: Colors.lightBlueAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.access_time,
                  color: Colors.white54, size: 18),
              const SizedBox(width: 6),
              Text(time,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.location_on,
                  color: Colors.white54, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(address,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13)),
              ),
            ],
          ),

          if (lat != null && lng != null) ...[
            const SizedBox(height: 10),
            Text(
              "GPS: $lat, $lng",
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  // ========================= DELETE SINGLE =========================
  void _showDeleteDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF162233),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text("Delete Activity?",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          "This will permanently delete this activity.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection("alerts")
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
            },
            child: const Text("Delete",
                style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  // ========================= CLEAR ALL =========================
  void _showClearAllDialog(BuildContext context, String caregiverId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF162233),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text("Clear All History?",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          "This will delete all activity history.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final snap = await FirebaseFirestore.instance
                  .collection("alerts")
                  .where("caregiverId", isEqualTo: caregiverId)
                  .get();

              for (var doc in snap.docs) {
                await doc.reference.delete();
              }

              Navigator.pop(context);
            },
            child: const Text("Delete All",
                style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
