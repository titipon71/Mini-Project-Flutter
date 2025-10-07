/* eslint-disable */
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const cors = require("cors")({ origin: true });

// 1) ประกาศ secret ให้ถูกต้อง
const SLIPOK_API_KEY = defineSecret("SLIPOK_API_KEY");

// 2) ใส่ secrets: [SLIPOK_API_KEY] ใน options
exports.slipokProxy = onRequest(
  { region: "asia-southeast1", secrets: [SLIPOK_API_KEY] },
  async (req, res) => {
    cors(req, res, async () => {
      if (req.method !== "POST") {
        res.status(405).send("POST only");
        return;
      }
      try {
        // 3) ดึงค่าแบบถูกต้อง
        const apiKey = SLIPOK_API_KEY.value();

        // (ดีบั๊กชั่วคราว - ดูว่ามีค่าไหม)
        console.log("SLIPOK_API_KEY length:", apiKey ? apiKey.length : 0);

        const resp = await fetch("https://api.slipok.com/api/line/apikey/54127", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-authorization": apiKey, // แนบคีย์จริง
          },
          body: JSON.stringify(req.body),
        });

        const text = await resp.text();
        let data;
        try { data = JSON.parse(text); } catch { data = { raw: text }; }

        res.set("Cache-Control", "no-store");
        res.status(resp.status).json(data);
      } catch (err) {
        console.error(err);
        res.status(500).json({ error: String(err) });
      }
    });
  }
);
