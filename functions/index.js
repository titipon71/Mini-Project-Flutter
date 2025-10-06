/* eslint-disable */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.setUserRole = functions.https.onCall(async (data, context) => {
  // ไม่ใช้ ?. เพื่อเลี่ยง ESLint parse error
  if (!context.auth || !context.auth.token || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError("permission-denied", "Admins only.");
  }

  const uid = data && data.uid;
  const role = data && data.role;
  if (!uid || !role) {
    throw new functions.https.HttpsError("invalid-argument", "uid & role required");
  }

  let claims = {};
  if (role === "vip") claims = { vip: true };
  else if (role === "admin") claims = { admin: true, vip: true };
  else claims = {}; // role 'user' = ล้าง claims

  await admin.auth().setCustomUserClaims(uid, claims);
  return { ok: true, uid, claims };
});
