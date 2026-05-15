# API Specification (Firebase Auth only)

## Overview
Base URL: /api/v1
Auth: Authorization: Bearer <Firebase ID token>
Roles: admin-only endpoints require admin == true (custom claims or roles)
Time format: ISO 8601 UTC string (ex: 2026-05-13T00:00:00Z)
Pagination: limit, cursor (opaque string)

Standard error response:
```json
{
  "error": {
    "code": "string",
    "message": "string",
    "details": {}
  }
}
```

---

## Data Sources (current Firebase schema)

### Realtime Database (RTDB)
- /mangas
  - key/index: string or 1-based list index
  - fields: name, cover, background, createdAt, updatedAt, chapters
- /mangas/{mangaId}/chapters
  - key/index: string or 1-based list index
  - fields: number, title, updatedAt, pages
- /website_info/carousel_images
  - list or map values of image URLs

### Firestore
- users/{uid}
  - roles.admin: boolean
  - roles.vip: boolean
  - roles.vipUntil: Timestamp
  - displayName, photoURL (optional)
- topups/{topupId}
  - fields listed in Topup model
- users/{uid}/topups/{topupId}
  - mirror of topups/{topupId}

### Storage (legacy paths)
- mangas/covers/*
- mangas/backgrounds/*
- manga_images/{mangaId}_cover.jpg
- manga_images/{mangaId}_background.jpg
- mangas/{mangaIndex}/chapters/{chapterIndex}/*
- pages/{pageIdx}/*
- topup_slips/{uid}/{topupId}/*
- carousel_images/*

---

## API Models (normalized)

### Manga
```json
{
  "id": "1",
  "name": "string",
  "coverUrl": "https://...",
  "backgroundUrl": "https://...|null",
  "createdAt": "2026-05-13T00:00:00Z",
  "updatedAt": "2026-05-13T00:00:00Z",
  "latestUpdatedAt": "2026-05-13T00:00:00Z",
  "chaptersCount": 12
}
```
Mapping:
- id <- RTDB /mangas/{id} key or list index (1-based)
- name <- /mangas/{id}/name
- coverUrl <- /mangas/{id}/cover
- backgroundUrl <- /mangas/{id}/background
- createdAt <- /mangas/{id}/createdAt (ms) -> ISO
- updatedAt <- /mangas/{id}/updatedAt (ms) -> ISO
- latestUpdatedAt <- max(chapters[].updatedAt) (ms) -> ISO
- chaptersCount <- count of chapters entries

### Chapter
```json
{
  "id": "1",
  "number": 1,
  "title": "string",
  "updatedAt": "2026-05-13T00:00:00Z",
  "pages": [
    {
      "id": "string|null",
      "index": 1,
      "type": "image",
      "url": "https://..."
    }
  ]
}
```
Mapping:
- id <- chapter key/index
- number <- number
- title <- title
- updatedAt <- updatedAt (ms) -> ISO
- pages <- pages list (index, type, url, optional id)

### WebsiteInfo
```json
{
  "carouselImages": ["https://..."]
}
```
Mapping:
- carouselImages <- /website_info/carousel_images (list or map values)

### UserProfile
```json
{
  "uid": "string",
  "email": "string|null",
  "displayName": "string|null",
  "photoUrl": "string|null",
  "roles": {
    "admin": false,
    "vip": true,
    "vipUntil": "2026-05-13T00:00:00Z|null"
  }
}
```
Mapping:
- email, displayName, photoUrl <- Firebase Auth user record and/or Firestore users/{uid}
- roles.* <- Firestore users/{uid}.roles
- vipUntil <- Firestore Timestamp -> ISO

### Topup
```json
{
  "topupId": "string",
  "userId": "string",
  "userName": "string",
  "packageLabel": "string",
  "packageValue": 3,
  "priceText": "$389",
  "amount": 389.0,
  "amountExpected": 389.0,
  "paymentMethod": "promptpay|card|bank_transfer",
  "status": "pending|paid|rejected|approved|failed|under_review|expired",
  "refCode": "string",
  "referral": "string|null",
  "slip": {
    "fileName": "string",
    "downloadUrl": "https://..."
  },
  "platform": "web|mobile",
  "createdAt": "2026-05-13T00:00:00Z",
  "updatedAt": "2026-05-13T00:00:00Z",
  "qrAmount": 389.0,
  "qrTarget": "0876947022",
  "roleTarget": "vip",
  "durationDays": 30,
  "expiresAt": "2026-05-15T00:00:00Z",
  "paidAt": "2026-05-13T00:00:00Z|null",
  "failReason": "string|null",
  "slipokPayload": {},
  "slipokTransRef": "string|null"
}
```
Mapping:
- topupId <- Firestore doc id (topups/{topupId})
- most fields are stored 1:1 in Firestore topup document
- status legacy values may include paid or approved depending on flow

### UploadAsset
```json
{
  "assetId": "string",
  "url": "https://...",
  "contentType": "image/png",
  "size": 123456,
  "createdAt": "2026-05-13T00:00:00Z"
}
```

---

## Endpoint Catalog

### Content (Manga)

GET /api/v1/mangas
- Auth: optional
- Query: limit, cursor, query (optional search)
- Response:
```json
{ "items": [Manga], "nextCursor": "string|null" }
```

GET /api/v1/mangas/{mangaId}
- Auth: optional
- Response: Manga

POST /api/v1/mangas
- Auth: admin
- Request:
```json
{ "name": "string", "coverUrl": "https://...", "backgroundUrl": "https://...|null" }
```
- Response: Manga

PUT /api/v1/mangas/{mangaId}
- Auth: admin
- Request:
```json
{ "name": "string|null", "coverUrl": "https://...|null", "backgroundUrl": "https://...|null" }
```
- Response: Manga

DELETE /api/v1/mangas/{mangaId}
- Auth: admin
- Response:
```json
{ "ok": true }
```

### Chapters

GET /api/v1/mangas/{mangaId}/chapters
- Auth: optional (enforce VIP on server if required)
- Response:
```json
{ "items": [Chapter] }
```

GET /api/v1/mangas/{mangaId}/chapters/{chapterId}
- Auth: optional (enforce VIP on server if required)
- Response: Chapter

POST /api/v1/mangas/{mangaId}/chapters
- Auth: admin
- Request:
```json
{
  "number": 1,
  "title": "string",
  "pages": [
    { "index": 1, "type": "image", "url": "https://...", "id": "string|null" }
  ]
}
```
- Response: Chapter

PUT /api/v1/mangas/{mangaId}/chapters/{chapterId}
- Auth: admin
- Request: same as create
- Response: Chapter

DELETE /api/v1/mangas/{mangaId}/chapters/{chapterId}
- Auth: admin
- Response:
```json
{ "ok": true }
```

### Website Info

GET /api/v1/website-info
- Auth: optional
- Response: WebsiteInfo

PUT /api/v1/website-info
- Auth: admin
- Request:
```json
{ "carouselImages": ["https://..."] }
```
- Response: WebsiteInfo

### Users and Roles

GET /api/v1/me
- Auth: user
- Response: UserProfile

GET /api/v1/me/roles
- Auth: user
- Response:
```json
{ "admin": false, "vip": true, "vipUntil": "2026-05-13T00:00:00Z|null" }
```

GET /api/v1/users/{uid}
- Auth: admin
- Response: UserProfile

GET /api/v1/admin/users
- Auth: admin
- Query: search, limit, cursor
- Response:
```json
{ "items": [UserProfile], "nextCursor": "string|null" }
```

PATCH /api/v1/admin/users/{uid}/roles
- Auth: admin
- Request:
```json
{ "role": "user|vip|admin", "durationDays": 30, "extend": true }
```
- Response:
```json
{ "ok": true, "uid": "string", "role": "user|vip|admin", "vipUntil": "2026-05-13T00:00:00Z|null" }
```

### Topups

POST /api/v1/topups
- Auth: user
- Request:
```json
{
  "topupId": "string|null",
  "userId": "string",
  "userName": "string|null",
  "packageLabel": "string",
  "packageValue": 3,
  "priceText": "$389",
  "amount": 389.0,
  "amountExpected": 389.0,
  "paymentMethod": "promptpay|card|bank_transfer",
  "refCode": "string",
  "referral": "string|null",
  "slipUrl": "https://...|null",
  "platform": "web|mobile",
  "qrAmount": 389.0,
  "qrTarget": "0876947022",
  "roleTarget": "vip",
  "durationDays": 30,
  "expiresAt": "2026-05-15T00:00:00Z"
}
```
- Response: Topup

GET /api/v1/topups/{topupId}
- Auth: owner or admin
- Response: Topup

GET /api/v1/users/{uid}/topups
- Auth: owner or admin
- Query: status, limit, cursor
- Response:
```json
{ "items": [Topup], "nextCursor": "string|null" }
```

GET /api/v1/admin/topups
- Auth: admin
- Query: status, q, limit, cursor
- Response:
```json
{ "items": [Topup], "nextCursor": "string|null" }
```

PATCH /api/v1/admin/topups/{topupId}
- Auth: admin
- Request:
```json
{ "status": "paid|rejected|approved", "failReason": "string|null" }
```
- Response: Topup

### Slip Verification

POST /api/v1/topups/{topupId}/manual-verify
- Auth: admin or system
- Request:
```json
{ "refCode": "string", "slipUrl": "https://..." }
```
- Response:
```json
{ "ok": true, "verified": true }
```

POST /api/v1/payments/slipok/verify
- Auth: user
- Request:
```json
{ "url": "https://...", "amount": 389.0 }
```
- Response:
```json
{ "ok": true, "slipok": {} }
```

POST /api/v1/payments/slipok/webhook
- Auth: system
- Request: SlipOK payload
- Response:
```json
{ "ok": true }
```

### Uploads / Assets

POST /api/v1/uploads
- Auth: user
- Request:
```json
{
  "purpose": "manga-cover|manga-background|chapter-page|topup-slip|carousel-image",
  "fileName": "string",
  "contentType": "image/png",
  "size": 123456,
  "mangaId": "string|null",
  "chapterId": "string|null",
  "topupId": "string|null"
}
```
- Response:
```json
{
  "uploadUrl": "https://...",
  "asset": { "assetId": "string", "url": "https://..." },
  "expiresAt": "2026-05-13T00:10:00Z"
}
```

DELETE /api/v1/assets/{assetId}
- Auth: owner or admin
- Response:
```json
{ "ok": true }
```

---

## Status Rules (Topups)
Suggested transitions:
- pending -> approved (auto) or rejected (admin)
- pending -> under_review (manual verify)
- under_review -> approved or rejected
- pending -> failed (amount mismatch or expired)

---

## Notes for Migration
- Normalize RTDB list vs map: treat both as key-value maps, preserve 1-based index if present.
- Chapters and pages must be reindexed 1..n on save (current UI logic depends on this).
- Keep legacy status values when reading old data; map to new set only on write.
- For VIP gating, compute:
  - vip == true AND vipUntil > now
- If using Firebase Auth only, still verify ID tokens on every endpoint.
