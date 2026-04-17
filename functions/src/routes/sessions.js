const express = require("express");
const admin = require("firebase-admin");
const { sendNotification } = require("../services/fcm");
const { verifyToken } = require("../middleware/auth");

const router = express.Router();

/**
 * End a charging session.
 * Triggered by Host or System.
 */
router.post("/end", verifyToken, async (req, res) => {
  const { bookingId, kwhDelivered, elapsedSeconds } = req.body;
  if (!bookingId) return res.status(400).json({ error: "Missing bookingId" });

  try {
    const db = admin.firestore();
    const rtdb = admin.database();
    
    // 1. Update Realtime DB status to 'ended'
    await rtdb.ref(`sessions/${bookingId}`).update({
      status: "ended",
      endedAt: new Date().toISOString(),
      kwhDelivered: kwhDelivered || 0,
      elapsedSeconds: elapsedSeconds || 0,
    });

    // 2. Update Firestore booking document
    const bookingRef = db.collection("bookings").doc(bookingId);
    const bookingDoc = await bookingRef.get();
    if (!bookingDoc.exists) return res.status(404).json({ error: "Booking not found" });
    
    const data = bookingDoc.data();
    
    // Calculate refund if they used significantly less time/kwh than booked
    // (Simplified logic: no refund for now, just mark completed)
    const refundAmount = 0.0; 

    await bookingRef.update({
      status: "completed",
      kwhDelivered: kwhDelivered || 0,
      actualDurationSeconds: elapsedSeconds || 0,
      refundAmount: refundAmount,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 3. Notify Renter & Host
    await sendNotification(data.renterUid, "Session Ended", `Your charging session is complete. You used ${kwhDelivered || 0} kWh.`);
    await sendNotification(data.hostUid, "Session Ended", `The renter's charging session has ended successfully.`);

    res.status(200).json({ status: "success", bookingId, refundAmount });
  } catch (error) {
    console.error("Error ending session:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
});

module.exports = router;
