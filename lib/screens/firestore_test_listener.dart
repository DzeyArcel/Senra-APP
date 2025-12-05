import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreTestListener extends StatefulWidget {
  const FirestoreTestListener({super.key});

  @override
  State<FirestoreTestListener> createState() => _FirestoreTestListenerState();
}

class _FirestoreTestListenerState extends State<FirestoreTestListener> {
  String logText = "Waiting for wearable alert... ⏳📡";

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
      .collection("alerts")
      .snapshots()
      .listen((snapshot) {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          setState(() {
            logText = "📥 Message received!\n\n${data["message"]}";
          });
          debugPrint("Wearable sent: $data");
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1625), // ✅ UI stays same
      body: Center(
        child: Text(
          logText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: "Inter"
          ),
        ),
      ),
    );
  }
}
