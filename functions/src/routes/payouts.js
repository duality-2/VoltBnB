const express = require("express");
const admin = require("firebase-admin");
const Razorpay = require("razorpay");
const {verifyToken} = require("../middleware/auth");
const {sendNotification} = require("../services/fcm");

const router = express.Router();

/**
 * Initiates a payout for the Host using Razorpay Payout APIs.
 */
router.post("/request", verifyToken, async (req, res) => {
  const uid = req.user.uid;

  try {
    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) return res.status(404).json({ error: "User not found" });
    
    const data = userDoc.data();
    if (data.role !== "host") return res.status(403).json({ error: "Only hosts can request payouts" });

    const balance = data.walletBalance || 0;
    if (balance <= 0) return res.status(400).json({ error: "Insufficient balance for payout" });

    // Call RazorpayX API to transfer funds to Host's Bank Account
    const razorpay = new Razorpay({
      key_id: process.env.RAZORPAY_KEY_ID || "YOUR_RAZORPAY_KEY_ID",
      key_secret: process.env.RAZORPAY_KEY_SECRET || "YOUR_RAZORPAY_KEY_SECRET",
    });

    // In a real scenario, you'd fetch the fundAccountId from the user's profile.
    // We mock the fundAccountId and accountNumber here for the demo.
    const payout = await razorpay.payouts.create({
      account_number: "7878780080316316", // RazorpayX test account
      fund_account_id: "fa_00000000000001", // Placeholder
      amount: balance * 100, // in paise
      currency: "INR",
      mode: "IMPS",
      purpose: "payout",
      queue_if_low_balance: true,
      reference_id: `payout_${uid}_${Date.now()}`,
      narration: "VoltBnB Host Payout"
    });
    
    // Update wallet after initiating payout
    await userRef.update({
      walletBalance: 0,
      lastPayoutDate: admin.firestore.FieldValue.serverTimestamp(),
      lastPayoutId: payout.id
    });

    await sendNotification(uid, "Payout Processed", `A payout of $${balance} has been sent to your bank account.`);

    res.status(200).json({ status: "success", amount: balance, payoutId: payout.id });
  } catch (error) {
    console.error("Error requesting payout:", error);
    // If Razorpay fails (e.g. invalid keys), don't deduct balance, just return error
    res.status(500).json({ error: "Internal Server Error or Invalid Razorpay Keys" });
  }
});

module.exports = router;
