const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const express = require("express");
const cors = require("cors");

admin.initializeApp();

const app = express();
app.use(cors({origin: true}));
app.use(express.json());

// Import Routes
const paymentRoutes = require("./src/routes/payments");
const sessionRoutes = require("./src/routes/sessions");
const payoutRoutes = require("./src/routes/payouts");

// Register Routes
app.use("/api/payments", paymentRoutes);
app.use("/api/sessions", sessionRoutes);
app.use("/api/payouts", payoutRoutes);

// Main export
exports.api = onRequest({maxInstances: 10}, app);
