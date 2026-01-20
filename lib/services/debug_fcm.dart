import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Future<void> debugSaveFcmToken(String caregiverId) async {
  final token = await FirebaseMessaging.instance.getToken();
   debugPrint("🔥 FCM TOKEN: $token");

  if (token == null) return;

  await FirebaseFirestore.instance
      .collection("caregivers")
      .doc(caregiverId)
      .update({
    "fcmToken": token,
    "pushNotifications": true,
  });
}
