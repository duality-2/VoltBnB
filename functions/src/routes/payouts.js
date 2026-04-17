const express = require("express");
const admin = require("firebase-admin");
const {verifyToken} = require("../middleware/auth");
const {sendNotification} = require("../services/fcm");

const router = express.Router();

/**
 * Initiates a payout for the Host using Razorpay Payout APIs.
 * This is a mocked implementation that updates wallet balance.
 */
router.post("/request", verifyToken, async (req, res) => {
  const uid = req.user.uid;

  try {
    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) return res.status(404).json({error: "User not found"});

    const data = userDoc.data();
    if (data.role !== "host") return res.status(403).json({error: "Only hosts can request payouts"});

    const balance = data.walletBalance || 0;
    if (balance <= 0) return res.status(400).json({error: "Insufficient balance for payout"});

    // TODO: Call RazorpayX API to transfer funds to Host's Bank Account
    // const razorpayPayout = await RazorpayClient.payouts.create({ amount: balance * 100, ... })

    // For now, simulate success and drain wallet
    await userRef.update({
      walletBalance: 0,
      lastPayoutDate: admin.firestore.FieldValue.serverTimestamp(),
    });

    await sendNotification(uid, "Payout Processed", `A payout of $${balance} has been sent to your bank account.`);

    res.status(200).json({status: "success", amount: balance});
  } catch (error) {
    console.error("Error requesting payout:", error);
    res.status(500).json({error: "Internal Server Error"});
  }
});

module.exports = router;
