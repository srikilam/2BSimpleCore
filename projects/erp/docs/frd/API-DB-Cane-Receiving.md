\#\# 8\) API Endpoints    
Base URL: \`\<base\_url\>\`    
Base Path: \`/agri/cane-receiving\`

| Method | Path | Use case | Notes |  
|---|---:|---|---|  
| GET | /api/cane-receivings | ดึงรายการการรับอ้อย (List / filter / pagination) | Headers: Authorization; Query filters: q,date\_from,date\_to,source\_type,status,checkin\_id,weigh\_coin,page,page\_size,sort; response: items\[\]; Page \= Receiving List · Journey \= view:list / \#1–\#4 |  
| GET | /api/cane-receivings/{receiving\_id} | ดึงรายละเอียดใบรับอ้อย (Detail) | Headers: Authorization, If-None-Match (optional); returns ReceivingNote; Page \= Receiving Detail · Journey \= view:detail / \#5 |  
| POST | /api/cane-receivings | สร้าง / ออกใบรับอ้อย (Issue) | Headers: Authorization, X-Idempotency-Key (required); idempotent; triggers side-effects (generate PDF, PATCH CBM, POST weigh-coin/free); Page \= Issue Receiving Drawer · Journey \= Issue (\#1/\#2/\#3/\#4) |  
| POST | /api/cane-receivings/{receiving\_id}/void | ยกเลิกใบรับอ้อย (Void) | Headers: Authorization, If-Match (required), X-Trace-Id (optional); returns updated status; Page \= Receiving Detail, Void Modal · Journey \= Void (\#5) |  
| POST | /api/cane-receivings/{receiving\_id}/pdf | สร้าง/ดาวน์โหลด PDF ของใบรับอ้อย | Headers: Authorization; may be triggered by server on create or by client; Page \= Detail / Issue Drawer · Journey \= \#1–\#4 |  
| GET | /api/cane-receivings/export | Export CSV (ตาม Filters, RBAC) | Headers: Authorization; Query filters same as list; synchronous CSV download (per page defs); Page \= Receiving List · Journey \= N/A (export action) |  
| POST | /api/scan/resolve | Resolve QR payload → checkin\_id หรือ receiving\_id | Headers: Authorization; Body: { qr\_payload }; Page \= QR Scanner Overlay · Journey \= Scan (\#6) |  
| GET | /ext/factory/dump | ดึงผลการเทจากโรงงาน (external) | Query: quota\_id?,date(ISO),weigh\_coin; returns FactoryDumpResult; used by Issue Drawer (auto fetch); Journey \= \#1/\#2/\#3/\#4 |  
| GET | /api/checkins/{checkin\_id} | ดึง snapshot ของ Check-in (prefill Issue Drawer) | Headers: Authorization; read-only CheckinRef fields (booking\_type, booking\_id, payment\_prefs); Page \= Issue Receiving Drawer · Journey \= \#1–\#4 |  
| PATCH | /api/cbm/{booking\_id}/status | (Outbound) อัพเดตสถานะ CBM (awaiting\_payment / awaiting\_dump\_result) | Headers: Authorization; triggered as side-effect on Issued / Void; note possible 409 CBM\_STATUS\_CONFLICT; Journey side-effect: \#1/\#2 (Issued) & \#5 (Void) |  
| POST | /api/weigh-coin/free | (Outbound) ปลดเลขเหรียญชั่ง (free coin) | Headers: Authorization; Body: { weigh\_coin }; possible 409 COIN\_ALREADY\_FREED; Journey side-effect on Issued |

\---

\#\#\# 8.1 List — \`GET /api/cane-receivings\`  
Traceability: Page \= \`Receiving List\` · Action \= \`view:list\` · Journey \= \`\#1/\#2/\#3/\#4\`    
Headers (required/optional): Authorization: Bearer \<token\>

Query params:  
| Name | Type | Req | Default | Description |  
|---|---:|---:|---|---|  
| q | string | no | — | ค้นหาข้อความ (plate / driver\_phone / source\_ref / weigh\_coin) |  
| date\_from | string (ISO-8601) | no | — | วันที่เริ่ม (checkin\_date) |  
| date\_to | string (ISO-8601) | no | — | วันที่สิ้นสุด (checkin\_date) |  
| source\_type | enum | no | — | one\_of \[CBM, NBM, CENTRAL\] |  
| status | enum | no | — | one\_of \[draft, issued, void\] (canonical input allowed) |  
| checkin\_id | string | no | — | กรองด้วย checkin\_id |  
| weigh\_coin | integer | no | — | กรองด้วย weigh\_coin |  
| page | integer | no | 1 | หน้าที่ต้องการ |  
| page\_size | integer | no | 25 | ขนาดหน้า |  
| sort | string | no | \-updated\_at | ตัวอย่าง: \-updated\_at, created\_at |

\#\#\#\# Request  
(no body; filters via query)

\#\#\#\# Response (success):  
\`\`\`json  
{  
  "items": \[  
    {  
      "receiving\_id": "CRN-2025-00001",  
      "source\_type": "CBM",  
      "source\_ref": "CBM-12345",  
      "checkin\_id": "CHK-0001",  
      "checkin\_time": "2025-11-10T07:15:00Z",  
      "weigh\_coin": 12345,  
      "dump\_fetch\_mode": "auto",  
      "ccs": 11.25,  
      "net\_weight\_kg": 1250.50,  
      "status": "Draft",  
      "issued\_at": null,  
      "issued\_by": null,  
      "pdf\_url": null  
    }  
  \],  
  "page": 1,  
  "page\_size": 25,  
  "total": 102  
}  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "unauthorized", "message": "Authentication required", "details": \[\], "trace\_id": "..." }  
\`\`\`

\---

\#\#\# 8.2 Detail — \`GET /api/cane-receivings/{receiving\_id}\`  
Traceability: Page \= \`Receiving Detail\` · Action \= \`view:detail\` · Journey \= \`\#5\`    
Headers (required/optional): Authorization: Bearer \<token\> · If-None-Match: "\<etag\>" (optional)

Query params: none

\#\#\#\# Request  
(no body)

\#\#\#\# Response (success):  
\`\`\`json  
{  
  "receiving\_id": "CRN-2025-00001",  
  "source\_type": "CBM",  
  "source\_ref": "CBM-12345",  
  "checkin\_id": "CHK-0001",  
  "checkin\_time": "2025-11-10T07:15:00Z",  
  "weigh\_coin": 12345,  
  "dump\_fetch\_mode": "auto",  
  "ccs": 11.25,  
  "net\_weight\_kg": 1250.50,  
  "status": "Issued",  
  "issued\_at": "2025-11-10T08:00:00Z",  
  "issued\_by": "user\_102",  
  "voided\_at": null,  
  "voided\_by": null,  
  "void\_reason": null,  
  "pdf\_url": "https://obj.example/pdfs/CRN-2025-00001.pdf",  
  "audit": {  
    "created\_at": "2025-11-10T08:00:00Z",  
    "created\_by": "user\_102",  
    "etag": "W/\\"v1-9\\""  
  }  
}  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "not\_found", "message": "receiving not found", "details": \[\], "trace\_id": "..." }  
\`\`\`

\---

\#\#\# 8.3 Create / Issue Receiving — \`POST /api/cane-receivings\`  
Traceability: Page \= \`Issue Receiving Drawer\` · Action \= \`issue:create\` · Journey \= \`\#1/\#2/\#3/\#4\`    
Headers (required/optional): Authorization: Bearer \<token\> · X-Idempotency-Key: "\<idempotency\_key\>" (required) · X-Trace-Id (optional)

\#\#\#\# Request:  
\`\`\`json  
{  
  "checkin\_id": "CHK-0001",  
  "source\_type": "CBM",  
  "source\_ref": "CBM-12345",  
  "weigh\_coin": 12345,  
  "dump\_fetch\_mode": "auto",  
  "ccs": 11.25,  
  "net\_weight\_kg": 1250.50,  
  "issuing\_by": "user\_102"  
}  
\`\`\`  
Notes:  
\- If dump\_fetch\_mode="auto" and external fetch succeeded, ccs/net\_weight\_kg may be supplied by server; when manual, ccs & net\_weight\_kg required.  
\- ccs: decimal(5,2); net\_weight\_kg: decimal(10,2); non-negative.

\#\#\#\# Response (success — 201):  
\`\`\`json  
{  
  "receiving\_id": "CRN-2025-00001",  
  "status": "Issued",  
  "issued\_at": "2025-11-10T08:00:00Z",  
  "issued\_by": "user\_102",  
  "pdf\_url": "https://obj.example/pdfs/CRN-2025-00001.pdf"  
}  
\`\`\`

Side-effects (server or orchestrator):  
\- POST /api/weigh-coin/free { "weigh\_coin": 12345 }  
\- PATCH /api/cbm/CBM-12345/status { "status": "awaiting\_payment" } (for CBM)  
\- Emit event: cane\_receiving.issued

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "ccs\_or\_weight\_invalid", "message": "ccs must have 2 decimal places and non-negative", "details": \[ { "field": "ccs", "message": "invalid format" } \], "trace\_id": "..." }  
\`\`\`  
Or  
\`\`\`json  
{ "code": "coin\_already\_freed", "message": "weigh coin already freed", "details": \[\], "trace\_id": "..." }  
\`\`\`

\---

\#\#\# 8.4 Void Receiving — \`POST /api/cane-receivings/{receiving\_id}/void\`  
Traceability: Page \= \`Receiving Detail\` · Action \= \`void:confirm\` · Journey \= \`\#5\`    
Headers (required/optional): Authorization: Bearer \<token\> · If-Match: "\<etag\>" (required) · X-Trace-Id (optional)

\#\#\#\# Request:  
\`\`\`json  
{  
  "void\_reason": "ข้อมูลน้ำหนักผิดพลาด \- ยกเลิกเพื่อสร้างใหม่"  
}  
\`\`\`

\#\#\#\# Response:  
\`\`\`json  
{  
  "receiving\_id": "CRN-2025-00001",  
  "status": "Void",  
  "voided\_at": "2025-11-11T09:00:00Z",  
  "voided\_by": "user\_201",  
  "void\_reason": "ข้อมูลน้ำหนักผิดพลาด \- ยกเลิกเพื่อสร้างใหม่"  
}  
\`\`\`

Side-effects:  
\- PATCH /api/cbm/CBM-12345/status { "status": "awaiting\_dump\_result" }  
\- Emit event: cane\_receiving.void

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "void\_not\_allowed", "message": "document linked to Payment, cannot void", "details": \[\], "trace\_id": "..." }  
\`\`\`  
Or  
\`\`\`json  
{ "code": "precondition\_failed", "message": "ETag mismatch", "details": \[\], "trace\_id": "..." }  
\`\`\`

\---

\#\#\# 8.5 Generate / Print PDF — \`POST /api/cane-receivings/{receiving\_id}/pdf\`  
Traceability: Page \= \`Receiving Detail\` / \`Issue Receiving Drawer\` · Action \= \`print:pdf\` · Journey \= \`\#1/\#2/\#5\`    
Headers (required/optional): Authorization: Bearer \<token\> · X-Trace-Id (optional)

\#\#\#\# Request:  
\`\`\`json  
{}  
\`\`\`

\#\#\#\# Response:  
\`\`\`json  
{  
  "receiving\_id": "CRN-2025-00001",  
  "pdf\_url": "https://obj.example/pdfs/CRN-2025-00001.pdf"  
}  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "server\_error", "message": "failed to generate pdf", "details": \[\], "trace\_id": "..." }  
\`\`\`

\---

\#\#\# 8.6 Export CSV — \`GET /api/cane-receivings/export\`  
Traceability: Page \= \`Receiving List\` · Action \= \`export:csv\` · Journey \= N/A    
Headers (required/optional): Authorization: Bearer \<token\>

Query params: same as list filters (q,date\_from,date\_to,source\_type,status,...)

Behavior:  
\- Synchronous CSV download (200 with text/csv) if result set reasonable.  
\- RBAC: export allowed only when user has export permission.

Response: CSV stream (Content-Type: text/csv) — example not shown as JSON.

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "forbidden", "message": "export not allowed for this user", "details": \[\], "trace\_id": "..." }  
\`\`\`

\---

\#\#\# 8.7 Resolve QR — \`POST /api/scan/resolve\`  
Traceability: Page \= \`QRCodeScannerOverlay\` · Action \= \`scan:resolve\` · Journey \= \`\#6\`    
Headers (required/optional): Authorization: Bearer \<token\> · X-Trace-Id (optional)

\#\#\#\# Request:  
\`\`\`json  
{  
  "qr\_payload": "CHK:CHK-0001"  
}  
\`\`\`

\#\#\#\# Response (success — resolves to checkin):  
\`\`\`json  
{  
  "checkin\_id": "CHK-0001",  
  "resolved\_type": "checkin"  
}  
\`\`\`  
Or (if already issued):  
\`\`\`json  
{  
  "receiving\_id": "CRN-2025-00001",  
  "resolved\_type": "receiving"  
}  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "not\_found", "message": "qr payload could not be resolved", "details": \[\], "trace\_id": "..." }  
\`\`\`

\---

\#\#\# 8.8 Factory Dump Fetch (external) — \`GET /ext/factory/dump\`  
Traceability: Page \= \`Issue Receiving Drawer\` · Action \= \`dump:fetch\_auto\` · Journey \= \`\#1/\#2/\#3/\#4\`    
Headers (required/optional): Authorization: Bearer \<token\> (as applicable to integration) · X-Trace-Id (optional)

Query params:  
| Name | Type | Req | Default | Description |  
|---|---:|---:|---|---|  
| quota\_id | string | no | — | ใช้สำหรับ CBM/NBM ถ้ามี |  
| date | string (ISO-8601) | yes | — | checkin\_date |  
| weigh\_coin | integer | yes | — | เลขเหรียญชั่ง |

\#\#\#\# Response:  
\`\`\`json  
{  
  "quota\_id": "QTA-0001",  
  "checkin\_date": "2025-11-10",  
  "weigh\_coin": 12345,  
  "ccs": 11.25,  
  "net\_weight\_kg": 1250.50,  
  "fetched\_at": "2025-11-10T07:20:00Z",  
  "fetch\_status": "success"  
}  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "factory\_result\_not\_found", "message": "no dump result", "details": \[\], "trace\_id": "..." }  
\`\`\`  
Or  
\`\`\`json  
{ "code": "factory\_result\_mismatch", "message": "lookup key mismatch", "details": \[\], "trace\_id": "..." }  
\`\`\`

\---

\#\#\# 8.9 Check-in Snapshot — \`GET /api/checkins/{checkin\_id}\`  
Traceability: Page \= \`Issue Receiving Drawer\` · Action \= \`prefill:checkin\` · Journey \= \`\#1/\#2/\#3/\#4\`    
Headers (required/optional): Authorization: Bearer \<token\>

\#\#\#\# Response:  
\`\`\`json  
{  
  "checkin\_id": "CHK-0001",  
  "booking\_type": "CBM",  
  "booking\_id": "CBM-12345",  
  "payment\_prefs": {  
    "method": "bank\_transfer",  
    "account": "xxxx-\*\*\*\*"  
  },  
  "farmer\_name": "นายสมชาย",  
  "driver\_name": "คนขับ A",  
  "driver\_phone": "+66-8-1234-5678",  
  "license\_plate": "กข-1234",  
  "weigh\_coin": 12345,  
  "checkin\_time": "2025-11-10T07:15:00Z"  
}  
\`\`\`

\---

\#\#\# 8.10 CBM Status Patch (outbound) — \`PATCH /api/cbm/{booking\_id}/status\`  
Traceability: Side-effect of Issue/Void (server) · Journey \= \`\#1/\#2\` (Issued) & \`\#5\` (Void)    
Headers (required/optional): Authorization: Bearer \<token\> · X-Trace-Id (optional)

\#\#\#\# Request:  
\`\`\`json  
{ "status": "awaiting\_payment" }  
\`\`\`

\#\#\#\# Response:  
\`\`\`json  
{ "booking\_id": "CBM-12345", "status": "awaiting\_payment", "updated\_at": "2025-11-10T08:00:05Z" }  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "cbm\_status\_conflict", "message": "target status not allowed", "details": \[\], "trace\_id": "..." }  
\`\`\`

\---

\#\#\# 8.11 Weigh-Coin Free (outbound) — \`POST /api/weigh-coin/free\`  
Traceability: Side-effect of Issue (server) · Journey \= \`\#1/\#2/\#3/\#4\`    
Headers (required/optional): Authorization: Bearer \<token\> · X-Trace-Id (optional)

\#\#\#\# Request:  
\`\`\`json  
{ "weigh\_coin": 12345 }  
\`\`\`

\#\#\#\# Response:  
\`\`\`json  
{ "weigh\_coin": 12345, "status": "freed", "freed\_at": "2025-11-10T08:00:06Z" }  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "coin\_already\_freed", "message": "weigh coin already freed", "details": \[\], "trace\_id": "..." }  
\`\`\`

\---

\# 9\. API Contract — Notes & Conventions

9.1 Security & Headers    
\- Authorization: Bearer \<JWT token\> (ทั้งหมดต้องมี Authorization unless explicitly public). RBAC/Scopes ตรวจสิทธิ์บน backend ตาม role mapping (Receiving Staff / Supervisor / Viewer / Admin).    
\- Required headers by operation:  
  \- POST /api/cane-receivings: X-Idempotency-Key (ต้องใส่)    
  \- POST /api/cane-receivings/{id}/void: If-Match (ETag) (ต้องใส่)    
  \- All calls: X-Trace-Id (optional, recommended) เพื่อ observability/audit.    
\- ETag ใน GET detail response: ส่ง header ETag (เช่น W/"v1-9") เพื่อใช้กับ If-Match บนคำสั่งเปลี่ยนสถานะ/void.

9.2 Error Model & Codes    
\- ใช้ HTTP statuses: 200/201/202, 400, 401, 403, 404, 409, 412, 422, 429, 500 ตามบริบท.    
\- รูปแบบ error กลาง:  
\`\`\`json  
{ "code": "string", "message": "string", "details": \[ { "field": "string", "message": "string" } \], "trace\_id": "string" }  
\`\`\`  
\- ข้อผิดพลาดโดเมนที่นิยาม:  
  \- 404 FACTORY\_RESULT\_NOT\_FOUND — external dump not found    
  \- 409 FACTORY\_RESULT\_MISMATCH — lookup key mismatch    
  \- 422 CCS\_OR\_WEIGHT\_INVALID — invalid decimal format / negative    
  \- 409 CBM\_STATUS\_CONFLICT — CBM target status invalid    
  \- 409 COIN\_ALREADY\_FREED — weigh-coin already freed    
  \- 409 VOID\_NOT\_ALLOWED — document linked to payment    
\- UX guidance:  
  \- 412 Precondition Failed (ETag mismatch): แนะนำให้ client รีเฟรช resource และแสดง dialog ให้ user merge/refresh.    
  \- 409 ขัดแย้งเชิงธุรกรรม: แสดงข้อความไทยที่ชัดเจนและข้อแนะนำ (เช่น “มีการเปลี่ยนสถานะโดยผู้อื่น กรุณารีเฟรช”).

9.3 Rate Limits & Required Headers    
\- ค่าเริ่มต้นแนะนำ: 120 requests/min per consumer (ปรับตาม NFR/AWS limits).    
\- 429 responses ต้องมี Retry-After header (seconds).    
\- ต้องส่ง X-Idempotency-Key สำหรับ POST ที่อาจ retry (create/issue, bulk actions).    
\- ต้องส่ง If-Match สำหรับการเปลี่ยนสถานะที่มี concurrency sensitivity (void).

9.4 Idempotency & Concurrency    
\- POST /api/cane-receivings ต้อง idempotent ตาม X-Idempotency-Key — server จะคืน resource เดิมเมื่อมี key เดียวกันกับ payload ที่เทียบเท่า.    
\- If-Match/ETag: PUT/PATCH/POST that changes state (void) ต้องใช้ If-Match; หาก mismatch → 412\.    
\- Conflict vs Precondition:  
  \- 409 ใช้เมื่อ domain conflict (CBM status conflict, coin freed, void not allowed).    
  \- 412 ใช้เมื่อ ETag mismatch (concurrent edit).    
\- Retry/backoff: client ควรใช้ exponential backoff (มี NFR: retry ext/factory/dump 3 ครั้ง) สำหรับ network/5xx, พิจารณาไม่ retry on 4xx except idempotent-safe cases.    
\- เมื่อเจอ 412: client flow — fetch latest GET /api/cane-receivings/{id}, show merge dialog, then retry with updated If-Match.

9.5 Example Requests (cURL)  
\- List (มี filters):  
\`\`\`bash  
curl \-H "Authorization: Bearer \<token\>" "\<base\_url\>/api/cane-receivings?q=กข-1234\&date\_from=2025-11-01\&date\_to=2025-11-12\&page=1\&page\_size=25"  
\`\`\`  
\- Create (Issue) — ใส่ X-Idempotency-Key:  
\`\`\`bash  
curl \-X POST "\<base\_url\>/api/cane-receivings" \\  
  \-H "Authorization: Bearer \<token\>" \\  
  \-H "X-Idempotency-Key: abc123-issue-0001" \\  
  \-H "Content-Type: application/json" \\  
  \-d '{"checkin\_id":"CHK-0001","weigh\_coin":12345,"dump\_fetch\_mode":"manual","ccs":11.25,"net\_weight\_kg":1250.50,"issuing\_by":"user\_102"}'  
\`\`\`  
\- Void (If-Match required):  
\`\`\`bash  
curl \-X POST "\<base\_url\>/api/cane-receivings/CRN-2025-00001/void" \\  
  \-H "Authorization: Bearer \<token\>" \\  
  \-H 'If-Match: "W/\\"v1-9\\""' \\  
  \-H "Content-Type: application/json" \\  
  \-d '{"void\_reason":"ข้อมูลน้ำหนักผิดพลาด \- ยกเลิกเพื่อสร้างใหม่"}'  
\`\`\`  
\- Resolve QR (scanner):  
\`\`\`bash  
curl \-X POST "\<base\_url\>/api/scan/resolve" \\  
  \-H "Authorization: Bearer \<token\>" \\  
  \-H "Content-Type: application/json" \\  
  \-d '{"qr\_payload":"CHK:CHK-0001"}'  
\`\`\`  
\- Patch CBM status (outbound from server; example client for test):  
\`\`\`bash  
curl \-X PATCH "\<base\_url\>/api/cbm/CBM-12345/status" \\  
  \-H "Authorization: Bearer \<token\>" \\  
  \-H "Content-Type: application/json" \\  
  \-d '{"status":"awaiting\_payment"}'  
\`\`\`

9.6 Notes (Integrations & Export)  
\- Export: per Page Definitions เป็น synchronous CSV via GET /api/cane-receivings/export ตาม filters; ensure RBAC check before returning CSV. ถ้าข้อมูลใหญ่เกินไป ให้เปลี่ยนเป็น async job (202 \+ job id \+ polling) — แต่ในปัจจุบัน spec ระบุ synchronous.    
\- Outbound integrations (side-effects) — server must ensure or compensate:  
  \- PATCH /api/cbm/{booking\_id}/status called when Issued → awaiting\_payment; when Void → awaiting\_dump\_result. ตรวจจับ 409 CBM\_STATUS\_CONFLICT และ surface error to user / alert ops.    
  \- POST /api/weigh-coin/free called when Issued. ตรวจสอบ 409 COIN\_ALREADY\_FREED และ handle idempotency.    
\- Inbound integrations:  
  \- GET /ext/factory/dump retry policy: 3 attempts (exponential backoff) ตาม NFR; failures should surface to UI to allow manual mode.    
  \- POST /api/scan/resolve returns either checkin\_id หรือ receiving\_id — client must handle both.    
\- Events / Webhooks: ควร emit cane\_receiving.issued และ cane\_receiving.void (payload includes receiving\_id, actor, timestamp, booking\_id, ccs, net\_weight\_kg, dump\_fetch\_mode). หากมี event bus/webhook system ให้ลงทะเบียน events เหล่านี้.    
\- PII / Masking: เมื่อส่งข้อมูล driver\_phone หรือ account info ใน payment\_prefs ให้ mask to appropriate level in list responses (e.g., \+66-8-1234-\*\*\*\*) และให้ full in detail only when user authorized.    
\- PDFs and audit: เก็บ pdf\_url ใน durable object storage; audit log ต้องบันทึก actor, timestamp, ETag, dump\_fetch\_mode, ccs, net\_weight\_kg, booking\_id.    
\- Warnings / Assumptions:  
  \- ไม่มี rollback policy ชัดเจนเมื่อ side-effects บางรายการล้มเหลว (เช่น PDF OK แต่ PATCH CBM fail). แนะนำออกแบบ compensating transactions or reconciliation job.    
  \- การตรวจสอบว่ามีการผูก Payment อยู่หรือไม่ (เพื่อป้องกัน Void) ต้องมี API/flag ภายในระบบ — หากยังไม่มีกำหนด ให้ treat as precondition and return 409 VOID\_NOT\_ALLOWED when detected.

\---

\#\# 10.0 Data Schema

\#\#\# 10.0.1 ภาพรวมเอนทิตี (Entity Overview)  
\- receiving\_notes — เก็บใบรับอ้อย (Receiving Note) เป็นแหล่งอำนาจเดียวสำหรับสถานะการรับอ้อยและค่าทางน้ำหนัก (ccs, net\_weight\_kg) พร้อม snapshot ของ check-in ที่เกี่ยวข้อง; มีความสัมพันธ์ 1:N → factory\_dump\_results    
\- factory\_dump\_results — บันทึกผลการเทจากโรงงาน (Factory Dump Result) เป็น log/runtime result ที่สามารถผูกกับ receiving\_note (nullable) เพื่อ audit และการตรวจสอบความถูกต้อง    
\- checkin\_ref — แหล่งข้อมูลภายนอก (read-only snapshot จากบริการ Check-in); ไม่ persist เป็นตารางแยก (snapshot ถูกเก็บเป็น JSONB ใน receiving\_notes เมื่อจำเป็น)

\#\#\# 10.0.2 สคีมาตามตาราง

\#\#\# ตาราง receiving\_notes — ใบรับอ้อย (Cane Receiving Note)  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`CRN-YYYY-NNNNN\`) — UNIQUE    
\- UK: \`uq\_receiving\_notes\_id (id)\`    
\- FK: (none referencing other local tables) — เก็บ \`checkin\_id\` เป็น external reference string → external checkin service    
\- Parent-of: factory\_dump\_results (one-to-many) / Child-of: —  

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---|---|---:|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | PK | คีย์ภายใน (ไม่เปิดเผยผ่าน API) |  
| id | varchar(14) | UNIQUE | NO | trigger | CHECK (id \~ '^CRN-\\d{4}-\\d{5}$') | UNIQUE | รหัสสั้นอ่านง่าย (CRN-YYYY-NNNNN) — แมปเป็น API field \`receiving\_id\` |  
| created\_at | timestamptz | \- | NO | now() | \- | idx\_receiving\_notes\_status\_updated\_at (part) | วันที่สร้าง (เก็บเป็น timestamptz; presentation เป็น Asia/Bangkok) |  
| updated\_at | timestamptz | \- | NO | now() | \- | idx\_receiving\_notes\_status\_updated\_at (part) | วันที่แก้ไขล่าสุด |  
| version | integer | \- | NO | 1 | CHECK (version \> 0\) | \- | optimistic locking (ใช้ร่วมกับ ETag/If-Match) |  
| status | text | \- | NO | 'Draft' | CHECK (status IN ('Draft','Issued','Void')) | idx\_receiving\_notes\_status\_updated\_at | สถานะธุรกิจ canonical |  
| source\_type | text | \- | NO | 'CBM' | CHECK (source\_type IN ('CBM','NBM','CENTRAL')) | idx\_receiving\_notes\_source\_type\_source\_ref | ประเภทแหล่งที่มา |  
| source\_ref | varchar(255) | \- | YES | NULL | \- | idx\_receiving\_notes\_source\_type\_source\_ref | external booking id (เช่น CBM-12345) |  
| checkin\_id | varchar(64) | \- | NO | NULL | CHECK (checkin\_id \<\> '') | idx\_receiving\_notes\_weigh\_coin\_checkin\_time | external checkin public id (e.g., CHK-0001) |  
| checkin\_time | timestamptz | \- | YES | NULL | \- | idx\_receiving\_notes\_weigh\_coin\_checkin\_time | เวลา check-in (จาก checkin snapshot) |  
| checkin\_snapshot | jsonb | \- | YES | NULL | \- | \- | snapshot ของข้อมูล checkin (farmer\_name, driver\_name, driver\_phone, license\_plate, payment\_prefs) — read-only in UI |  
| weigh\_coin | integer | \- | YES | NULL | CHECK (weigh\_coin \>= 0\) | idx\_receiving\_notes\_weigh\_coin\_checkin\_time | หมายเลขเหรียญชั่ง |  
| dump\_fetch\_mode | text | \- | NO | 'auto' | CHECK (dump\_fetch\_mode IN ('auto','manual')) | \- | โหมดดึงผลการเท (auto/manual) |  
| ccs | numeric(5,2) | \- | YES | NULL | CHECK (ccs \>= 0 AND ccs \= round(ccs::numeric,2)) | \- | CCS ค่า 2 ตำแหน่งทศนิยม |  
| net\_weight\_kg | numeric(10,2) | \- | YES | NULL | CHECK (net\_weight\_kg \>= 0 AND net\_weight\_kg \= round(net\_weight\_kg::numeric,2)) | \- | น้ำหนักสุทธิ (กก.) 2 ตำแหน่งทศนิยม |  
| issued\_at | timestamptz | \- | YES | NULL | \- | idx\_receiving\_notes\_status\_updated\_at | เวลาออกใบ (เมื่อ status \= 'Issued') |  
| issued\_by | varchar(64) | \- | YES | NULL | \- | \- | ผู้ดำเนินการออกใบ (user id) |  
| voided\_at | timestamptz | \- | YES | NULL | \- | \- | เวลา void |  
| voided\_by | varchar(64) | \- | YES | NULL | \- | \- | ผู้ดำเนินการ void |  
| void\_reason | text | \- | YES | NULL | \- | \- | เหตุผลการ void |  
| pdf\_url | text | \- | YES | NULL | \- | \- | ลิงก์ไปยังไฟล์ PDF ใน object storage |  
| booking\_id | varchar(255) | \- | YES | NULL | \- | idx\_receiving\_notes\_source\_type\_source\_ref | (dup of source\_ref when source\_type=CBM/NBM) |  
| payment\_prefs | jsonb | \- | YES | NULL | \- | \- | snapshot ของ payment\_prefs (เฉพาะสำหรับ NBM; read-only in UI) |  
| deleted\_at | timestamptz | \- | YES | NULL | \- | \- | soft-delete (ถ้าจำเป็น) |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- API field \`receiving\_id\` ↔ DB \`id\` (public short id)    
\- API \`checkin\_id\` ↔ DB \`checkin\_id\` (string)    
\- API \`issuing\_by\` / \`issued\_by\` ↔ DB \`issued\_by\`    
\- API \`voided\_by\` / \`void\_reason\` ↔ DB \`voided\_by\`, \`void\_reason\`    
\- API \`ccs\` → DB \`ccs\` (numeric(5,2)); API input case-insensitive for enum values; server enforces canonical enum capitalization in DB.

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- row 1:  
  \- row\_id: 2f8b3f3a-7c2a-4b6e-9d3a-1c2b3a4d5e6f    
  \- id: CRN-2025-00001    
  \- created\_at: 2025-11-10T08:00:00+07:00    
  \- updated\_at: 2025-11-10T08:00:05+07:00    
  \- version: 1    
  \- status: Issued    
  \- source\_type: CBM    
  \- source\_ref: CBM-12345    
  \- checkin\_id: CHK-0001    
  \- checkin\_time: 2025-11-10T07:15:00+07:00    
  \- weigh\_coin: 12345    
  \- dump\_fetch\_mode: auto    
  \- ccs: 11.25    
  \- net\_weight\_kg: 1250.50    
  \- issued\_at: 2025-11-10T08:00:00+07:00    
  \- issued\_by: user\_102    
  \- pdf\_url: https://obj.example/pdfs/CRN-2025-00001.pdf

\- row 2 (Draft, manual):  
  \- row\_id: a3f1c2d4-...    
  \- id: CRN-2025-00002    
  \- status: Draft    
  \- dump\_fetch\_mode: manual    
  \- ccs: 0.00 (nullable until provided)    
  \- net\_weight\_kg: NULL

\---

\#\#\# ตาราง factory\_dump\_results — บันทึกผลการเทจากโรงงาน  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`FDR-0000000001\` style) — UNIQUE    
\- UK: \`uq\_factory\_dump\_results\_key (quota\_id, checkin\_date, weigh\_coin)\` (partial when quota\_id present)    
\- FK: \`receiving\_row\_id → receiving\_notes.row\_id (ON UPDATE CASCADE ON DELETE SET NULL)\`    
\- Parent-of: — / Child-of: receiving\_notes

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---|---|---:|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | PK | คีย์ภายใน |  
| id | varchar(14) | UNIQUE | NO | trigger | CHECK (id \~ '^FDR-\\d{10}$') | UNIQUE | public id auto-generated (FDR prefix) |  
| created\_at | timestamptz | \- | NO | now() | \- | idx\_factory\_dump\_results\_lookup | เวลาที่รับผลจากโรงงาน |  
| quota\_id | varchar(64) | \- | YES | NULL | \- | idx\_factory\_dump\_results\_lookup | (optional) |  
| checkin\_date | date | \- | NO | NULL | \- | idx\_factory\_dump\_results\_lookup | วันที่ตรวจสอบ (ISO date) |  
| weigh\_coin | integer | \- | NO | NULL | CHECK (weigh\_coin \>= 0\) | idx\_factory\_dump\_results\_lookup | เลขเหรียญชั่ง |  
| ccs | numeric(5,2) | \- | YES | NULL | CHECK (ccs \>= 0 AND ccs \= round(ccs::numeric,2)) | \- | CCS จากโรงงาน |  
| net\_weight\_kg | numeric(10,2) | \- | YES | NULL | CHECK (net\_weight\_kg \>= 0 AND net\_weight\_kg \= round(net\_weight\_kg::numeric,2)) | \- | น้ำหนักสุทธิจากโรงงาน |  
| fetched\_at | timestamptz | \- | YES | NULL | \- | \- | เวลา fetch ผลจากโรงงาน |  
| fetch\_status | text | \- | NO | 'not\_found' | CHECK (fetch\_status IN ('success','not\_found','mismatch','error')) | \- | สถานะการค้นหา |  
| source\_payload | jsonb | \- | YES | NULL | \- | \- | raw payload/response from external factory API |  
| receiving\_row\_id | uuid | FK → receiving\_notes.row\_id | YES | NULL | \- | idx\_factory\_dump\_results\_receiving\_row\_id | optional link to receiving\_note |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- External GET /ext/factory/dump ↔ สร้าง/บันทึก row ใน factory\_dump\_results (log) และอาจผูก \`receiving\_row\_id\` เมื่อสร้าง receiving\_note

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- row 1:  
  \- row\_id: 9b7c6a5d-4f3e-2a1b-8c7d-6e5f4a3b2c1d    
  \- id: FDR-0000000123    
  \- quota\_id: QTA-0001    
  \- checkin\_date: 2025-11-10    
  \- weigh\_coin: 12345    
  \- ccs: 11.25    
  \- net\_weight\_kg: 1250.50    
  \- fetched\_at: 2025-11-10T07:20:00+07:00    
  \- fetch\_status: success    
  \- receiving\_row\_id: 2f8b3f3a-7c2a-4b6e-9d3a-1c2b3a4d5e6f

\#\#\#\#= 10.0.3 แนวทางการตั้งดัชนี (Indexing Hints)  
\- receiving\_notes:  
  \- idx\_receiving\_notes\_weigh\_coin\_checkin\_time ON receiving\_notes (weigh\_coin, checkin\_time) — exact lookup for coin+date filters    
  \- idx\_receiving\_notes\_source\_type\_source\_ref ON receiving\_notes (source\_type, source\_ref) — filter by source booking    
  \- idx\_receiving\_notes\_status\_updated\_at ON receiving\_notes (status, updated\_at DESC) — list queries sorted by updated\_at per status    
  \- idx\_receiving\_notes\_checkin\_id ON receiving\_notes (checkin\_id) — exact lookup from QR/scan    
\- factory\_dump\_results:  
  \- idx\_factory\_dump\_results\_lookup ON factory\_dump\_results (quota\_id, checkin\_date, weigh\_coin) — lookup key for external fetch    
  \- idx\_factory\_dump\_results\_receiving\_row\_id ON factory\_dump\_results (receiving\_row\_id) — FK index

\#\# 10.1 ERD  
\`\`\`mermaid  
erDiagram  
    RECEIVING\_NOTES ||--o{ FACTORY\_DUMP\_RESULTS : "has"  
    RECEIVING\_NOTES {  
        uuid row\_id PK  
        varchar id  
        text status  
        text source\_type  
        varchar source\_ref  
        varchar checkin\_id  
        timestamptz checkin\_time  
        integer weigh\_coin  
        numeric ccs  
        numeric net\_weight\_kg  
    }  
    FACTORY\_DUMP\_RESULTS {  
        uuid row\_id PK  
        varchar id  
        varchar quota\_id  
        date checkin\_date  
        integer weigh\_coin  
        numeric ccs  
        numeric net\_weight\_kg  
        timestamptz fetched\_at  
        text fetch\_status  
        uuid receiving\_row\_id FK  
    }  
\`\`\`

\#\# 10.2 ไฮไลท์ DDL & นโยบายคีย์  
\- Extension prerequisite:  
  \- CREATE EXTENSION IF NOT EXISTS pgcrypto;  
\- PK:  
  \- ทุกตารางมี \`row\_id UUID PRIMARY KEY DEFAULT gen\_random\_uuid()\`  
\- Public ID:  
  \- receiving\_notes.id — CHECK '^CRN-\\d{4}-\\d{5}$' ; sequence \`seq\_receiving\_note\_public\_id\` \+ trigger fn to produce \`CRN-\<YYYY\>-\<NNNNN\>\` (sequence padded to 5 digits). (รายละเอียดการสร้างใน 10.5 Conflict Log เนื่องจาก pattern เฉพาะ)  
  \- factory\_dump\_results.id — CHECK '^FDR-\\d{10}$' ; sequence \`seq\_factory\_dump\_results\_public\_id\` padded to 10 digits via trigger  
\- FK default policy:  
  \- Default: ON UPDATE CASCADE ON DELETE RESTRICT    
  \- receiving\_row\_id in factory\_dump\_results: ON UPDATE CASCADE ON DELETE SET NULL (เก็บ log แม้ receiving ถูกลบ)  
\- UNIQUE / UK:  
  \- uq\_receiving\_notes\_id ON receiving\_notes(id)    
  \- uq\_factory\_dump\_results\_key ON factory\_dump\_results(quota\_id, checkin\_date, weigh\_coin) — sparse/partial: only when quota\_id IS NOT NULL (implement as partial unique index if required)  
\- CHECK constraints:  
  \- status IN ('Draft','Issued','Void') — canonical capitalization enforced in DB    
  \- source\_type IN ('CBM','NBM','CENTRAL')    
  \- dump\_fetch\_mode IN ('auto','manual')    
  \- fetch\_status IN ('success','not\_found','mismatch','error')    
  \- ccs, net\_weight\_kg non-negative and rounded to 2 decimals (checked)  
\- Indexing:  
  \- ทุก FK มี index; lookups and composite indexes named: idx\_receiving\_notes\_weigh\_coin\_checkin\_time, idx\_receiving\_notes\_source\_type\_source\_ref, idx\_factory\_dump\_results\_lookup, etc.  
\- Sequence/Trigger template (ตัวอย่างแบบเป็นแนวทาง):  
  \- seq\_receiving\_note\_public\_id    
  \- fn\_receiving\_notes\_make\_public\_id() sets NEW.id := 'CRN-' || to\_char(current\_timestamp AT TIME ZONE 'Asia/Bangkok','YYYY') || '-' || lpad(nextval('seq\_receiving\_note\_public\_id')::text,5,'0')  
  \- trg\_receiving\_notes\_public\_id BEFORE INSERT EXECUTE fn\_receiving\_notes\_make\_public\_id()  
\- Transactions & Side-effects:  
  \- Issuing a receiving (status Draft→Issued) must be implemented as an orchestrated transaction with compensations: create receiving\_notes row, log factory\_dump\_results when fetched, call POST /api/weigh-coin/free, PATCH /api/cbm/{booking\_id}/status, generate PDF and persist pdf\_url — the DB will only persist canonical facts; external calls handled by orchestrator. Ensure idempotency via X-Idempotency-Key (server-side idempotency store).  
\- Audit/ETag:  
  \- Use version integer \+ updated\_at to compute ETag (W/"v\<version\>-\<updated\_at\_epoch\>") for If-Match/optimistic concurrency.

\#\# 10.3 พจนานุกรมข้อมูล (Field Dictionary แบบเต็ม)

\#\#\# receiving\_notes  
\- row\_id: uuid; 36; NOT NULL; DEFAULT gen\_random\_uuid(); PK; Example: 2f8b3f3a-7c2a-4b6e-9d3a-1c2b3a4d5e6f; PII: no    
\- id: varchar(14); 14; NOT NULL; DEFAULT via trigger; UNIQUE; Example: CRN-2025-00001; PII: no; Pattern: ^CRN-\\d{4}-\\d{5}$    
\- created\_at: timestamptz; \-; NOT NULL; DEFAULT now(); Example: 2025-11-10T08:00:00+07:00; PII: no    
\- updated\_at: timestamptz; \-; NOT NULL; DEFAULT now(); Example: 2025-11-10T08:00:05+07:00; PII: no    
\- version: integer; \-; NOT NULL; DEFAULT 1; CHECK \>0; Example: 1; PII: no    
\- status: text; \-; NOT NULL; DEFAULT 'Draft'; CHECK in ('Draft','Issued','Void'); Example: 'Issued'; PII: no    
\- source\_type: text; \-; NOT NULL; DEFAULT 'CBM'; CHECK in ('CBM','NBM','CENTRAL'); Example: 'CBM'; PII: no    
\- source\_ref: varchar(255); 255; NULL; Example: CBM-12345; PII: no    
\- checkin\_id: varchar(64); 64; NOT NULL; Example: CHK-0001; PII: no    
\- checkin\_time: timestamptz; \-; NULL; Example: 2025-11-10T07:15:00+07:00; PII: no    
\- checkin\_snapshot: jsonb; \-; NULL; Example: {"farmer\_name":"นายสมชาย","driver\_phone":"+66-8-1234-\*\*\*\*"}; PII: contains PII (driver\_phone) — mask in list responses; full visible per RBAC in detail.    
\- weigh\_coin: integer; \-; NULL; Example: 12345; PII: no    
\- dump\_fetch\_mode: text; \-; NOT NULL; DEFAULT 'auto'; CHECK in ('auto','manual'); Example: 'auto'; PII: no    
\- ccs: numeric(5,2); precision 5 scale 2; NULL; Example: 11.25; CHECK non-negative & 2 decimals; PII: no    
\- net\_weight\_kg: numeric(10,2); precision 10 scale 2; NULL; Example: 1250.50; CHECK non-negative & 2 decimals; PII: no    
\- issued\_at: timestamptz; \-; NULL; Example: 2025-11-10T08:00:00+07:00; PII: no    
\- issued\_by: varchar(64); 64; NULL; Example: user\_102; PII: maybe user id — internal only    
\- voided\_at: timestamptz; \-; NULL; Example: 2025-11-11T09:00:00+07:00; PII: no    
\- voided\_by: varchar(64); \-; NULL; Example: user\_201; PII: internal — audit only    
\- void\_reason: text; \-; NULL; Example: "ข้อมูลน้ำหนักผิดพลาด \- ยกเลิกเพื่อสร้างใหม่"; PII: no    
\- pdf\_url: text; \-; NULL; Example: https://obj.example/pdfs/CRN-2025-00001.pdf; PII: may include identifiers — treat as internal link    
\- booking\_id: varchar(255); \-; NULL; Example: CBM-12345; PII: no    
\- payment\_prefs: jsonb; \-; NULL; Example: {"method":"bank\_transfer","account":"xxxx-\*\*\*\*"}; PII: contains masked financial info — show masked in list; full per RBAC    
\- deleted\_at: timestamptz; \-; NULL; Example: NULL; PII: no

Masking note: driver\_phone, account in payment\_prefs are PII and must be masked at API layer for list responses; full data only for authorized roles (Supervisor/Receiving Staff where policy permits).

\#\#\# factory\_dump\_results  
\- row\_id: uuid; NOT NULL; DEFAULT gen\_random\_uuid(); PK; Example: 9b7c6a5d-...; PII: no    
\- id: varchar(14); NOT NULL; DEFAULT trigger; UNIQUE; Example: FDR-0000000123; PII: no    
\- created\_at: timestamptz; NOT NULL; DEFAULT now(); Example: 2025-11-10T07:20:00+07:00    
\- quota\_id: varchar(64); NULL; Example: QTA-0001; PII: no    
\- checkin\_date: date; NOT NULL; Example: 2025-11-10    
\- weigh\_coin: integer; NOT NULL; Example: 12345    
\- ccs: numeric(5,2); NULL; Example: 11.25; CHECK \>=0 and 2 decimals    
\- net\_weight\_kg: numeric(10,2); NULL; Example: 1250.50    
\- fetched\_at: timestamptz; NULL; Example: 2025-11-10T07:20:00+07:00    
\- fetch\_status: text; NOT NULL; DEFAULT 'not\_found'; CHECK in ('success','not\_found','mismatch','error')    
\- source\_payload: jsonb; NULL; raw external response — may contain PII depending on vendor; treat as sensitive and apply retention policy    
\- receiving\_row\_id: uuid; NULL; FK → receiving\_notes.row\_id; Example: 2f8b3f3a-...; PII: no

\#\# 10.4 Enums & Patterns  
\- status: TEXT \+ CHECK IN ('Draft','Issued','Void') — canonical capitalization enforced. API accepts case-insensitive inputs; server normalizes to canonical values.  
\- source\_type: TEXT \+ CHECK IN ('CBM','NBM','CENTRAL')  
\- dump\_fetch\_mode: TEXT \+ CHECK IN ('auto','manual')  
\- factory fetch\_status: TEXT \+ CHECK IN ('success','not\_found','mismatch','error')  
\- receiving\_id pattern (canonical): ^CRN-\\d{4}-\\d{5}$ (exact)    
\- factory\_dump\_results.id pattern: ^FDR-\\d{10}$    
\- weigh\_coin: integer \>= 0    
\- ccs: numeric(5,2) non-negative; net\_weight\_kg: numeric(10,2) non-negative

\#\# 10.5 Conflict Log & Candidate Fields  
\- Conflict 1 (Short-ID policy vs Canonical receiving\_id pattern):  
  \- Canonical requires receiving\_id matching ^CRN-\\d{4}-\\d{5}$ (CRN-YYYY-NNNNN). Short-ID policy typically uses seq with fixed digits\_len (default 10). Decision: follow Canonical — implement receiving\_notes.id as CRN-\<YYYY\>-\<NNNNN\> using a per-table sequence padded to 5 digits (seq\_receiving\_note\_public\_id) and trigger that includes current year. Documented here because it deviates from default digits\_len=10. Rationale: Canonical pattern is source-of-truth for external integrations and existing references.  
\- Conflict 2 (DB timezone storage vs Canonical "TZ=Asia/Bangkok"):  
  \- Canonical: "เก็บเป็น ISO-8601 (TZ=Asia/Bangkok)". Platform guideline: store timestamptz (UTC). Decision/Assumption: store timestamps as timestamptz DEFAULT now() (UTC) and application/API layer will normalize to Asia/Bangkok for writes/reads (i.e., UI/presentation enforces Asia/Bangkok). Rationale: DB standardization on timestamptz in UTC avoids DST/offset issues; presentation layer guarantees required TZ. Logged as assumption.  
\- Conflict 3 (API uses field name \`receiving\_id\`):  
  \- API payloads/responses use \`receiving\_id\`. Short-ID policy prefers \`id\`. Decision: DB column named \`id\` (public id) while API maps \`receiving\_id\` ↔ DB \`id\`. Documented mapping in 10.0.2.  
\- Candidate Fields (present in API but not modeled as first-class columns):  
  \- From GET /api/checkins/{id}: farmer\_name, driver\_name, driver\_phone, license\_plate — these are stored as JSONB \`checkin\_snapshot\` (snapshot) in receiving\_notes rather than separate normalized columns to avoid duplicating master checkin data and to keep schema minimal. Candidate alternative: separate checkin\_snapshot table if needs querying.  
  \- audit.etag (from API responses): not stored as-is; ETag computed from (version, updated\_at) on demand.  
  \- API \`audit.created\_by\`/\`created\_at\` — mapped to receiving\_notes.created\_at and created\_by can be added to created\_by (if available via application). If created\_by missing in inputs, assume application populates it.  
\- Assumptions made when inputs ambiguous:  
  \- Id generation for CRN uses single global sequence seq\_receiving\_note\_public\_id incrementing across years; sequence not reset per year (keeps monotonic numbering). Rationale: simpler implementation and avoids sequence reuse; still fulfills pattern with year prefix.  
  \- When external side-effects (PATCH CBM, POST weigh-coin/free, PDF generation) partially fail during Issue, server should attempt retries and ultimately surface errors; database will only be committed when core facts persisted — orchestrator handles compensations. Documented in 10.6.  
  \- \`factory\_dump\_results\` retention: store raw payload for audit but treat as sensitive and apply retention/cleanup policy via housekeeping job (not modeled here).

\#\# 10.6 Data Lineage & Integration Notes  
\- Sources/Systems:  
  \- Check-in Service: authoritative for booking\_type/booking\_id/payment\_prefs and checkin snapshot. We persist minimal snapshot (\`checkin\_snapshot\`) and external reference (\`checkin\_id\`) only. Single source: do not duplicate master checkin records.  
  \- CBM (booking management): authoritative for booking status and payment linkage. We store \`source\_ref\`/\`booking\_id\` only and call PATCH /api/cbm/{booking\_id}/status as side-effect when Issue (awaiting\_payment) or Void (awaiting\_dump\_result). Do not persist CBM status locally (source-of-truth remains CBM).  
  \- Factory Dump (external): authoritative for the raw dump result. We call GET /ext/factory/dump (auto, retried 3 times) and log responses in factory\_dump\_results. On success, ccs/net\_weight\_kg are copied into receiving\_notes (authoritative for invoice/receipt) but original factory payload remains in factory\_dump\_results for audit and reconciliation.  
  \- Weigh-coin Service: authoritative for coin freeing. On Issued, call POST /api/weigh-coin/free. Handle 409 COIN\_ALREADY\_FREED via idempotent handling and user-visible error.  
  \- PDF/Object Storage: generated PDF stored in durable object storage; pdf\_url saved in receiving\_notes.pdf\_url.  
\- Rationale for storing certain fields:  
  \- ccs and net\_weight\_kg are stored in receiving\_notes as they are needed for billing/invoice and business workflows. The factory result remains the source-of-truth for origin; storing both enables reconciliation and audit.  
  \- checkin\_snapshot stored as JSONB for audit and UI prefill; avoids duplication of checkin master data but preserves necessary read-only display values.  
\- Business process guarantees:  
  \- Issued transition must complete sequence: create receiving\_note row → (if auto) fetch factory\_dump\_results → persist ccs/net\_weight\_kg → POST weigh-coin/free → PATCH CBM status → generate PDF → update pdf\_url → emit event cane\_receiving.issued. Orchestrator must ensure idempotency (X-Idempotency-Key) and implement compensating actions on partial failures.  
  \- Void transition must verify no linked Payment exists; if safe, set status=Void, set voided\_at/voided\_by/void\_reason, PATCH CBM status back to awaiting\_dump\_result, emit event cane\_receiving.void.  
\- Views / Read Models:  
  \- For complex reporting or export, create read-only VIEWs that join receiving\_notes \+ factory\_dump\_results (latest) \+ checkin\_snapshot fields. Avoid duplicating computed metrics in multiple tables.  
\- Reconciliation:  
  \- Implement periodic job to reconcile factory\_dump\_results vs receiving\_notes (matching by weigh\_coin, checkin\_date) and flag mismatches for operator review.  
\- Security / PII handling:  
  \- Mask driver\_phone and payment account numbers at API list level; full values only for authorized roles. Raw PII in checkin\_snapshot/source\_payload must be encrypted at rest or access-controlled per compliance.

\---