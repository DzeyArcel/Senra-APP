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
          future: _getPairedDeviceId(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.blueAccent),
              );
            }

            final deviceId = snap.data;

            if (deviceId == null) {
              return const Center(
                child: Text(
                  "No linked device found.",
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            return _buildHistory(context, deviceId);
          },
        ),
      ),
    );
  }

  // ================================
  // READ deviceId from SharedPrefs
  // ================================
  Future<String?> _getPairedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("pairedDevice");
  }

  // ================================
  // FIRESTORE STREAM
  // ================================
  Widget _buildHistory(BuildContext context, String deviceId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("alerts")
          .where("deviceId", isEqualTo: deviceId)
          .orderBy("timestamp", descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          );
        }

        final docs = snap.data?.docs ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, docs.isNotEmpty, deviceId),
              const SizedBox(height: 20),

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
                return _activityCard(
                  context,
                  docId: doc.id,
                  type: data["fallType"] ?? "Fall Detected",
                  time: _formatTimestamp(data["timestamp"]),
                  address: data["location"] ?? "Unknown location",
                  lat: (data["lat"] as num?)?.toDouble(),
                  lng: (data["lng"] as num?)?.toDouble(),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // =======================================
  // TIMESTAMP FIX → STRING or TIMESTAMP OK
  // =======================================
  String _formatTimestamp(dynamic value) {
    DateTime? dt;

    if (value is Timestamp) dt = value.toDate();
    if (value is String) dt = DateTime.tryParse(value);

    if (dt == null) return "Unknown time";

    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');

    return "$y-$m-$d  $hh:$mm";
  }

  // =======================================
  // HEADER
  // =======================================
  Widget _header(BuildContext context, bool hasDocs, String deviceId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon:
                  const Icon(Icons.arrow_back, color: Colors.white70, size: 22),
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
        if (hasDocs)
          GestureDetector(
            onTap: () => _clearAll(context, deviceId),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          ),
      ],
    );
  }

  // =======================================
  // ACTIVITY CARD
  // =======================================
  Widget _activityCard(
    BuildContext context, {
    required String docId,
    required String type,
    required String time,
    required String address,
    double? lat,
    double? lng,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                onTap: () => _deleteOne(context, docId),
                child: const Icon(Icons.delete_outline,
                    color: Colors.white54, size: 20),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.access_time,
                  color: Colors.white54, size: 18),
              const SizedBox(width: 6),
              Text(time,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13)),
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
            const SizedBox(height: 8),
            Text("GPS: $lat, $lng",
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12)),
          ]
        ],
      ),
    );
  }

  // =======================================
  // DELETE SINGLE
  // =======================================
  void _deleteOne(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF162233),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Activity?",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          "This will permanently delete this record.",
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
            child: const Text("Cancel",
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  // =======================================
  // CLEAR ALL
  // =======================================
  void _clearAll(BuildContext context, String deviceId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF162233),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Clear All History?",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text(
          "This will delete all activity for this device.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final snap = await FirebaseFirestore.instance
                  .collection("alerts")
                  .where("deviceId", isEqualTo: deviceId)
                  .get();

              for (final doc in snap.docs) {
                doc.reference.delete();
              }
              Navigator.pop(context);
            },
            child: const Text("Delete All",
                style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
