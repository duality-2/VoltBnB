const express = require("express");
const crypto = require("crypto");
const admin = require("firebase-admin");
const {sendNotification} = require("../services/fcm");

const router = express.Router();

// Razorpay webhook endpoint
router.post("/razorpay-webhook", async (req, res) => {
  try {
    const signature = req.headers["x-razorpay-signature"];
    const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET || "YOUR_WEBHOOK_SECRET";

    const expectedSignature = crypto
        .createHmac("sha256", webhookSecret)
        .update(JSON.stringify(req.body))
        .digest("hex");

    if (expectedSignature === signature) {
      const event = req.body.event;

      if (event === "payment.captured") {
        const paymentData = req.body.payload.payment.entity;
        const paymentId = paymentData.id;
        const bookingId = paymentData.notes?.bookingId;

        if (bookingId) {
          const db = admin.firestore();
          await db.collection("bookings").doc(bookingId).update({
            status: "confirmed",
            paymentId: paymentId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Fetch booking to notify host and renter
          const bookingDoc = await db.collection("bookings").doc(bookingId).get();
          if (bookingDoc.exists) {
            const data = bookingDoc.data();
            await sendNotification(data.renterUid, "Booking Confirmed!", "Your payment was successful and your EV charger is reserved.");
            await sendNotification(data.hostUid, "New Booking!", "You have a new confirmed booking. Payment received.");
          }

          console.log(`Booking ${bookingId} confirmed via Webhook.`);
        }
      }

      res.status(200).json({status: "ok"});
    } else {
      console.error("Invalid Razorpay Signature");
      res.status(400).json({error: "Invalid signature"});
    }
  } catch (error) {
    console.error("Webhook Error:", error);
    res.status(500).json({error: "Internal Server Error"});
  }
});

module.exports = router;
