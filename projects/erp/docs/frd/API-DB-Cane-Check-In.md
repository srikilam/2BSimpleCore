\#\# 8\) API Endpoints    
Base URL: \`\<base\_url\>\`    
Base Path: \`/cane/check-in\`

| Method | Path | Use case | Notes |  
|---|---|---|---|  
| GET | /api/cane-checkins | ดึงรายการ Checkin (List \+ Export CSV) | Headers: Authorization; Query filters: q, status, source\_type, guest\_only, cbm\_id, quota\_id, plate\_no, coin\_number, page, page\_size, sort; export=csv → synchronous CSV download; Journey/Page: CheckinListPage (\`/cane/check-in\`) · Journey E/A |  
| GET | /api/cane-checkins/{checkin\_id} | ดูรายละเอียด Checkin | Headers: Authorization; Response includes ETag; Journey/Page: CheckinDetail (\`/cane/check-in/:id\`) · used by Drawers/Detail |  
| POST | /api/cane-checkins | สร้าง Checkin (CBM / member\_no\_booking / guest\_pool) | Headers: Authorization, X-Idempotency-Key (required); body varies by source\_type; On CBM flow also PATCH CBM booking; Journey/Page: CheckinCBMDrawer / CheckinMemberDrawer / CheckinGuestDrawer · Journeys A/B/C |  
| PATCH | /api/cane-checkins/{checkin\_id} | แก้ไข Checkin (จำกัดตามสถานะ) | Headers: Authorization, If-Match (required to avoid stale) ; editable only when status permits; Journey/Page: Edit flow (\`/cane/check-in/:id/edit\`) |  
| POST | /api/cane-checkins/void | Void (soft) checkin — เปลี่ยน status → voided และคืน coin\_number | Headers: Authorization, X-Idempotency-Key (required), If-Match (recommended); body: { checkin\_id, reason }; Journey/Page: Confirm Void Modal \`/cane/check-in/{id}/void\` · Journey D |  
| GET | /api/cbm/bookings?status=dispatch | อ่านรายการ CBM bookings (แสดงคิว "ต้องส่ง") — upstream read-only | Headers: Authorization; used to populate List Tab "ต้องส่ง"; Journey/Page: CheckinListPage · Journey A |  
| PATCH | /api/cbm/bookings/{cbm\_id}/status | อัปเดตสถานะ CBM booking → awaiting\_payment (integration) | Headers: Authorization, If-Match (if upstream uses ETag); body: { "phase\_cut\_transport": "awaiting\_payment" }; Called during CBM create flow; Journey A |  
| GET | /api/cane-checkins/validate | (optional) ตรวจสอบความว่างของ \`coin\_number\` / quick-validate | Headers: Authorization; Query: coin\_number=... ; Journey/Page: Create Drawers (prefill/validate) |

\---

\#\#\# 8.1 List — \`GET /api/cane-checkins\`  
Traceability: Page \= \`Check-In — List View (/cane/check-in)\` · Action \= \`view:list\` · Journey \= \`Journey E\` / (A/B/C for resulting items)    
Headers (required/optional): \`Authorization: Bearer \<token\>\`    
Query params:  
| Name | Type | Req | Default | Description |  
|---|---:|:---:|---|---|  
| q | string | optional | — | search across cbm\_id, quota\_id, plate\_no, coin\_number |  
| status | string | optional | — | enum {checked\_in, awaiting\_payment, completed, voided} |  
| source\_type | string | optional | — | enum {cbm\_booking, member\_no\_booking, guest\_pool} |  
| guest\_only | boolean | optional | false | true → filter guest\_pool only |  
| cbm\_id | string | optional | — | filter by CBM id (pattern ^CBM-\\\\d{4}-\\\\d{7}$) |  
| quota\_id | string | optional | — | filter by quota\_id |  
| plate\_no | string | optional | — | filter by plate\_no |  
| coin\_number | string | optional | — | filter by coin\_number |  
| page | integer | optional | 1 | page number |  
| page\_size | integer | optional | 25 | page size |  
| sort | string | optional | \-checkin\_time | e.g., checkin\_time, \-checkin\_time |  
| export | string | optional | — | if \`export=csv\` → synchronous CSV download (per Page Definitions) |

\#\#\#\# Response (success):  
\`\`\`json  
{  
  "items": \[  
    {  
      "checkin\_id": "CHK-2025-000001",  
      "source\_type": "cbm\_booking",  
      "cbm\_id": "CBM-2025-0000001",  
      "quota\_id": "QUOTA-01",  
      "plate\_no": "1กข1234",  
      "driver\_name": "สมชาย ตัวอย่าง",  
      "driver\_phone": "0812345678",  
      "coin\_number": "CN001",  
      "entry\_channel": "gate\_a",  
      "payment\_type\_1st": "green\_bill",  
      "payment\_type\_2nd": "white\_bill",  
      "debt\_payment\_percent": 20,  
      "checkin\_time": "2025-01-01T01:00:00Z",  
      "status": "awaiting\_payment",  
      "guest\_flag": false,  
      "notes": "prefill from CBM",  
      "created\_by": "user\_1001",  
      "created\_at": "2025-01-01T01:00:00Z",  
      "updated\_by": null,  
      "updated\_at": null  
    }  
  \],  
  "meta": {  
    "page": 1,  
    "page\_size": 25,  
    "total": 300  
  }  
}  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "VALIDATION\_FAILED", "message": "Invalid filter", "details": \[ { "field": "coin\_number", "message": "must be at most 12 chars" } \], "trace\_id": "abc123" }  
\`\`\`

\---

\#\#\# 8.2 Detail — \`GET /api/cane-checkins/{checkin\_id}\`  
Traceability: Page \= \`Check-In — Detail/Drawer\` (\`/cane/check-in/:id\`) · Action \= \`view:detail\` · Journey \= \`detail view\`    
Headers (required/optional): \`Authorization: Bearer \<token\>\`; Response includes header \`ETag: "\<etag-value\>"\`    
Path params:  
| Name | Type | Req | Default | Description |  
|---|---:|:---:|---|---|  
| checkin\_id | string | required | — | pattern ^CHK-\\d{4}-\\d{6}$ |

\#\#\#\# Response (success):  
Headers: ETag returned (e.g., \`ETag: "W/\\"v123\\""\`)

\`\`\`json  
{  
  "checkin\_id": "CHK-2025-000001",  
  "source\_type": "cbm\_booking",  
  "cbm\_id": "CBM-2025-0000001",  
  "quota\_id": "QUOTA-01",  
  "plate\_no": "1กข1234",  
  "driver\_name": "สมชาย ตัวอย่าง",  
  "driver\_phone": "0812345678",  
  "coin\_number": "CN001",  
  "entry\_channel": "gate\_a",  
  "payment\_type\_1st": "green\_bill",  
  "payment\_type\_2nd": "white\_bill",  
  "debt\_payment\_percent": 20,  
  "checkin\_time": "2025-01-01T01:00:00Z",  
  "status": "awaiting\_payment",  
  "guest\_flag": false,  
  "notes": "prefill from CBM",  
  "created\_by": "user\_1001",  
  "created\_at": "2025-01-01T01:00:00Z",  
  "updated\_by": null,  
  "updated\_at": null  
}  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "NOT\_FOUND", "message": "checkin not found", "details": \[\], "trace\_id": "req-789" }  
\`\`\`

\---

\#\#\# 8.3 Create — \`POST /api/cane-checkins\`  
Traceability: Page \= \`Check-In — Create Drawers (/cane/check-in/new/\*)\` · Action \= \`create:checkin\` · Journey \= \`Journey A / B / C\`    
Headers (required/optional): \`Authorization: Bearer \<token\>\`, \`X-Idempotency-Key: \<uuid\>\` (required)    
Note: server will set status=checked\_in then immediately awaiting\_payment; for CBM flow the service will also call PATCH \`/api/cbm/bookings/{cbm\_id}/status\` per integration.

\#\#\#\# Request (CBM example):  
Headers: X-Idempotency-Key: "idem-123"

\`\`\`json  
{  
  "source\_type": "cbm\_booking",  
  "cbm\_id": "CBM-2025-0000001",  
  "plate\_no": "1กข1234",  
  "driver\_name": "สมชาย ตัวอย่าง",  
  "driver\_phone": "0812345678",  
  "coin\_number": "CN001",  
  "notes": "จาก QR scan"  
}  
\`\`\`

\#\#\#\# Request (Member no-booking example):  
\`\`\`json  
{  
  "source\_type": "member\_no\_booking",  
  "quota\_id": "QUOTA-01",  
  "plate\_no": "1กข1234",  
  "driver\_name": "สมหญิง ตัวอย่าง",  
  "driver\_phone": "0898765432",  
  "payment\_type\_1st": "green\_bill",  
  "payment\_type\_2nd": "white\_bill",  
  "debt\_payment\_percent": 30,  
  "coin\_number": "CN002",  
  "notes": ""  
}  
\`\`\`

\#\#\#\# Response (success 201):  
Headers: ETag returned (optional)

\`\`\`json  
{  
  "checkin\_id": "CHK-2025-000002",  
  "status": "awaiting\_payment",  
  "checkin\_time": "2025-01-01T02:00:00Z",  
  "coin\_number": "CN002"  
}  
\`\`\`

\#\#\#\# Error (examples):  
\`\`\`json  
{ "code": "VALIDATION\_FAILED", "message": "coin\_number is required or duplicate", "details": \[ { "field": "coin\_number", "message": "duplicate for active checkin" } \], "trace\_id": "tx-456" }  
\`\`\`

\---

\#\#\# 8.4 Update — \`PATCH /api/cane-checkins/{checkin\_id}\`  
Traceability: Page \= \`Check-In — Edit (/cane/check-in/:id/edit)\` · Action \= \`update:checkin\` · Journey \= \`Edit flow\`    
Headers (required/optional): \`Authorization: Bearer \<token\>\`, \`If-Match: "\<etag\>"\` (required)    
Preconditions: editable only when status allows (not awaiting\_payment/completed per Status Model)

\#\#\#\# Request:  
\`\`\`json  
{  
  "plate\_no": "1กข9999",  
  "driver\_name": "สมชาย แก้ไข",  
  "driver\_phone": "0812345679",  
  "notes": "แก้ไขข้อมูล"  
}  
\`\`\`

\#\#\#\# Response (success):  
\`\`\`json  
{  
  "checkin\_id": "CHK-2025-000001",  
  "status": "checked\_in",  
  "updated\_at": "2025-01-01T03:00:00Z",  
  "updated\_by": "user\_1002"  
}  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "CONFLICT\_UPDATE\_STALE", "message": "ETag mismatch", "details": \[\], "trace\_id": "etag-001" }  
\`\`\`

\---

\#\#\# 8.5 Void — \`POST /api/cane-checkins/void\`  
Traceability: Page \= \`Confirm Void Modal (/cane/check-in/{id}/void)\` · Action \= \`void:checkin\` · Journey \= \`Journey D\`    
Headers (required): \`Authorization: Bearer \<token\>\`, \`X-Idempotency-Key: \<uuid\>\` (required), \`If-Match: "\<etag\>"\` (recommended)    
Request:  
\`\`\`json  
{  
  "checkin\_id": "CHK-2025-000001",  
  "reason": "ผิดทะเบียน \- คืนเหรียญ"  
}  
\`\`\`

\#\#\#\# Response:  
\`\`\`json  
{  
  "checkin\_id": "CHK-2025-000001",  
  "status": "voided",  
  "released\_coin\_number": "CN001",  
  "voided\_at": "2025-01-01T03:30:00Z"  
}  
\`\`\`

\#\#\#\# Error (examples):  
\`\`\`json  
{ "code": "INVALID\_STATE", "message": "cannot void a completed checkin", "details": \[\], "trace\_id": "void-234" }  
\`\`\`

\---

\#\#\# 8.6 CBM Bookings — \`GET /api/cbm/bookings\`  
Traceability: Page \= \`Check-In — List View (/cane/check-in)\` · Action \= \`fetch:cbm\_bookings\` · Journey \= \`Journey A\`    
Headers (required/optional): \`Authorization: Bearer \<token\>\`    
Query params: \`status=dispatch\` recommended to fetch "ต้องส่ง"

\#\#\#\# Response (success):  
\`\`\`json  
{  
  "items": \[  
    {  
      "cbm\_id": "CBM-2025-0000001",  
      "farmer\_name": "นาย A",  
      "quota\_id": "QUOTA-01",  
      "plate\_no": "1กข1234",  
      "driver\_name": "สมชาย",  
      "driver\_phone": "0812345678",  
      "booking\_status": "dispatch"  
    }  
  \],  
  "meta": { "page": 1, "page\_size": 25, "total": 10 }  
}  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "NOT\_FOUND", "message": "no cbm bookings", "details": \[\], "trace\_id": "cbm-001" }  
\`\`\`

\---

\#\#\# 8.7 CBM Booking Status Update — \`PATCH /api/cbm/bookings/{cbm\_id}/status\`  
Traceability: Page \= \`Check-In — CBM Drawer\` · Action \= \`cbm:patch\_status\` · Journey \= \`Journey A\` (side-effect of create)    
Headers (required/optional): \`Authorization: Bearer \<token\>\`, \`If-Match: "\<etag\>"\` (if upstream uses ETag)    
Request:  
\`\`\`json  
{ "phase\_cut\_transport": "awaiting\_payment" }  
\`\`\`

\#\#\#\# Response:  
\`\`\`json  
{ "cbm\_id": "CBM-2025-0000001", "booking\_status": "awaiting\_payment", "updated\_at": "2025-01-01T01:05:00Z" }  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "INVALID\_STATE", "message": "CBM not in dispatchable state", "details": \[\], "trace\_id": "cbm-patch-01" }  
\`\`\`

\---

\#\#\# 8.8 Quick-validate coin\_number — \`GET /api/cane-checkins/validate\`  
Traceability: Page \= \`Create Drawers\` · Action \= \`validate:coin\` · Journey \= \`Journeys A/B/C\`    
Headers (required): \`Authorization: Bearer \<token\>\`    
Query params:  
| Name | Type | Req | Description |  
|---|---:|:---:|---|  
| coin\_number | string | required | coin\_number to validate (max 12\) |

\#\#\#\# Response:  
\`\`\`json  
{ "coin\_number": "CN003", "available": true }  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "VALIDATION\_FAILED", "message": "coin\_number format invalid", "details": \[\], "trace\_id": "val-001" }  
\`\`\`

\---

\# 9\. API Contract — Notes & Conventions

9.1 Security & Headers  
\- Authentication: \`Authorization: Bearer \<jwt\>\` (RBAC enforced server-side). Roles per Canonical Map: \`Gate Staff\`, \`Dispatcher\`, \`Logistics Supervisor\`.  
\- Headers:  
  \- \`X-Idempotency-Key\` — required for retriable POST operations (e.g., \`POST /api/cane-checkins\`, \`POST /api/cane-checkins/void\`).  
  \- \`If-Match\` — required for \`PATCH /api/cane-checkins/{id}\` and recommended for \`POST /api/cane-checkins/void\` to detect stale resources (ETag from \`GET\`).  
  \- Responses for detail/list SHOULD include \`ETag\` header for concurrency control.  
\- RBAC: enforce action gating (create, void, edit) as defined in Page Definitions (Gate Staff primary actor; Dispatcher read-only; Logistics Supervisor may approve voids per policy).

9.2 Error Model & Codes  
\- Use HTTP status codes semantically: 400, 401, 403, 404, 409, 412, 422, 429, 500\.  
\- Shared error payload:  
\`\`\`json  
{ "code": "…", "message": "…", "details": \[ { "field": "…", "message": "…" } \], "trace\_id": "…" }  
\`\`\`  
\- Domain-specific codes (must be used where applicable):  
  \- \`VALIDATION\_FAILED\` — missing/invalid inputs (e.g., coin\_number format/duplicate).  
  \- \`NOT\_FOUND\` — resource missing (e.g., cbm\_id not found).  
  \- \`INVALID\_STATE\` — attempting actions not permitted by status model (e.g., void after completed).  
  \- \`DEBT\_PERCENT\_OUT\_OF\_RANGE\` — debt\_payment\_percent outside 0..100.  
  \- \`CONFLICT\_UPDATE\_STALE\` — ETag mismatch; mapped to HTTP 412\.  
  \- \`FORBIDDEN\` — RBAC denies action (HTTP 403).  
\- UX guidance:  
  \- On 412 (ETag mismatch): client should re-fetch the resource, present merge dialog or show latest data.  
  \- On 409 (conflict, coin\_number): show guidance to choose different coin\_number or retry; display conflicting record summary if available.

9.3 Rate Limits & Required Headers  
\- Default rate guidance: 120 requests/min per consumer (adjust per NFR). Return \`Retry-After\` for 429\.  
\- Require \`X-Idempotency-Key\` on POSTs that create or change resources to allow safe retries.  
\- Clients should include \`Accept: application/json\` and \`Content-Type: application/json\` for JSON payloads.

9.4 Idempotency & Concurrency  
\- POST create/void: implement idempotency keyed by \`X-Idempotency-Key\`. On duplicate idempotency key, return the original response (201/200) or 409 if semantics differ.  
\- PATCH/void: use \`If-Match\` with ETag to prevent lost updates. On mismatch return 412 \`CONFLICT\_UPDATE\_STALE\`.  
\- coin\_number reservation: enforce database-level unique constraint WHERE status IN ('checked\_in','awaiting\_payment'). Acquire transactional lock when validating/committing coin\_number to avoid races.  
\- Retry/backoff: clients should use exponential backoff for 429/5xx. For 412, do not retry blindly — refresh state and prompt user.

9.5 Example Requests (cURL)  
\- List with filters:  
\`\`\`bash  
curl \-s \-H "Authorization: Bearer \<token\>" "\<base\_url\>/api/cane-checkins?q=CBM-2025\&status=awaiting\_payment\&page=1\&page\_size=25\&sort=-checkin\_time"  
\`\`\`  
\- Create (Member) with Idempotency:  
\`\`\`bash  
curl \-X POST "\<base\_url\>/api/cane-checkins" \\  
  \-H "Authorization: Bearer \<token\>" \\  
  \-H "X-Idempotency-Key: idem-12345" \\  
  \-H "Content-Type: application/json" \\  
  \-d '{  
    "source\_type":"member\_no\_booking",  
    "quota\_id":"QUOTA-01",  
    "plate\_no":"1กข1234",  
    "driver\_name":"สมหญิง ตัวอย่าง",  
    "driver\_phone":"0898765432",  
    "payment\_type\_1st":"green\_bill",  
    "payment\_type\_2nd":"white\_bill",  
    "debt\_payment\_percent":30,  
    "coin\_number":"CN010",  
    "notes":"สนามทดสอบ"  
  }'  
\`\`\`  
\- Update with If-Match:  
\`\`\`bash  
curl \-X PATCH "\<base\_url\>/api/cane-checkins/CHK-2025-000001" \\  
  \-H "Authorization: Bearer \<token\>" \\  
  \-H 'If-Match: "W/\\"v123\\""' \\  
  \-H "Content-Type: application/json" \\  
  \-d '{ "plate\_no":"1กข9999", "driver\_phone":"0812345679" }'  
\`\`\`  
\- Void with Idempotency & If-Match:  
\`\`\`bash  
curl \-X POST "\<base\_url\>/api/cane-checkins/void" \\  
  \-H "Authorization: Bearer \<token\>" \\  
  \-H "X-Idempotency-Key: idem-void-001" \\  
  \-H 'If-Match: "W/\\"v124\\""' \\  
  \-H "Content-Type: application/json" \\  
  \-d '{ "checkin\_id":"CHK-2025-000001", "reason":"ข้อมูลผิดพลาด" }'  
\`\`\`

9.6 Notes (Integrations & Export)  
\- Export CSV: per Page Definitions \`Export CSV\` is implemented as \`GET /api/cane-checkins?{filters}\&export=csv\` — synchronous CSV download is acceptable for typical page sizes. For large exports implement async job (202 \+ job endpoint) — not defined in current inputs (Warning: large export not specified).  
\- Outbound integration: after successful CBM flow create, call \`PATCH /api/cbm/bookings/{cbm\_id}/status\` with body \`{ "phase\_cut\_transport": "awaiting\_payment" }\`. Upstream may require \`If-Match\` (use ETag if provided by upstream).  
\- Events/Webhooks: feature emits events \`cane.checkin.created\` and \`cane.checkin.voided\` (EventBus). Payment system must call back to transition \`awaiting\_payment\` → \`completed\` (webhook/API not defined — Payment contract missing; see Warnings).  
\- Webhook security: when adding Payment webhook, require HMAC signature and authentication.  
\- PII/Masking: \`driver\_phone\` is PII — mask in logs and ensure transport uses TLS. In UI show partial mask for non-essential contexts.  
\- Audit: every create/void/update must record actor id, role, timestamp, and reason (for void). Audit trail storage required per NFR.  
\- Approval: approval flow for Void is not fully specified — current API assumes immediate void by Gate Staff; if Logistics Supervisor approval required, introduce separate endpoints \`POST /api/cane-checkins/{id}:request\_void\` and \`POST /api/cane-checkins/{id}:approve\_void\` (not in current spec — add if needed).

\---

\#\# 10.0 Data Schema

\#\#\# 10.0.1 ภาพรวมเอนทิตี (Entity Overview)  
\- cane\_checkins — เก็บรายการเช็คอินรถส่งอ้อย (อ้างอิง CBM booking แบบอ้างอิงค่าเท่านั้น) · ใช้เป็นแหล่งข้อมูลหลักสำหรับสถานะเช็คอิน/การคืนเหรียญ · ไม่มี FK ไปยังระบบ CBM (upstream) — เก็บ cbm\_id เป็น string ที่มีรูปแบบ  
\- cbm\_bookings (UPSTREAM) — ระบบภายนอก (CBM) เป็นแหล่งความจริงของ booking/status (อ่าน/patch ผ่าน integration) · cane\_checkins จะเรียก PATCH ไปยัง /api/cbm/bookings/{cbm\_id}/status เมื่อเช็คอิน CBM สำเร็จ  
\- quota (reference) — quota\_id เก็บเป็น string อ้างอิงโควต้าภายนอก/โดเมน

\---

\#\#\# 10.0.2 สคีมาตามตาราง

\#\#\# ตาราง cane\_checkins — รายการเช็คอินรถส่งอ้อย  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`CHK-YYYY-\#\#\#\#\#\#\`) — UNIQUE    
\- UK: ไม่มียูนิกแบบธุรกิจนอกเหนือจาก \`id\`    
\- FK: ไม่มี FK ไปยังตารางภายใน (cbm\_id เป็น external reference)    
\- Parent-of: — / Child-of: —  

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---|---|---|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | idx: pk | คีย์ภายใน (ไม่เปิดเผยผ่าน API) |  
| id | varchar(15) | UNIQUE (public id) | NO | trigger | CHECK (id \~ '^CHK-\\d{4}-\\d{6}$') | uq\_cane\_checkins\_id | รหัสสั้นตามรูปแบบ CHK-YYYY-\#\#\#\#\#\# (public) |  
| created\_at | timestamptz | \- | NO | now() | \- | idx\_cane\_checkins\_created\_at | วันที่สร้าง (UTC) |  
| updated\_at | timestamptz | \- | NO | now() | \- | idx\_cane\_checkins\_updated\_at | วันที่แก้ไขล่าสุด (UTC) |  
| version | integer | \- | NO | 1 | CHECK (version \> 0\) | \- | optimistic locking / ETag base |  
| checkin\_time | timestamptz | \- | NO | now() | \- | idx\_cane\_checkins\_checkin\_time\_desc (btree DESC) | เวลาที่เช็คอิน (จัดเก็บเป็น timestamptz) |  
| source\_type | text | \- | NO | 'cbm\_booking' | CHECK (source\_type IN ('cbm\_booking','member\_no\_booking','guest\_pool')) | idx\_cane\_checkins\_source\_type | ประเภทแหล่งข้อมูลเช็คอิน (Canonical) |  
| cbm\_id | varchar(15) | \- | YES | NULL | CHECK (cbm\_id \~ '^CBM-\\d{4}-\\d{7}$') | idx\_cane\_checkins\_cbm\_id | อ้างอิง CBM booking (upstream) |  
| quota\_id | varchar(64) | \- | YES | NULL | \- | idx\_cane\_checkins\_quota\_id | โควต้า (reference string) |  
| plate\_no | varchar(32) | \- | YES | NULL | \- | idx\_cane\_checkins\_plate\_no | ป้ายทะเบียน |  
| driver\_name | varchar(200) | \- | YES | NULL | \- | \- | ชื่อคนขับ |  
| driver\_phone | varchar(16) | \- | YES | NULL | CHECK (driver\_phone \~ '^0\\d{8,9}$') | idx\_cane\_checkins\_driver\_phone | เบอร์โทรคนขับ (PII) |  
| coin\_number | varchar(12) | \- | NO | '' | CHECK (char\_length(coin\_number) BETWEEN 1 AND 12\) | partial unique idx (see Indexes) | หมายเลขเหรียญ/คิว (ต้องไม่ซ้ำในสถานะ active) |  
| entry\_channel | varchar(64) | \- | YES | NULL | \- | idx\_cane\_checkins\_entry\_channel | ช่องทางเข้า เช่น gate\_a |  
| payment\_type\_1st | text | \- | YES | NULL | CHECK (payment\_type\_1st IN ('green\_bill','white\_bill')) | \- | ประเภทการชำระหลัก |  
| payment\_type\_2nd | text | \- | YES | NULL | CHECK (payment\_type\_2nd IN ('green\_bill','white\_bill')) | \- | ประเภทการชำระรอง |  
| debt\_payment\_percent | integer | \- | YES | NULL | CHECK (debt\_payment\_percent BETWEEN 0 AND 100\) | \- | หากมีหนี้เป็น % (member\_no\_booking บังคับ) |  
| status | text | \- | NO | 'checked\_in' | CHECK (status IN ('checked\_in','awaiting\_payment','completed','voided')) | idx\_cane\_checkins\_status\_updated\_at | สถานะหลักของเช็คอิน |  
| guest\_flag | boolean | \- | NO | false | \- | idx\_cane\_checkins\_guest\_flag | แสดงว่าเป็น guest\_pool |  
| notes | text | \- | YES | NULL | \- | \- | หมายเหตุ/Prefill จาก CBM |  
| created\_by | varchar(64) | \- | NO | 'system' | \- | idx\_cane\_checkins\_created\_by | user id ผู้สร้าง (actor) |  
| updated\_by | varchar(64) | \- | YES | NULL | \- | idx\_cane\_checkins\_updated\_by | user id ผู้แก้ไขล่าสุด |  
| voided\_at | timestamptz | \- | YES | NULL | \- | idx\_cane\_checkins\_voided\_at | เวลา void (เมื่อ status → voided) |  
| voided\_by | varchar(64) | \- | YES | NULL | \- | \- | ผู้ดำเนินการ void |  
| void\_reason | text | \- | YES | NULL | \- | \- | เหตุผล void (required ใน API void request) |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- API \`checkin\_id\` ↔ DB \`id\` (public short id)    
\- API \`cbm\_id\` ↔ DB \`cbm\_id\` (string, รูปแบบ ^CBM-\\d{4}-\\d{7}$)    
\- API \`created\_at\`/\`updated\_at\`/\`checkin\_time\` ↔ DB timestamptz (เก็บ UTC; application layer เป็นผู้แปลง/แสดงเป็น \+07:00/พ.ศ.)    
\- API ใช้ \`status\`, \`source\_type\`, \`payment\_type\_\*\` เป็นค่าตาม Canonical; DB บังคับผ่าน CHECK

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- แถวตัวอย่าง 1  
  \- row\_id: 57b1a7e3-8f3c-4d12-9a2c-3f8e9b1c2a11    
  \- id: CHK-2025-000001    
  \- created\_at: 2025-01-01T01:00:00Z    
  \- updated\_at: 2025-01-01T01:00:00Z    
  \- checkin\_time: 2025-01-01T01:00:00Z    
  \- source\_type: cbm\_booking    
  \- cbm\_id: CBM-2025-0000001    
  \- quota\_id: QUOTA-01    
  \- plate\_no: 1กข1234    
  \- driver\_name: สมชาย ตัวอย่าง    
  \- driver\_phone: 0812345678    
  \- coin\_number: CN001    
  \- entry\_channel: gate\_a    
  \- payment\_type\_1st: green\_bill    
  \- payment\_type\_2nd: white\_bill    
  \- debt\_payment\_percent: 20    
  \- status: awaiting\_payment    
  \- guest\_flag: false    
  \- notes: prefill from CBM    
  \- created\_by: user\_1001    
  \- voided\_at/voided\_by/void\_reason: NULL  
\- แถวตัวอย่าง 2 (member\_no\_booking)  
  \- row\_id: 7c2d9f21-44b2-4a21-8b6f-a6d6b0e3d222    
  \- id: CHK-2025-000002    
  \- source\_type: member\_no\_booking    
  \- quota\_id: QUOTA-02    
  \- coin\_number: CN002    
  \- payment\_type\_1st: green\_bill    
  \- payment\_type\_2nd: white\_bill    
  \- debt\_payment\_percent: 30    
  \- status: awaiting\_payment    
  \- created\_by: user\_1010  
\- แถวตัวอย่าง 3 (guest\_pool)  
  \- row\_id: 9d3e1b44-1a2b-4c77-b5f0-2f9a7c6b3333    
  \- id: CHK-2025-000003    
  \- source\_type: guest\_pool    
  \- coin\_number: CN100    
  \- payment\_type\_1st: white\_bill    
  \- payment\_type\_2nd: green\_bill    
  \- debt\_payment\_percent: NULL    
  \- guest\_flag: true    
  \- status: checked\_in

\#\#\#\#= 10.0.3 แนวทางการตั้งดัชนี (Indexing Hints)  
\- ดัชนี FK/lookup:  
  \- idx\_cane\_checkins\_cbm\_id ON cane\_checkins(cbm\_id)  
  \- idx\_cane\_checkins\_quota\_id ON cane\_checkins(quota\_id)  
  \- idx\_cane\_checkins\_plate\_no ON cane\_checkins(plate\_no)  
  \- idx\_cane\_checkins\_driver\_phone ON cane\_checkins(driver\_phone)  
  \- idx\_cane\_checkins\_entry\_channel ON cane\_checkins(entry\_channel)  
  \- idx\_cane\_checkins\_created\_by ON cane\_checkins(created\_by)  
\- สถานะ/เวลาค้นหา:  
  \- idx\_cane\_checkins\_status\_updated\_at ON cane\_checkins(status, updated\_at DESC)  
  \- idx\_cane\_checkins\_checkin\_time\_desc ON cane\_checkins(checkin\_time DESC)  
\- Unique / partial:  
  \- UNIQUE partial index for coin\_number when active:  
    \- CONCURRENTLY CREATE UNIQUE INDEX uq\_cane\_checkins\_coin\_number\_active ON cane\_checkins(coin\_number) WHERE status IN ('checked\_in','awaiting\_payment');  
\- Exact lookups:  
  \- idx\_cane\_checkins\_id (unique constraint) — exact lookup by public id

\---

\#\# 10.1 ERD  
\`\`\`mermaid  
erDiagram  
  CANE\_CHECKINS {  
    uuid row\_id PK  
    varchar id  
    timestamptz checkin\_time  
    text source\_type  
    varchar cbm\_id  
    varchar quota\_id  
    varchar plate\_no  
    varchar driver\_name  
    varchar driver\_phone  
    varchar coin\_number  
    text entry\_channel  
    text payment\_type\_1st  
    text payment\_type\_2nd  
    integer debt\_payment\_percent  
    text status  
    boolean guest\_flag  
    text notes  
    varchar created\_by  
    varchar updated\_by  
    timestamptz created\_at  
    timestamptz updated\_at  
    timestamptz voided\_at  
  }

  %% CBM\_BOOKINGS is external/upstream (no internal FK)  
  CBM\_BOOKINGS {  
    varchar cbm\_id  
    text booking\_status  
  }

  CANE\_CHECKINS ||--o{ CBM\_BOOKINGS : "references (external)"  
\`\`\`

(หมายเหตุ: CBM\_BOOKINGS เป็นระบบภายนอก — cane\_checkins เก็บ cbm\_id เป็น reference string เท่านั้น)

\---

\#\# 10.2 ไฮไลท์ DDL & นโยบายคีย์  
\- Extension prerequisite:  
  \- CREATE EXTENSION IF NOT EXISTS pgcrypto;  
\- PK:  
  \- row\_id UUID PRIMARY KEY DEFAULT gen\_random\_uuid()  
\- Public ID:  
  \- \`id VARCHAR(15) NOT NULL UNIQUE\` \+ \`CHECK (id \~ '^CHK-\\d{4}-\\d{6}$')\`  
  \- Sequence \+ trigger (generator จะสร้างรูปแบบ 'CHK-' || to\_char(now(),'YYYY') || '-' || lpad(nextval('seq\_cane\_checkins\_public\_id')::text,6,'0'))  
  \- Sequence: seq\_cane\_checkins\_public\_id  
  \- Trigger function: fn\_cane\_checkins\_make\_public\_id()  
\- Optimistic lock:  
  \- version INTEGER NOT NULL DEFAULT 1 CHECK (version \> 0\)  
  \- API ใช้ ETag ที่อิง version  
\- Timestamps:  
  \- created\_at/updated\_at TIMESTAMPTZ NOT NULL DEFAULT now()  
\- Foreign keys:  
  \- ไม่มี FK ภายใน; cbm\_id เป็น external reference (validate pattern only)  
\- On-delete/update policy:  
  \- Default: ON UPDATE CASCADE ON DELETE RESTRICT (ไม่มี FK ภายใน)  
\- Partial unique:  
  \- UNIQUE INDEX uq\_cane\_checkins\_coin\_number\_active ON cane\_checkins(coin\_number) WHERE status IN ('checked\_in','awaiting\_payment')  
  \- เหมาะสำหรับป้องกันการจองเหรียญซ้ำขณะ active  
\- Index naming convention:  
  \- idx\_cane\_checkins\_\<col\> for single-column indexes  
  \- idx\_cane\_checkins\_status\_updated\_at for composite index  
\- Race conditions & transactions:  
  \- coin\_number uniqueness enforced by partial unique index; transaction should SELECT FOR UPDATE / SERIALIZABLE or rely on constraint violation and retry with idempotency key/backoff  
\- Sequence/Trigger template (Postgres 14+):  
\`\`\`sql  
CREATE SEQUENCE IF NOT EXISTS seq\_cane\_checkins\_public\_id;

CREATE OR REPLACE FUNCTION fn\_cane\_checkins\_make\_public\_id()  
RETURNS trigger LANGUAGE plpgsql AS $$  
BEGIN  
  IF NEW.id IS NULL OR NEW.id \= '' THEN  
    NEW.id := 'CHK-' || to\_char(now(), 'YYYY') || '-' || lpad(nextval('seq\_cane\_checkins\_public\_id')::text, 6, '0');  
  END IF;  
  RETURN NEW;  
END; $$;

CREATE TRIGGER trg\_cane\_checkins\_public\_id  
BEFORE INSERT ON cane\_checkins  
FOR EACH ROW EXECUTE FUNCTION fn\_cane\_checkins\_make\_public\_id();  
\`\`\`

\---

\#\# 10.3 พจนานุกรมข้อมูล (Field Dictionary แบบเต็ม)  
ตาราง: cane\_checkins

\- row\_id  
  \- ชนิด: uuid  
  \- Null: NO  
  \- Default: gen\_random\_uuid()  
  \- คำอธิบาย: PK ภายใน (ไม่เปิดเผย)  
  \- ตัวอย่าง: 57b1a7e3-8f3c-4d12-9a2c-3f8e9b1c2a11  
  \- PII: no

\- id  
  \- ชนิด: varchar(15)  
  \- Null: NO  
  \- Default: trigger generator  
  \- คำอธิบาย: public id รูปแบบ CHK-YYYY-\#\#\#\#\#\# (อ่านได้)  
  \- ตัวอย่าง: CHK-2025-000001  
  \- PII: no

\- created\_at  
  \- ชนิด: timestamptz  
  \- Null: NO  
  \- Default: now()  
  \- คำอธิบาย: เวลาสร้าง (เก็บ UTC)  
  \- ตัวอย่าง: 2025-01-01T01:00:00Z  
  \- PII: no

\- updated\_at  
  \- ชนิด: timestamptz  
  \- Null: NO  
  \- Default: now()  
  \- คำอธิบาย: เวลาแก้ไขล่าสุด (เก็บ UTC)  
  \- ตัวอย่าง: 2025-01-01T03:00:00Z  
  \- PII: no

\- version  
  \- ชนิด: integer  
  \- Null: NO  
  \- Default: 1  
  \- คำอธิบาย: optimistic locking (ETag)  
  \- ตัวอย่าง: 2  
  \- PII: no

\- checkin\_time  
  \- ชนิด: timestamptz  
  \- Null: NO  
  \- Default: now()  
  \- คำอธิบาย: เวลาที่บันทึกเช็คอิน (index desc)  
  \- ตัวอย่าง: 2025-01-01T01:00:00Z  
  \- PII: no

\- source\_type  
  \- ชนิด: text  
  \- Null: NO  
  \- Default: 'cbm\_booking'  
  \- คำอธิบาย: แหล่งที่มาของเช็คอิน (Canonical)  
  \- ตัวอย่าง: cbm\_booking  
  \- PII: no

\- cbm\_id  
  \- ชนิด: varchar(15)  
  \- Null: YES  
  \- Default: NULL  
  \- คำอธิบาย: รหัส CBM booking (upstream) — ตรวจรูปแบบ  
  \- ตัวอย่าง: CBM-2025-0000001  
  \- PII: no

\- quota\_id  
  \- ชนิด: varchar(64)  
  \- Null: YES  
  \- Default: NULL  
  \- คำอธิบาย: โควต้าอ้างอิง  
  \- ตัวอย่าง: QUOTA-01  
  \- PII: no

\- plate\_no  
  \- ชนิด: varchar(32)  
  \- Null: YES  
  \- Default: NULL  
  \- คำอธิบาย: ป้ายทะเบียน  
  \- ตัวอย่าง: 1กข1234  
  \- PII: no

\- driver\_name  
  \- ชนิด: varchar(200)  
  \- Null: YES  
  \- Default: NULL  
  \- คำอธิบาย: ชื่อคนขับ  
  \- ตัวอย่าง: สมชาย ตัวอย่าง  
  \- PII: yes (ชื่อ) — apply masking in UI/logs per RBAC

\- driver\_phone  
  \- ชนิด: varchar(16)  
  \- Null: YES  
  \- Default: NULL  
  \- คำอธิบาย: เบอร์โทรศัพท์ (รูปแบบ ^0\\d{8,9}$)  
  \- ตัวอย่าง: 0812345678  
  \- PII: yes (phone) — mask in API/UI except for permitted roles

\- coin\_number  
  \- ชนิด: varchar(12)  
  \- Null: NO  
  \- Default: ''  
  \- คำอธิบาย: หมายเลขเหรียญ/คิว (max 12\) — unique when active  
  \- ตัวอย่าง: CN001  
  \- PII: no

\- entry\_channel  
  \- ชนิด: varchar(64)  
  \- Null: YES  
  \- Default: NULL  
  \- คำอธิบาย: ช่องทางเข้า เช่น gate\_a  
  \- ตัวอย่าง: gate\_a  
  \- PII: no

\- payment\_type\_1st  
  \- ชนิด: text  
  \- Null: YES  
  \- Default: NULL  
  \- คำอธิบาย: ประเภทการชำระหลัก (green\_bill|white\_bill)  
  \- ตัวอย่าง: green\_bill  
  \- PII: no

\- payment\_type\_2nd  
  \- ชนิด: text  
  \- Null: YES  
  \- Default: NULL  
  \- คำอธิบาย: ประเภทการชำระรอง (green\_bill|white\_bill)  
  \- ตัวอย่าง: white\_bill  
  \- PII: no

\- debt\_payment\_percent  
  \- ชนิด: integer  
  \- Null: YES  
  \- Default: NULL  
  \- คำอธิบาย: เปอร์เซ็นต์ชำระหนี้ (0..100) — required for member\_no\_booking; must be NULL for guest\_pool  
  \- ตัวอย่าง: 30  
  \- PII: no

\- status  
  \- ชนิด: text  
  \- Null: NO  
  \- Default: 'checked\_in'  
  \- คำอธิบาย: checked\_in | awaiting\_payment | completed | voided  
  \- ตัวอย่าง: awaiting\_payment  
  \- PII: no

\- guest\_flag  
  \- ชนิด: boolean  
  \- Null: NO  
  \- Default: false  
  \- คำอธิบาย: แสดงว่าเป็น guest\_pool  
  \- ตัวอย่าง: false  
  \- PII: no

\- notes  
  \- ชนิด: text  
  \- Null: YES  
  \- Default: NULL  
  \- คำอธิบาย: หมายเหตุ  
  \- ตัวอย่าง: จาก QR scan  
  \- PII: may contain PII (mask in logs)

\- created\_by / updated\_by / voided\_by  
  \- ชนิด: varchar(64)  
  \- Null: created\_by NO, others YES  
  \- Default: created\_by 'system'  
  \- คำอธิบาย: actor id (user)  
  \- ตัวอย่าง: user\_1001  
  \- PII: yes (user id) — audit only

\- voided\_at  
  \- ชนิด: timestamptz  
  \- Null: YES  
  \- Default: NULL  
  \- คำอธิบาย: เวลา void  
  \- ตัวอย่าง: 2025-01-01T03:30:00Z

\- void\_reason  
  \- ชนิด: text  
  \- Null: YES  
  \- Default: NULL  
  \- คำอธิบาย: เหตุผล void (จาก API)  
  \- ตัวอย่าง: ผิดทะเบียน \- คืนเหรียญ

PII / Masking note: driver\_phone และ driver\_name เป็น PII — ต้อง masking ใน API/UI ตาม RBAC; logs ต้องหลีกเลี่ยงเก็บ plaintext หรือ apply redaction.

\---

\#\# 10.4 Enums & Patterns  
\- status: allowed values TEXT \+ CHECK  
  \- ('checked\_in','awaiting\_payment','completed','voided')  
\- source\_type: TEXT \+ CHECK  
  \- ('cbm\_booking','member\_no\_booking','guest\_pool')  
\- payment types: TEXT \+ CHECK  
  \- ('green\_bill','white\_bill')  
\- Patterns (regex):  
  \- checkin id: ^CHK-\\d{4}-\\d{6}$ (e.g., CHK-2025-000001)  
  \- cbm id: ^CBM-\\d{4}-\\d{7}$ (e.g., CBM-2025-0000001)  
  \- driver\_phone: ^0\\d{8,9}$ (e.g., 0812345678\)  
  \- coin\_number: .{1,12} (non-empty, max 12\)  
\- Implementation: เก็บเป็น TEXT/VARCHAR ใน DB \+ CHECK constraints (ไม่ใช้ Postgres ENUM)

\---

\#\# 10.5 Conflict Log & Candidate Fields  
\- Conflict: Short-ID Policy (ต้องเป็น \<PREFIX\>-\<SEQ\> ด้วย sequence default digits\_len=10) vs Feature-provided checkin\_id pattern ^CHK-\\d{4}-\\d{6}$    
  \- ตัดสินใจ: ปฏิบัติตาม pattern ของฟีเจอร์ (CHK-YYYY-\#\#\#\#\#\#) เพื่อสอดคล้องกับ Canonical/API ที่ให้รูปแบบนี้เป็นข้อบังคับและตัวอย่างข้อมูลจริง    
  \- ผลกระทบ: Public ID generator ใช้ sequence \+ current year \+ 6-digit padding (sequence width=6) แทนการใช้ default digits\_len=10 ของ short-id policy — บันทึกไว้ที่นี่  
\- Mapping note: API ใช้ \`checkin\_id\` ใน payloads/paths → แมปกับ DB column \`id\` (public id). \`row\_id\` เป็น PK ภายในและใช้เป็น FK อ้างอิงภายในเท่านั้น (API ยอมรับ/แสดง public id)  
\- Candidate fields (จาก API แต่ไม่เป็นธุรกิจหลักใน DB หรือเป็นฟิลด์ชั่วคราว):  
  \- entry\_channel (ได้รับจาก API examples) — รวมใน schema (string)  
  \- released\_coin\_number (ใน Void response) — ไม่เก็บแยกเป็นคอลัมน์; คำนวณ/อ่านจาก coin\_number และ voided\_at; response ส่ง value จาก coin\_number ก่อน void  
\- Assumptions:  
  \- เก็บเวลาใน DB เป็น UTC (timestamptz) — application layer แปลงเป็น \+07:00 และแสดงเป็น พ.ศ. ตาม UI requirement    
  \- CBM booking ไม่ถูกทำซ้ำใน DB — แค่เก็บ cbm\_id โดยมีรูปแบบตรวจสอบ; การตรวจสอบความ dispatch ของ CBM ต้องกระทำโดยเรียก upstream /api/cbm/bookings?status=dispatch ก่อนการสร้างเช็คอิน (แอพเลเยอร์)    
  \- Void reason ถูกเก็บใน \`void\_reason\`; การอนุมัติ Void โดย Logistics Supervisor หากจำเป็น จะจัดทำเป็น workflow แยกภายหลัง (not in this scope)  
  \- created\_by/updated\_by เป็น user identifier string — ไม่มี FK ไปยังตาราง users ภายใน (out of scope)  
  \- ETag generation: เบื้องต้นมาจาก \`version\` (integer) — server เปลี่ยนเวอร์ชันเมื่อ PATCH/VOID สำเร็จ  
\- Mapping differences logged:  
  \- API path uses \`checkin\_id\` (CHK-YYYY-\#\#\#\#\#\#) → DB \`id\` varchar(15) WITH CHECK regex  
  \- Short-ID policy sequence width overridden to 6 to match pattern → documented

\---

\#\# 10.6 Data Lineage & Integration Notes  
\- แหล่งข้อมูล:  
  \- CBM bookings: upstream system — แหล่งความจริงของ booking/detail/status — อ่านผ่าน GET /api/cbm/bookings?status=dispatch; เมื่อสร้าง checkin สำหรับ CBM ต้อง PATCH /api/cbm/bookings/{cbm\_id}/status เพื่อ set phase\_cut\_transport='awaiting\_payment'  
  \- Payment system: เป็น authoritative สำหรับการเปลี่ยน awaited → completed — ไม่ persist payment result ซ้ำใน cane\_checkins (แค่ update status → completed เมื่อ callback ยืนยัน)  
  \- QR Scanner, EventBus: รับ input/emit event \`cane.checkin.created\`, \`cane.checkin.voided\` — EventBus ใช้สำหรับ downstream (e.g., Payment, Reporting)  
\- Single source decisions:  
  \- Booking details: ไม่สำเนา CBM booking ข้ามระบบ — เก็บเพียง cbm\_id \+ prefill data (plate\_no, driver\_name, driver\_phone, quota\_id, notes) แต่หากต้องการข้อมูลครบควรเรียก upstream เมื่อแสดงรายละเอียด  
  \- Coin availability: authority \= this service (cane\_checkins) — uniqueness constraint enforced here and used as source for availability checks  
\- Views / read models:  
  \- สร้าง materialized view / read API ที่ join กับ external cached CBM info ถ้าต้องการแสดงรายละเอียด booking — ไม่รวมในปัจจุบัน  
\- Transactional side-effects:  
  \- เมื่อสร้าง checkin (source\_type \= cbm\_booking) ภายใน transaction/flow ต้อง:  
    1\) Validate CBM status \= dispatch (via upstream GET or prior cached state)  
    2\) Insert cane\_checkins row (reserve coin\_number)  
    3\) PATCH upstream CBM: { "phase\_cut\_transport": "awaiting\_payment" } — หาก upstream PATCH ล้มเหลว ต้อง rollback local insert (transaction across systems; use compensating actions or two-phase commit pattern; at minimum, ensure idempotency and compensating void)  
\- Audit:  
  \- ทุกการ create/patch/void ต้องบันทึก created\_by/updated\_by/voided\_by และ version เพื่อการตรวจสอบ (audit trail)

\---