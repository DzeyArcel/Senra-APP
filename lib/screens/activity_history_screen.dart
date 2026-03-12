import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityHistoryScreen extends StatelessWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625),
      body: SafeArea(
        child: FutureBuilder<Map<String, String?>>(
          future: _getSession(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF33B5FF),
                ),
              );
            }

            final caregiverId = snap.data?["caregiverId"];
            final deviceId = snap.data?["deviceId"];

            if (caregiverId == null || deviceId == null) {
              return const Center(
                child: Text(
                  "No caregiver or device session found.",
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            return FutureBuilder<bool>(
              future: _locationAllowed(),
              builder: (context, privacySnap) {
                if (!privacySnap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF33B5FF),
                    ),
                  );
                }

                return _historyStream(
                  context,
                  deviceId,
                  privacySnap.data!,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<Map<String, String?>> _getSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString("pairedDevice");

    if (deviceId == null || deviceId.isEmpty) return {};

    return {
      "caregiverId": user.uid,
      "deviceId": deviceId.replaceAll('"', '').trim(),
    };
  }

  Future<bool> _locationAllowed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true;

    final doc = await FirebaseFirestore.instance
        .collection("caregivers")
        .doc(user.uid)
        .get();

    return doc.data()?["locationSharing"] ?? true;
  }

  Widget _historyStream(
    BuildContext context,
    String deviceId,
    bool allowLocation,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("alerts")
          .where("deviceId", isEqualTo: deviceId)
          .orderBy("timestamp", descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF33B5FF),
            ),
          );
        }

        final docs = snap.data!.docs;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, docs.isNotEmpty, deviceId),
              const SizedBox(height: 20),

              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                    child: Text(
                      "No activity yet.",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;

                final rawAddress = data["address"];

                final address = allowLocation
                    ? _formatAddress(rawAddress)
                    : "Location hidden";

                return _activityCard(
                  context,
                  docId: doc.id,
                  type: data["fallType"] ?? "Fall Detected",
                  time: _formatTime(data["timestamp"]),
                  address: address,
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _header(
    BuildContext context,
    bool hasDocs,
    String deviceId,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
          ),
          const SizedBox(width: 6),
          const Text(
            "Activity &\nHistory",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ]),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _activityCard(
    BuildContext context, {
    required String docId,
    required String type,
    required String time,
    required String address,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.redAccent),
                const SizedBox(width: 8),
                Text(
                  type,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]),
              GestureDetector(
                onTap: () => _deleteOne(docId),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.white54,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            time,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            address,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAddress(String? raw) {
    if (raw == null || raw.isEmpty) {
      return "Unknown location";
    }

    String address = raw;

    if (address.contains("Tubog") && !address.contains("Ubay")) {
      address = "Tubog Ubay Bohol 6315";
    }

    return address;
  }

  String _formatTime(dynamic raw) {
    DateTime? dt;
    if (raw is Timestamp) dt = raw.toDate();
    if (raw is String) dt = DateTime.tryParse(raw);
    if (dt == null) return "Unknown time";

    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-"
        "${dt.day.toString().padLeft(2, '0')} "
        "${dt.hour.toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')}";
  }

  void _deleteOne(String docId) async {
    await FirebaseFirestore.instance
        .collection("alerts")
        .doc(docId)
        .delete();
  }

  void _clearAll(BuildContext context, String deviceId) async {
    final snap = await FirebaseFirestore.instance
        .collection("alerts")
        .where("deviceId", isEqualTo: deviceId)
        .get();

    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }
}