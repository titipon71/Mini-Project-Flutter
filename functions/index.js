// functions/index.js
/* eslint-disable */
exports.slipokProxy = require("./slipokProxy").slipokProxy;

const { onCall } = require("firebase-functions/v2/https");
const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const cors = require("cors")({ origin: true });
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();
const auth = getAuth();
function daysToMs(d) { return Number(d || 0) * 24 * 60 * 60 * 1000; }

function onlyDigits(s = "") {
  return String(s || "").replace(/\D+/g, "");
}

// ต่ออายุ role (เช่น vip) แบบทบจาก <role>Until ถ้ายังไม่หมดอายุ
async function applyRoleExtend(uid, role, days) {
  const user = await auth.getUser(uid);
  const cur = user.customClaims || {};
  const now = Date.now();
  const key = `${role}Until`;
  const hasValid =
    cur[role] === true && typeof cur[key] === "number" && cur[key] > now;
  const until = (hasValid ? cur[key] : now) + Number(days) * 86400000;
  const next = { ...cur, role, [role]: true, [key]: until };
  // กันสิทธิ์ค้างที่ไม่ควรมี
  if (role !== "admin") delete next.admin;
  await auth.setCustomUserClaims(uid, next);
  await auth.revokeRefreshTokens(uid);
  return next;
}

/**
 * Webhook รับผลตรวจสลิปจาก SlipOK
 * - จับคู่ topups โดย refCode == data.transRef
 * - ตรวจ amount, qrTarget (PromptPay), expiresAt
 * - อนุมัติ + เปลี่ยน role อัตโนมัติ
 */
exports.slipokWebhook = onRequest(
  { region: "asia-southeast1" },
  async (req, res) => {
    try {
      if (req.method !== "POST")
        return res.status(405).send("Method Not Allowed");

      // === 1) รับ payload ===
      const body = req.body || {};
      const d = body.data || {};
      const transRef = d.transRef; // "2025100779AWh5U3Nn9A7h9ow"
      const amount = Number(d.amount); // 1 (ตัวอย่าง)
      const paidAtIso = d.transTimestamp; // "2025-10-07T06:51:44.000Z"
      const recvMsisdn = onlyDigits(d?.receiver?.proxy?.value); // "xxx-xxx-7022" -> "7022" (เดี๋ยวเทียบแบบ contains)

      if (!transRef || !Number.isFinite(amount)) {
        return res.status(400).send({ ok: false, reason: "bad_payload" });
      }

      // === 2) หาเอกสาร topups จาก refCode ===
      const q = await db
        .collection("topups")
        .where("refCode", "==", transRef)
        .limit(1)
        .get();
      if (q.empty) {
        logger.warn("topup not found for transRef:", transRef);
        return res.status(200).send({ ok: true, note: "not_found" }); // idempotent-friendly
      }
      const snap = q.docs[0];
      const topup = snap.data();

      // idempotent
      if (topup.status === "approved") {
        return res.status(200).send({ ok: true, idempotent: true });
      }

      // === 3) ตรวจหมดอายุ ===
      const nowMs = Date.now();
      if (topup.expiresAt && topup.expiresAt.toMillis() < nowMs) {
        await snap.ref.update({
          status: "failed",
          failReason: "expired",
          slipokPayload: body,
          updatedAt: new Date(),
        });
        return res.status(200).send({ ok: true, expired: true });
      }

      // === 4) ตรวจยอดโอน ===
      const expected = Number(topup.amountExpected ?? topup.amount);
      if (!Number.isFinite(expected) || amount !== expected) {
        await snap.ref.update({
          status: "failed",
          failReason: `amount_mismatch(${amount} != ${expected})`,
          slipokPayload: body,
          updatedAt: new Date(),
        });
        return res.status(200).send({ ok: true, amountMismatch: true });
      }

      // === 5) ตรวจปลายทาง PromptPay (ถ้ามีเก็บไว้) ===
      // topup.qrTarget อาจเก็บครบ "0876947022" ส่วน SlipOK ให้มาแบบแมสก์
      // วิธีเช็คที่ทนกว่า: ตรวจว่า "4 ตัวท้าย" ตรงกัน
      let targetOk = true;
      if (topup.qrTarget) {
        const target = onlyDigits(topup.qrTarget); // "0876947022"
        const last4A = target.slice(-4);
        const last4B = recvMsisdn.slice(-4);
        targetOk = last4A && last4B && last4A === last4B;
      }
      if (!targetOk) {
        await snap.ref.update({
          status: "failed",
          failReason: "qr_target_mismatch",
          slipokPayload: body,
          updatedAt: new Date(),
        });
        return res.status(200).send({ ok: true, qrTargetMismatch: true });
      }

      // === 6) ผ่านทุกเงื่อนไข → อนุมัติ ===
      await snap.ref.update({
        status: "approved",
        paidAt: paidAtIso ? new Date(paidAtIso) : new Date(),
        slipokPayload: body,
        slipokTransRef: d.transRef, // เก็บ transRef ของ SlipOK ไว้ด้วย

        updatedAt: new Date(),
      });

      // === 7) เปลี่ยน role ตามแพ็กเกจ ===
      const uid = topup.userId;
      const role = topup.roleTarget ?? "vip";
      const days = Number(topup.durationDays ?? 0);
      if (uid && role && days > 0) {
        await applyRoleExtend(uid, role, days);
        logger.info("Role updated", { uid, role, days });
      }

      return res.status(200).send({ ok: true, topupId: snap.id });
    } catch (err) {
      logger.error(err);
      return res.status(500).send("Internal Error");
    }
  }
);



// ==== SlipOK via URL (JSON) =========================================
async function slipokVerifyByUrl({apiKey, url, amount, log = true }) {
  const endpoint = `https://api.slipok.com/api/line/apikey/54127`;

  const resp = await fetch(endpoint, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-authorization": apiKey,           // << ใช้ x-authorization ตามสเปค
    },
    body: JSON.stringify({
      url,                                 // << ลิงก์รูปสลิป
      amount,                              // (optional) ให้ SlipOK cross-check ยอด
      log,                                 // (optional) เก็บ log เป็นหลักฐาน
    }),
  });

  let data = null;
  try {
    data = await resp.json();
  } catch (_) {
    // เผื่อ SlipOK ตอบไม่ใช่ JSON
  }
  return { ok: resp.ok, status: resp.status, data };
}


const { defineSecret } = require("firebase-functions/params");
// อ่าน secret ที่ตั้งไว้
const BRANCH_ID = "54127";
const SL_APIKEY = defineSecret("SLIPOK_API_KEY");

exports.manualVerify = onRequest(
  { region: "asia-southeast1", secrets: [BRANCH_ID, SL_APIKEY] },
  async (req, res) => {
    return cors(req, res, async () => {
      try {
        if (req.method !== "POST") return res.status(405).json({ error: "Method Not Allowed" });

        const { topupId, refCode, slipUrl } = req.body || {};
        if (!topupId || !refCode || !slipUrl) {
          return res.status(400).json({ error: "Missing fields: topupId, refCode, slipUrl" });
        }

        // โหลดเอกสาร topup
        const topupRef = db.collection("topups").doc(topupId);
        const snap = await topupRef.get();
        if (!snap.exists) return res.status(404).json({ error: "Topup not found" });
        const topup = snap.data();

        // กันยิงซ้ำ
        if (["approved", "rejected", "failed"].includes(topup.status)) {
          return res.status(409).json({ error: `Already ${topup.status}` });
        }

        // ตั้งสถานะกำลังตรวจ
        await topupRef.update({
          status: "under_review",
          updatedAt: new Date(),
          verify: {
            refCode,
            slipUrl,
            submittedAt: new Date(),
            userId: topup.userId || null,
          },
        });

        // เรียก SlipOK แบบ URL
        const branchId = BRANCH_ID;
        const apiKey   = SL_APIKEY.value();
        const expected = Number(topup.amountExpected ?? topup.amount);
        const { ok, status, data } = await slipokVerifyByUrl({
          branchId,
          apiKey,
          url: slipUrl,
          amount: Number.isFinite(expected) ? expected : undefined,
          log: true,
        });

        // เก็บ payload ตอบกลับไว้เสมอ (debug/อ้างอิง)
        const updateBase = {
          slipokPayload: data,
          updatedAt: new Date(),
        };

        // เช็คผลลัพธ์แบบปลอดภัย (เพราะโครงสร้าง response อาจต่าง)
        if (!ok) {
          await topupRef.update({
            ...updateBase,
            status: "rejected",
            failReason: `slipok_http_${status}`,
          });
          return res.status(400).json({ ok: false, reason: "slipok_http_error", status, data });
        }

        // คุณสามารถเพิ่ม logic cross-check เพิ่มเติมจาก data ได้ เช่น:
        // - ยอดจริงที่อ่านได้
        // - เวลาที่โอน
        // - ปลายทาง PromptPay (ถ้า SlipOK ส่งข้อมูลนี้กลับมา)
        // ด้านล่างนี้เราจะอนุมัติเลย ถ้า HTTP ok (และก่อนหน้าเราใส่ amount ไปแล้ว)
        await topupRef.update({
          ...updateBase,
          status: "approved",
        });

        // ต่ออายุ role หากกำหนดใน topup
        const uid = topup.userId;
        const role = topup.roleTarget ?? "vip";
        const days = Number(topup.durationDays ?? 0);
        if (uid && role && days > 0) await applyRoleExtend(uid, role, days);

        return res.status(200).json({ ok: true, verified: true, slipok: data });
      } catch (err) {
        logger.error("manualVerify failed", err);
        return res.status(500).json({ error: "Internal Error" });
      }
    });
  }
);

exports.setUserRole = onCall({ region: "asia-southeast1" }, async (req) => {
  try {
    // ---------- 1) ตรวจสิทธิ์ผู้เรียก (ต้องเป็น admin ผ่าน custom claims) ----------
    const caller = req.auth;
    if (!caller || caller.token?.admin !== true) {
      return { ok: false, error: "permission-denied: admin only" };
    }

    // ---------- 2) รับพารามิเตอร์ ----------
    const { uid, role, durationDays, extend } = req.data || {};
    if (!uid) return { ok: false, error: "missing uid" };

    const allowed = new Set(["user", "vip", "admin"]);
    if (!allowed.has(role)) return { ok: false, error: "invalid role" };

    // ---------- 3) เตรียมข้อมูลเดิม (claims + firestore) ----------
    const [userRec, userDocSnap] = await Promise.all([
      auth.getUser(uid),
      db.collection("users").doc(uid).get(),
    ]);

    const now = Date.now();

    // อ่าน vipUntil เดิม (จาก claims ก่อน, ถ้าไม่มีค่อยดู Firestore)
    const oldClaims = userRec.customClaims || {};
    let baseMs = now;
    const claimsVipUntil = typeof oldClaims.vipUntil === "number" ? oldClaims.vipUntil : 0;

    // Firestore vipUntil เดิม
    let fsVipUntilMs = 0;
    if (userDocSnap.exists) {
      const r = userDocSnap.get("roles");
      if (r && r.vipUntil && typeof r.vipUntil.toMillis === "function") {
        fsVipUntilMs = r.vipUntil.toMillis();
      }
    }

    if (extend === true) {
      // ทบจากอันที่ "ยังไม่หมดอายุ" สูงสุด
      const candidates = [claimsVipUntil, fsVipUntilMs].filter((x) => x > now);
      if (candidates.length > 0) {
        baseMs = Math.max(...candidates);
      }
    }

    // ---------- 4) คำนวณค่าใหม่ตาม role ----------
    let newClaims = { ...oldClaims };
    // เคลียร์คีย์ที่เกี่ยวกับ role ก่อน (เพื่อเลี่ยงค่าเก่าค้าง)
    delete newClaims.admin;
    delete newClaims.vip;
    delete newClaims.vipUntil;

    let rolesUpdate = {
      admin: false,
      vip: false,
      // vipUntil จะใส่/ลบแยกต่างหาก
    };

    let vipUntilMs = 0;

    if (role === "admin") {
      newClaims.admin = true;
      rolesUpdate.admin = true;
      rolesUpdate.vip = false;
    } else if (role === "vip") {
      const days = Number.isFinite(Number(durationDays)) && Number(durationDays) > 0
        ? Number(durationDays)
        : 30; // ค่า default = 30 วัน
      vipUntilMs = baseMs + daysToMs(days);

      newClaims.vip = true;
      newClaims.vipUntil = vipUntilMs;

      rolesUpdate.vip = true;
    } else {
      // role === "user" => ไม่มี admin, ไม่มี vip
      // newClaims ไม่มี admin/vip/vipUntil
      rolesUpdate.admin = false;
      rolesUpdate.vip = false;
    }

    // ---------- 5) เขียน Custom Claims ----------
    await auth.setCustomUserClaims(uid, newClaims);
    await auth.revokeRefreshTokens(uid); // ✅ เพิ่มบรรทัดนี้


    // ---------- 6) เขียน Firestore users/{uid}.roles ----------
    const userRef = db.collection("users").doc(uid);
    const updatePayload = {
      "roles.admin": rolesUpdate.admin,
      "roles.vip": rolesUpdate.vip,
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (role === "vip") {
      updatePayload["roles.vipUntil"] = Timestamp.fromMillis(vipUntilMs);
    } else {
      // ถ้าไม่ใช่ VIP ให้ลบ vipUntil ออก
      updatePayload["roles.vipUntil"] = FieldValue.delete();
    }

    await userRef.set(updatePayload, { merge: true });

    // ---------- 7) ตอบกลับ ----------
    return {
      ok: true,
      uid,
      role,
      claims: newClaims,
      roles: {
        admin: rolesUpdate.admin,
        vip: rolesUpdate.vip,
        vipUntil: role === "vip" ? vipUntilMs : null,
      },
    };
  } catch (err) {
    console.error("[setUserRole] error:", err);
    return { ok: false, error: String(err && err.message || err) };
  }
});

exports.forceRefreshToken = onCall(async (req) => {
  const uid = req.auth.uid;
  await auth.revokeRefreshTokens(uid);
  return { ok: true };
});
