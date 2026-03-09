/*************************************************
 * SENRA CLOUD FUNCTIONS — FINAL (PH TIME FIXED)
 * - Fall alert notifications (FCM)
 * - Uses FALL TIME (not send time)
 * - PH timezone enforced (Asia/Manila)
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
   🕒 FORMAT FALL TIME (PH TIME, SOURCE = ALERT TIMESTAMP)
========================================================= */
function formatFallTime(ts) {
  try {
    if (!ts) return "Unknown time";

    const options = {
      timeZone: "Asia/Manila",   // ✅ FORCE PH TIME
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      hour12: true,
    };

    // Firestore Timestamp
    if (typeof ts.toDate === "function") {
      return ts.toDate().toLocaleString("en-PH", options);
    }

    // ISO / millis fallback
    const d = new Date(ts);
    if (!isNaN(d)) {
      return d.toLocaleString("en-PH", options);
    }

    return "Unknown time";
  } catch {
    return "Unknown time";
  }
}

/* =========================================================
   1️⃣ SEND FALL ALERT (WITH FALL TIME + ADDRESS)
========================================================= */
exports.sendFallAlert = onDocumentCreated(
  "alerts/{alertId}",
  async (event) => {
    const snap = event.data;
    if (!snap || !snap.exists) return;

    const data = snap.data();
    const alertId = event.params.alertId;
    const db = getFirestore();

    // 🚫 Process only once
    if (data.status !== "pending" || data.delivered === true) {
      return;
    }

    const deviceId = data.deviceId;
    if (!deviceId) {
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

    if (caregiversSnap.empty) return;

    const caregiverDoc = caregiversSnap.docs[0];
    const caregiver = caregiverDoc.data();
    const caregiverId = caregiverDoc.id;

    if (caregiver.pushNotifications === false) return;
    if (!caregiver.fcmToken) return;

    // --------------------------------------------------
    // 📍 Resolve address (safe fallback)
    // --------------------------------------------------
    let address = "Location unavailable";
    try {
      const deviceSnap = await db.collection("devices").doc(deviceId).get();
      if (deviceSnap.exists && deviceSnap.data()?.address) {
        address = deviceSnap.data().address;
      }
    } catch {}

    await db.collection("alerts").doc(alertId).update({ address });

    // --------------------------------------------------
    // 🕒 FALL TIME (PH TIME, SOURCE OF TRUTH)
    // --------------------------------------------------
    const fallTime = formatFallTime(data.timestamp);

    // --------------------------------------------------
    // 🔔 FCM PAYLOAD
    // --------------------------------------------------
    const payload = {
  token: caregiver.fcmToken,

  notification: {
    title: "🚨 Senra Alert",
    body:
      `Possible fall detected\n` +
      `🕒 ${fallTime}\n` +
      `📍 ${address}`,
  },

  android: {
    priority: "high",
    notification: {
      channelId: "senra_alerts_v3",
    },
  },

  apns: {
    payload: {
      aps: {
        sound: "default",
        contentAvailable: true
      }
    }
  },

  data: {
    alertId,
    deviceId,
    type: "fall_detected",
    fallTime,
    address,
    screen: "alert"
  }
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
    } catch (err) {
      if (
        err.code === "messaging/registration-token-not-registered" ||
        err.message?.includes("Requested entity was not found")
      ) {
        await db
          .collection("caregivers")
          .doc(caregiverId)
          .update({ fcmToken: "" });
      }

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

      if (!res.ok) throw new Error();

   const geo = await res.json();
const addr = geo.address || {};

const barangay =
  addr.suburb ||
  addr.village ||
  addr.hamlet ||
  addr.neighbourhood ||
  "";

const city =
  addr.city ||
  addr.town ||
  addr.municipality ||
  addr.county ||
  "";

const province =
  addr.state ||
  addr.region ||
  "";

const postcode =
  addr.postcode || "";

const address =
  [barangay, city, province, postcode]
    .filter(v => v && v.length > 0)
    .join(", ");

await getFirestore()
  .collection("devices")
  .doc(event.params.deviceId)
  .update({
    address: address || "Unknown location"
  });
    } catch {}
  }
);