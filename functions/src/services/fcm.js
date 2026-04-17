const admin = require("firebase-admin");

/**
 * Sends a push notification to a specific user.
 * @param {string} uid User ID in Firestore
 * @param {string} title Notification Title
 * @param {string} body Notification Body
 */
const sendNotification = async (uid, title, body) => {
  try {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!userDoc.exists) return;

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) {
      console.log(`User ${uid} does not have an FCM token.`);
      return;
    }

    const message = {
      notification: { title, body },
      token: fcmToken,
    };

    await admin.messaging().send(message);

    // Save notification to Firestore for in-app history
    await admin.firestore().collection(`notifications/${uid}/items`).add({
      title,
      body,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });

    console.log(`Notification sent to ${uid}`);
  } catch (error) {
    console.error(`Error sending notification to ${uid}:`, error);
  }
};

module.exports = { sendNotification };
