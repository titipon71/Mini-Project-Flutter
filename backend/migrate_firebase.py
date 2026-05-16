#!/usr/bin/env python3
"""
migrate_firebase.py — ดึงข้อมูลจาก Firebase (RTDB + Firestore) แล้ว insert เข้า MySQL

วิธีใช้:
  cd backend/
  python migrate_firebase.py

ต้องมีใน .env:
  FIREBASE_DATABASE_URL=https://<project-id>-default-rtdb.firebaseio.com
"""
import os
import sys
import decimal
from datetime import datetime

sys.path.insert(0, os.path.dirname(__file__))
from app.config import settings

DATABASE_URL = settings.DATABASE_URL
CREDS_PATH = settings.FIREBASE_CREDENTIALS_PATH
RTDB_URL = settings.FIREBASE_DATABASE_URL

if not RTDB_URL:
    print("ERROR: FIREBASE_DATABASE_URL ไม่มีใน .env")
    print("  เพิ่ม: FIREBASE_DATABASE_URL=https://<project-id>-default-rtdb.firebaseio.com")
    sys.exit(1)

import firebase_admin
from firebase_admin import credentials, db as rtdb, firestore as fs

cred = credentials.Certificate(CREDS_PATH)
firebase_admin.initialize_app(cred, {"databaseURL": RTDB_URL})

# ใช้ sync driver สำหรับ migration script
SYNC_DB_URL = DATABASE_URL.replace("+aiomysql", "+pymysql")

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.models.manga import Manga, Chapter, Page
from app.models.user import User
from app.models.topup import Topup
from app.models.website import CarouselImage

engine = create_engine(SYNC_DB_URL, echo=False)


# ── helpers ──────────────────────────────────────────────────────────────────

def parse_ts(ts) -> datetime | None:
    if ts is None:
        return None
    if isinstance(ts, datetime):
        return ts.replace(tzinfo=None)
    if isinstance(ts, (int, float)):
        return datetime.utcfromtimestamp(ts / 1000 if ts > 1e10 else ts)
    return None


def to_list(data) -> list:
    """Firebase 1-indexed dict/list → Python list (skip nulls)"""
    if data is None:
        return []
    if isinstance(data, list):
        return [x for x in data if x is not None]
    if isinstance(data, dict):
        items = []
        for k in sorted(data.keys(), key=lambda x: int(x) if str(x).isdigit() else 0):
            v = data[k]
            if v is not None:
                items.append(v)
        return items
    return []


def to_decimal(val, default="0") -> decimal.Decimal:
    try:
        return decimal.Decimal(str(val or default))
    except Exception:
        return decimal.Decimal(default)


# ── migration functions ───────────────────────────────────────────────────────

def migrate_carousel(session: Session):
    print("\n=== Carousel Images (RTDB) ===")
    data = rtdb.reference("website_info/carousel_images").get()
    if not data:
        print("  ไม่มีข้อมูล — ข้าม")
        return

    if session.query(CarouselImage).count() > 0:
        print("  มีข้อมูลอยู่แล้ว — ข้าม")
        return

    images = to_list(data)
    inserted = 0
    for i, url in enumerate(images):
        if isinstance(url, str) and url.startswith("http"):
            session.add(CarouselImage(url=url, sort_order=i))
            inserted += 1
    session.commit()
    print(f"  ✅ {inserted} รูป")


def migrate_mangas(session: Session):
    print("\n=== Mangas / Chapters / Pages (RTDB) ===")
    data = rtdb.reference("mangas").get()
    if not data:
        print("  ไม่มีข้อมูล — ข้าม")
        return

    manga_list = to_list(data)
    print(f"  พบ {len(manga_list)} mangas ใน Firebase")

    count_m = count_c = count_p = 0

    for manga_data in manga_list:
        if not isinstance(manga_data, dict):
            continue
        name = (manga_data.get("name") or "").strip()
        if not name:
            continue

        if session.query(Manga).filter(Manga.name == name).first():
            print(f"  ข้าม '{name}' (มีอยู่แล้ว)")
            continue

        manga = Manga(
            name=name,
            cover_url=manga_data.get("cover") or "",
            background_url=manga_data.get("background"),
            created_at=parse_ts(manga_data.get("createdAt")) or datetime.utcnow(),
            updated_at=parse_ts(manga_data.get("updatedAt")) or datetime.utcnow(),
        )
        session.add(manga)
        session.flush()
        count_m += 1

        for ch_data in to_list(manga_data.get("chapters")):
            if not isinstance(ch_data, dict):
                continue
            chapter = Chapter(
                manga_id=manga.id,
                number=int(ch_data.get("number", 0)),
                title=str(ch_data.get("title", "")),
                updated_at=parse_ts(ch_data.get("updatedAt")) or datetime.utcnow(),
            )
            session.add(chapter)
            session.flush()
            count_c += 1

            for pg_data in to_list(ch_data.get("pages")):
                if not isinstance(pg_data, dict):
                    continue
                url = pg_data.get("url", "")
                if not url:
                    continue
                session.add(Page(
                    chapter_id=chapter.id,
                    page_index=int(pg_data.get("index", 0)),
                    type=str(pg_data.get("type", "image")),
                    url=url,
                ))
                count_p += 1

        session.commit()
        print(f"  ✅ '{name}'")

    print(f"  รวม: {count_m} mangas, {count_c} chapters, {count_p} pages")


def migrate_users(session: Session):
    print("\n=== Users (Firestore) ===")
    client = fs.client()
    docs = list(client.collection("users").stream())
    print(f"  พบ {len(docs)} users ใน Firestore")

    new_count = update_count = 0
    for doc in docs:
        data = doc.to_dict() or {}
        uid = doc.id
        roles = data.get("roles") or {}

        existing = session.get(User, uid)
        if existing:
            existing.is_admin = bool(roles.get("admin", False))
            existing.is_vip = bool(roles.get("vip", False))
            existing.vip_until = parse_ts(roles.get("vipUntil"))
            existing.updated_at = datetime.utcnow()
            session.commit()
            update_count += 1
            continue

        session.add(User(
            uid=uid,
            email=data.get("email"),
            display_name=data.get("displayName"),
            photo_url=data.get("photoUrl"),
            is_admin=bool(roles.get("admin", False)),
            is_vip=bool(roles.get("vip", False)),
            vip_until=parse_ts(roles.get("vipUntil")),
            created_at=parse_ts(data.get("createdAt")) or datetime.utcnow(),
            updated_at=parse_ts(data.get("updatedAt")) or datetime.utcnow(),
        ))
        session.commit()
        new_count += 1

    print(f"  ✅ เพิ่มใหม่ {new_count}, อัปเดต {update_count}")


def migrate_topups(session: Session):
    print("\n=== Topups (Firestore) ===")
    client = fs.client()
    docs = list(client.collection("topups").stream())
    print(f"  พบ {len(docs)} topups ใน Firestore")

    new_count = skip_count = 0
    for doc in docs:
        data = doc.to_dict() or {}
        topup_id = doc.id

        if session.get(Topup, topup_id):
            skip_count += 1
            continue

        user_id = data.get("userId", "")
        if not user_id:
            continue

        # สร้าง user stub ถ้ายังไม่มี (อาจ login ผ่าน Firebase เท่านั้นยังไม่เคยเข้าถึง backend)
        if not session.get(User, user_id):
            session.add(User(
                uid=user_id,
                display_name=data.get("userName"),
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow(),
            ))
            session.flush()

        session.add(Topup(
            id=topup_id,
            user_id=user_id,
            user_name=data.get("userName"),
            package_label=data.get("packageLabel") or "",
            package_value=int(data.get("packageValue") or 0),
            price_text=data.get("priceText") or "",
            amount=to_decimal(data.get("amount")),
            amount_expected=to_decimal(data.get("amountExpected") or data.get("amount")),
            payment_method=data.get("paymentMethod") or "promptpay",
            status=data.get("status") or "pending",
            ref_code=data.get("refCode") or "",
            referral=data.get("referral"),
            slip_file_name=data.get("slipFileName"),
            slip_download_url=data.get("slipDownloadUrl"),
            platform=data.get("platform") or "mobile",
            role_target=data.get("roleTarget") or "vip",
            duration_days=int(data.get("durationDays") or 30),
            qr_amount=to_decimal(data.get("qrAmount")) if data.get("qrAmount") else None,
            qr_target=data.get("qrTarget"),
            expires_at=parse_ts(data.get("expiresAt")),
            paid_at=parse_ts(data.get("paidAt")),
            fail_reason=data.get("failReason"),
            slipok_payload=data.get("slipokPayload"),
            slipok_trans_ref=data.get("slipokTransRef"),
            created_at=parse_ts(data.get("createdAt")) or datetime.utcnow(),
            updated_at=parse_ts(data.get("updatedAt")) or datetime.utcnow(),
        ))
        session.commit()
        new_count += 1

    print(f"  ✅ เพิ่มใหม่ {new_count}, ข้าม {skip_count} (มีอยู่แล้ว)")


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    print("=" * 55)
    print("  Firebase → MySQL Migration")
    print(f"  DB  : {SYNC_DB_URL.split('@')[-1]}")
    print(f"  RTDB: {RTDB_URL}")
    print("=" * 55)

    with Session(engine) as session:
        migrate_carousel(session)
        migrate_mangas(session)
        migrate_users(session)
        migrate_topups(session)

    print("\n" + "=" * 55)
    print("  ✅ Migration เสร็จสมบูรณ์!")
    print("=" * 55)


if __name__ == "__main__":
    main()
