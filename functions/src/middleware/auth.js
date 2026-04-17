const admin = require("firebase-admin");

/**
 * Express middleware to verify Firebase Auth ID Token.
 * Required header: Authorization: Bearer <token>
 */
const verifyToken = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({error: "Unauthorized: Missing Bearer Token"});
  }

  const idToken = authHeader.split("Bearer ")[1];

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    req.user = decodedToken;
    next();
  } catch (error) {
    console.error("Token verification failed:", error);
    return res.status(403).json({error: "Unauthorized: Invalid Token"});
  }
};

module.exports = {verifyToken};
