// functions/one-off.js
const admin = require('firebase-admin');
const serviceAccount = require('./flutterapp-3d291-firebase-adminsdk-fbsvc-e2ab3ad24c.json');


admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'flutterapp-3d291',        // แนะนำระบุชัด

  // ถ้าจะใช้ RTDB/Storage ด้วยก็ใส่ได้ (ไม่บังคับสำหรับ set claims)
  // databaseURL: 'https://flutterapp-3d291.firebaseio.com',
  // storageBucket: 'flutterapp-3d291.appspot.com',
});


(async () => {
  try {
    const UID = '1ahJbe1s46N7stvwJOhAmSt6LC62'; // ใส่ UID ของคุณ (ดึงได้จาก Firebase Auth)
    await admin.auth().setCustomUserClaims(UID, { admin: true, vip: true });
    console.log('✅ Set admin+vip for:', UID);
    process.exit(0);
  } catch (e) {
    console.error('❌ Error:', e);
    process.exit(1);
  }
})();
