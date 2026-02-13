/*************************************************
 * SENRA CLOUD FUNCTIONS — FINAL
 * - Fall alert notifications (FCM)
 * - Safe alert lifecycle
 * - Reverse geocoding (GPS → address)
 * - No duplicate alerts
 * - No retry loops
 *************************************************/

const { onDocumentCreated, onDocumentUpdated } =
  require("firebase-functions/v2/firestore");

const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } =
  require("firebase-admin/firestore");
const { getMessaging } =
  require("firebase-admin/messaging");

const fetch = require("node-fetch");

initializeApp();

/* =========================================================
   1️⃣ SEND FALL ALERT (WITH ADDRESS + HARDENED)
========================================================= */
exports.sendFallAlert = onDocumentCreated(
  "alerts/{alertId}",
  async (event) => {
    const snap = event.data;
    if (!snap || !snap.exists) return;

    const data = snap.data();
    const alertId = event.params.alertId;
    const db = getFirestore();

    // 🚫 Process only ONCE
    if (data.status !== "pending" || data.delivered === true) {
      console.log("⏭ Alert already processed:", alertId);
      return;
    }

    const deviceId = data.deviceId;
    if (!deviceId) {
      console.error("❌ Missing deviceId:", alertId);
      await db.collection("alerts").doc(alertId).update({
        status: "invalid",
        error: "Missing deviceId",
      });
      return;
    }

    // --------------------------------------------------
    // 🔎 Find caregiver linked to device
    // --------------------------------------------------
    const caregiversSnap = await db
      .collection("caregivers")
      .where("pairedDevice", "==", deviceId)
      .limit(1)
      .get();

    if (caregiversSnap.empty) {
      console.error("❌ No caregiver for device:", deviceId);
      return;
    }

    const caregiverDoc = caregiversSnap.docs[0];
    const caregiver = caregiverDoc.data();
    const caregiverId = caregiverDoc.id;

  if (caregiver.pushNotifications === false) {
  console.log("🔕 Push disabled:", caregiverId);
  return;
}


    if (!caregiver.fcmToken) {
      console.error("❌ Missing FCM token:", caregiverId);
      await db.collection("alerts").doc(alertId).update({
        status: "send_failed",
        error: "Missing FCM token",
      });
      return;
    }

    // --------------------------------------------------
    // 📍 Resolve address (safe fallback)
    // --------------------------------------------------
    let address = "Location unavailable";
    try {
      const deviceSnap = await db.collection("devices").doc(deviceId).get();
      if (deviceSnap.exists && deviceSnap.data()?.address) {
        address = deviceSnap.data().address;
      }
    } catch {
      console.warn("⚠️ Failed to read device address:", deviceId);
    }

    await db.collection("alerts").doc(alertId).update({ address });

    // --------------------------------------------------
    // 🔔 FCM PAYLOAD
    // --------------------------------------------------
  const payload = {
  token: caregiver.fcmToken,

  notification: {
    title: "🚨 Senra Alert",
    body: `Possible fall detected.\n📍 ${address}`,
  },

  android: {
    priority: "high",
    notification: {
      channelId: "senra_alerts_v3",
      // ❌ NO category
      // ❌ NO visibility
      // ❌ NO sound here (channel controls it)
    },
  },

  data: {
    alertId: alertId,
    deviceId: deviceId,
    type: "fall_detected",
    timestamp: Date.now().toString(),
  },
};




    // --------------------------------------------------
    // 🚀 SEND NOTIFICATION
    // --------------------------------------------------
    try {
      await getMessaging().send(payload);

      await db.collection("alerts").doc(alertId).update({
        delivered: true,
        status: "sent",
        caregiverId,
        sentAt: FieldValue.serverTimestamp(),
      });

      console.log("✅ Alert sent:", alertId);
    } catch (err) {
      console.error("❌ FCM send failed:", err.code || err.message);

      // 🧹 Clear invalid token once
      if (
        err.code === "messaging/registration-token-not-registered" ||
        err.message?.includes("Requested entity was not found")
      ) {
        await db
          .collection("caregivers")
          .doc(caregiverId)
          .update({ fcmToken: "" });

        console.warn("🧹 Invalid FCM token cleared:", caregiverId);
      }

      // ❗ Mark alert failed to prevent loops
      await db.collection("alerts").doc(alertId).update({
        status: "send_failed",
        error: err.message,
      });
    }
  }
);

/* =========================================================
   2️⃣ REVERSE GEOCODING (GPS → ADDRESS)
========================================================= */
exports.resolveAddress = onDocumentUpdated(
  "devices/{deviceId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (!after?.lat || !after?.lng) return;
    if (before.lat === after.lat && before.lng === after.lng) return;

    try {
      const url =
        `https://nominatim.openstreetmap.org/reverse` +
        `?format=json&lat=${after.lat}&lon=${after.lng}`;

      const res = await fetch(url, {
        headers: {
          "User-Agent": "Senra/1.0 (capstone project)",
        },
        timeout: 8000,
      });

      if (!res.ok) throw new Error("Geocoding failed");

      const geo = await res.json();
      const address = geo.display_name || "Unknown location";

      await getFirestore()
        .collection("devices")
        .doc(event.params.deviceId)
        .update({ address });

      console.log("📍 Address resolved:", address);
    } catch (err) {
      console.warn("⚠️ Reverse geocoding skipped:", err.message);
    }
  }
);
