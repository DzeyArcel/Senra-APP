const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.sendFallAlert = onDocumentCreated(
  "alerts/{alertId}",
  async (event) => {
    const snap = event.data;
    if (!snap || !snap.exists) return;

    const data = snap.data();
    const alertId = event.params.alertId;

    // ✅ Only pending alerts
    if (data.status !== "pending") {
      console.log("⏭ Alert not pending, skipping:", alertId);
      return;
    }

    const deviceId = data.deviceId;
    if (!deviceId) {
      console.log("❌ Missing deviceId in alert:", alertId);
      return;
    }

    // 🔍 FIND CAREGIVER BY PAIRED DEVICE (KEY FIX)
    const caregiversSnap = await getFirestore()
      .collection("caregivers")
      .where("pairedDevice", "==", deviceId)
      .limit(1)
      .get();

    if (caregiversSnap.empty) {
      console.log("❌ Caregiver not found for device:", deviceId);
      return;
    }

    const caregiverDoc = caregiversSnap.docs[0];
    const caregiver = caregiverDoc.data();
    const caregiverId = caregiverDoc.id;

    console.log("✅ Caregiver found:", caregiverId);

    // 🔕 Push disabled
    if (caregiver.pushNotifications !== true) {
      console.log("🔕 Push disabled for caregiver:", caregiverId);
      return;
    }

    if (!caregiver.fcmToken) {
      console.log("❌ No FCM token for caregiver:", caregiverId);
      return;
    }

    const payload = {
  token: caregiver.fcmToken,

  notification: {
    title: "🚨 Senra Emergency",
    body: "A fall was detected. Tap to view details and respond.",
  },

  android: {
    priority: "high",
    notification: {
      channelId: "senra_alerts",
      sound: "default",
      visibility: "public", // shows full text on lock screen
      category: "alarm",    // makes it heads-up & urgent
    },
  },

  data: {
    alertId,
    deviceId,
  },
};


    // 📲 SEND PUSH
    await getMessaging().send(payload);
    console.log("✅ Notification sent:", alertId);

    // ✅ OPTIONAL: Mark delivered + attach caregiverId
    await getFirestore()
      .collection("alerts")
      .doc(alertId)
      .update({
        delivered: true,
        caregiverId,
      });
  }
);
