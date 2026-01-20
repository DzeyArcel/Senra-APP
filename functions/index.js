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

    if (data.status !== "pending") {
      console.log("⏭ Alert not pending, skipping");
      return;
    }

    const caregiverId = data.caregiverId;
    if (!caregiverId) {
      console.log("❌ Missing caregiverId");
      return;
    }

    const caregiverSnap = await getFirestore()
      .collection("caregivers")
      .doc(caregiverId)
      .get();

    if (!caregiverSnap.exists) {
      console.log("❌ Caregiver not found");
      return;
    }

    const caregiver = caregiverSnap.data();

    if (caregiver.pushNotifications !== true) {
      console.log("🔕 Push disabled");
      return;
    }

    if (!caregiver.fcmToken) {
      console.log("❌ No FCM token");
      return;
    }

    const payload = {
      token: caregiver.fcmToken,
      notification: {
        title: "🚨 SENRA EMERGENCY",
        body: data.fallType || "Fall detected",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "senra_alerts",
          sound: "default",
        },
      },
      data: {
        alertId,
        deviceId: data.deviceId || "",
      },
    };

    await getMessaging().send(payload);
    console.log("✅ Notification sent:", alertId);
  }
);
