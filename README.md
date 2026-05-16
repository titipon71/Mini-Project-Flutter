# Twebtoon

แพลตฟอร์มอ่านการ์ตูนเว็บ/มังงะออนไลน์ สร้างด้วย Flutter + FastAPI + MySQL

---

## Tech Stack

| ส่วน | เทคโนโลยี |
|------|-----------|
| Frontend | Flutter (Web, Android, iOS, Windows) |
| Backend | Python FastAPI + SQLAlchemy (async) |
| Database | MySQL |
| Auth | Firebase Authentication + Local JWT |
| File Storage | Local (FastAPI static files) |
| Payment | PromptPay QR + SlipOK verification |

---

## Architecture

```
Flutter App
    └── ApiService (HTTP + JWT)
            └── FastAPI Backend
                    ├── MySQL (mangas, chapters, users, topups)
                    └── Firebase Auth (identity verification only)
```

- Flutter ส่ง Firebase ID Token → FastAPI ออก Local JWT
- ทุก request หลังจากนั้นใช้ Local JWT (Bearer token)
- ข้อมูลทั้งหมดเก็บใน MySQL

---

## Project Structure

```
my_app/
├── lib/                        # Flutter frontend
│   ├── screens/                # หน้าจอต่างๆ
│   ├── services/               # API, Auth, VIP services
│   ├── helpers/                # User role extension
│   └── assets/widgets/         # Shared widgets (Sidebar)
│
├── backend/                    # FastAPI backend
│   ├── app/
│   │   ├── routers/            # API endpoints
│   │   ├── models/             # SQLAlchemy models
│   │   ├── schemas/            # Pydantic schemas
│   │   ├── services/           # Business logic (JWT, Firebase, SlipOK)
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── database.py
│   │   └── deps.py
│   ├── alembic/                # Database migrations
│   └── migrate_firebase.py     # Script ย้ายข้อมูลจาก Firebase
│
└── RUN_COMMANDS.txt            # คำสั่งรัน
```

---

## Getting Started

### Requirements

- Flutter SDK
- Python 3.11+
- MySQL 8.0+
- Firebase project (สำหรับ Authentication)

---

### 1. Setup Backend

```bash
cd backend
pip install -r requirements.txt
```

สร้างไฟล์ `.env` ใน `backend/`:

```env
DATABASE_URL=mysql+aiomysql://root:password@localhost:3306/twebtoon
FIREBASE_CREDENTIALS_PATH=./firebase-credentials.json
JWT_SECRET_KEY=your-strong-random-secret-here
SLIPOK_API_KEY=your-slipok-key
```

วาง `firebase-credentials.json` ไว้ใน `backend/`

รัน database migration:

```bash
alembic upgrade head
```

### 2. Setup Flutter

```bash
flutter pub get
```

---

## Running

**Terminal 1 — Backend:**

```bash
cd backend
uvicorn app.main:app --reload --port 8000
```

API Docs: [http://localhost:8000/docs](http://localhost:8000/docs)

**Terminal 2 — Flutter Web:**

```bash
flutter run -d chrome --web-port 7357
```

> ใช้ port 7357 เพราะอยู่ใน CORS whitelist แล้ว

---

## API Endpoints

| Method | Path | คำอธิบาย |
|--------|------|----------|
| POST | `/auth/token` | แลก Firebase token → Local JWT |
| GET | `/api/v1/mangas` | รายการมังงะทั้งหมด |
| GET | `/api/v1/mangas/:id/chapters` | รายการตอนของมังงะ |
| GET | `/api/v1/me/roles` | สถานะ VIP/Admin ของตัวเอง |
| PATCH | `/api/v1/me/profile` | อัปเดตโปรไฟล์ |
| GET | `/api/v1/admin/users` | รายชื่อผู้ใช้ทั้งหมด (Admin) |
| PATCH | `/api/v1/admin/users/:uid/roles` | เปลี่ยน role ผู้ใช้ (Admin) |
| GET | `/api/v1/admin/topups` | รายการ topup ทั้งหมด (Admin) |
| POST | `/api/v1/uploads` | อัปโหลดรูปภาพ |
| GET | `/api/v1/website-info` | ข้อมูลหน้าเว็บ (carousel images) |

---

## Features

- อ่านการ์ตูนเว็บ/มังงะ
- ระบบ VIP สมาชิกพรีเมียม
- Top-up ผ่าน PromptPay QR Code
- ตรวจสลิปอัตโนมัติด้วย SlipOK
- Admin Dashboard จัดการมังงะ, ตอน, ผู้ใช้
- ค้นหามังงะ
- รองรับ Web, Android, iOS, Windows
