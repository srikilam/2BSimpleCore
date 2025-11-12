\#\# 8\) API Endpoints    
Base URL: \`\<base\_url\>\`    
Base Path: \`/agm/admin/area-permission\`  

| Method | Path | Use case | Notes |  
|---|---|---|---|  
| GET | /api/areas | ดึงรายการ Areas (search/filter/sort/paginate) | Headers: Authorization. Query: q, province\_id, district\_id, subdistrict\_id, status, page, page\_size, sort. child counts: heads\_count, codes\_count |  
| GET | /api/areas/{area\_id} | ดึงรายละเอียด Area | Headers: Authorization. Returns Areas object (postal\_code read-only). Traceable → Area Detail page |  
| POST | /api/areas | สร้าง Area ใหม่ | Headers: Authorization, X-Idempotency-Key (required). Body: area fields. Response 201\. Journey A / Create Drawer |  
| PUT | /api/areas/{area\_id} | แก้ไข Area (full update) | Headers: Authorization, If-Match (version required). Uses optimistic locking. Journey B / Edit Drawer |  
| PATCH | /api/areas/{area\_id}/status | สลับสถานะ Area (active ↔ inactive) | Headers: Authorization, If-Match. Guard: 409 if Area has OCCUPIED codes. Journey C |  
| GET | /api/areas/{area\_id}/heads | ดึง Area Heads สำหรับ Area | Headers: Authorization. Returns AreaHeadAssignments\[\] |  
| POST | /api/areas/{area\_id}/heads | เพิ่ม Area Head ให้ Area | Headers: Authorization, X-Idempotency-Key. Body: { employee\_id }. Journey G |  
| DELETE | /api/areas/{area\_id}/heads/{employee\_id} | ลบ Area Head | Headers: Authorization, If-Match optional. Response 204 |  
| GET | /api/roles/directors | ดึงรายการ Directors (global) | Headers: Authorization. Journey E |  
| POST | /api/roles/directors | เพิ่ม Director (global) | Headers: Authorization, X-Idempotency-Key. Body: { employee\_id }. Journey E |  
| DELETE | /api/roles/directors/{employee\_id} | ลบ Director (global) | Headers: Authorization. Response 204\. Journey F |  
| GET | /api/extension-codes | ดึงรายการ ExtensionCodes (search/filter/paginate) | Headers: Authorization. Query: q, area\_id, status, page, page\_size, sort. fields: display\_code, status, assigned\_to |  
| GET | /api/extension-codes/{ext\_code\_id} | ดึงรายละเอียด Extension Code | Headers: Authorization. Returns ExtensionCodes \+ current assignment (ExtensionCodeAssignments) |  
| POST | /api/extension-codes | สร้าง Extension Code | Headers: Authorization, X-Idempotency-Key. Body: { area\_id, display\_code, note }. Journey I |  
| PUT | /api/extension-codes/{ext\_code\_id}/rename | เปลี่ยน display\_code (rename-only) | Headers: Authorization, If-Match (version required). Body: { new\_display\_code }. Journey J |  
| POST | /api/extension-codes/{ext\_code\_id}/assign | มอบหมาย employee → code (EMPTY → OCCUPIED) | Headers: Authorization, X-Idempotency-Key. Body: { employee\_id }. Preconditions: code EMPTY; employee active; employee has no active code. Journey K |  
| POST | /api/extension-codes/{from\_id}/reassign | ย้าย (atomic) assignment จาก from\_id → to\_id | Headers: Authorization, X-Idempotency-Key. Body: { to\_id, employee\_id }. Atomic transaction; 423 on race. Journey L |  
| GET | /api/areas/export | Export CSV ของ Areas (async/sync per impl) | Headers: Authorization. Query mirrors list. Journey M (Export) |  
| GET | /api/extension-codes/export | Export CSV ของ ExtensionCodes | Headers: Authorization. Query mirrors list. Journey M (Export) |  
| GET | /api/erp/employees | (integration) ERP employee lookup | Headers: Authorization. Query: q. Used for validation/lookups. Integration |  
| GET | /api/geo/provinces, /api/geo/districts, /api/geo/subdistricts, /api/geo/postal?subdistrict\_id= | (integration) Address Master lookups | Headers: Authorization. Used to populate postal\_code (RO) |

\---

\#\#\# 8.1 List — \`GET /api/areas\`  
Traceability: Page \= \`Areas (List)\` · Action \= \`view:list\` · Journey \= \`M (Lists: Search/Filter/Export)\`    
Headers (required/optional): Authorization: Bearer \<token\>

Query params:  
| Name | Type | Req | Default | Description |  
|---|---:|---:|---|---|  
| q | string | no |  | ค้นหา area\_name หรือ area\_id |  
| province\_id | string | no |  | กรองตาม province\_id |  
| district\_id | string | no |  | กรองตาม district\_id |  
| subdistrict\_id | string | no |  | กรองตาม subdistrict\_id |  
| status | enum | no |  | ค่าที่รองรับ: active, inactive |  
| page | int | no | 1 | หมายเลขหน้า |  
| page\_size | int | no | 25 | จำนวนรายการต่อหน้า |  
| sort | string | no | updated\_at desc | ตัวอย่าง: area\_name asc, updated\_at desc |

\#\#\#\# Response (success):  
\`\`\`json  
{  
  "items": \[  
    {  
      "area\_id": "e7b8c1d2-3f4a-4b5c-9d6e-0f1a2b3c4d5e",  
      "area\_name": "พื้นที่ภาคกลาง",  
      "province\_id": "10",  
      "district\_id": "1001",  
      "subdistrict\_id": "100101",  
      "postal\_code": "10110",  
      "address\_line": "ถนนประชา",  
      "description": "ศูนย์ทดลอง",  
      "status": "active",  
      "heads\_count": 2,  
      "codes\_count": 12,  
      "version": 3,  
      "created\_at": "2025-01-01T08:00:00Z",  
      "created\_by": "EMP-1001",  
      "updated\_at": "2025-03-01T10:00:00Z",  
      "updated\_by": "EMP-1002"  
    }  
  \],  
  "page": 1,  
  "page\_size": 25,  
  "total": 125  
}  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "VALIDATION\_FAILED", "message": "Invalid filter value", "details": \[{ "field": "page\_size", "message": "max 200" }\], "trace\_id": "req-1234" }  
\`\`\`

\---

\#\#\# 8.2 Detail — \`GET /api/areas/{area\_id}\`  
Traceability: Page \= \`Area Detail\` · Action \= \`view:detail\` · Journey \= \`D (View Detail)\`    
Headers (required/optional): Authorization: Bearer \<token\>

\#\#\#\# Response (success):  
\`\`\`json  
{  
  "area\_id": "e7b8c1d2-3f4a-4b5c-9d6e-0f1a2b3c4d5e",  
  "area\_name": "พื้นที่ภาคกลาง",  
  "province\_id": "10",  
  "district\_id": "1001",  
  "subdistrict\_id": "100101",  
  "postal\_code": "10110",  
  "address\_line": "ถนนประชา",  
  "description": "ศูนย์ทดลอง",  
  "status": "active",  
  "version": 3,  
  "created\_at": "2025-01-01T08:00:00Z",  
  "created\_by": "EMP-1001",  
  "updated\_at": "2025-03-01T10:00:00Z",  
  "updated\_by": "EMP-1002"  
}  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "NOT\_FOUND", "message": "Area not found", "details": \[\], "trace\_id": "req-5678" }  
\`\`\`

\---

\#\#\# 8.3 Create Area — \`POST /api/areas\`  
Traceability: Page \= \`Area Create (Drawer)\` · Action \= \`create:area\` · Journey \= \`A (Create Area)\`    
Headers (required/optional): Authorization: Bearer \<token\>, X-Idempotency-Key: \<uuid\> (required)

\#\#\#\# Request:  
\`\`\`json  
{  
  "area\_name": "พื้นที่ภาคเหนือทดลอง",  
  "province\_id": "57",  
  "district\_id": "5701",  
  "subdistrict\_id": "570101",  
  "address\_line": "หมู่บ้านตัวอย่าง 12",  
  "description": "พื้นที่ใช้งานทดลอง"  
}  
\`\`\`

\#\#\#\# Response (success 201):  
\`\`\`json  
{  
  "area\_id": "a3f1c2d3-4e5f-4001-9a1b-0c1d2e3f4a5b",  
  "version": 1,  
  "status": "active",  
  "created\_at": "2025-11-01T02:00:00Z"  
}  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "CONFLICT", "message": "area\_name already exists", "details": \[{ "field": "area\_name", "message": "duplicate" }\], "trace\_id": "req-9101" }  
\`\`\`

\---

\#\#\# 8.4 Update Area — \`PUT /api/areas/{area\_id}\`  
Traceability: Page \= \`Area Edit (Drawer)\` · Action \= \`update:area\` · Journey \= \`B (Edit)\`    
Headers (required/optional): Authorization: Bearer \<token\>, If-Match: "\<version\>" (required)

\#\#\#\# Request:  
\`\`\`json  
{  
  "area\_name": "พื้นที่ภาคกลาง (ปรับปรุง)",  
  "province\_id": "10",  
  "district\_id": "1001",  
  "subdistrict\_id": "100101",  
  "address\_line": "ถนนประชา 2",  
  "description": "อัพเดตข้อมูล"  
}  
\`\`\`

\#\#\#\# Response (success 200):  
\`\`\`json  
{  
  "area\_id": "e7b8c1d2-3f4a-4b5c-9d6e-0f1a2b3c4d5e",  
  "version": 4,  
  "updated\_at": "2025-11-02T05:00:00Z",  
  "updated\_by": "EMP-1002"  
}  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "PRECONDITION\_FAILED", "message": "If-Match mismatch", "details": \[\], "trace\_id": "req-1122" }  
\`\`\`

\---

\#\#\# 8.5 Toggle Area Status — \`PATCH /api/areas/{area\_id}/status\`  
Traceability: Page \= \`Areas (List), Area Detail\` · Action \= \`toggle:status\` · Journey \= \`C (Activate/Deactivate)\`    
Headers (required/optional): Authorization: Bearer \<token\>, If-Match: "\<version\>" (required)

\#\#\#\# Request:  
\`\`\`json  
{ "status": "inactive" }  
\`\`\`

\#\#\#\# Response:  
\`\`\`json  
{ "area\_id": "e7b8c1d2-3f4a-4b5c-9d6e-0f1a2b3c4d5e", "status": "inactive", "version": 5, "updated\_at": "2025-11-02T06:00:00Z" }  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "CONFLICT", "message": "Cannot inactivate area with OCCUPIED codes", "details": \[\], "trace\_id": "req-3344" }  
\`\`\`

\---

\#\#\# 8.6 List Area Heads for Area — \`GET /api/areas/{area\_id}/heads\`  
Traceability: Page \= \`Area Detail\` · Action \= \`view:heads\` · Journey \= \`D/G\`    
Headers (required/optional): Authorization: Bearer \<token\>

\#\#\#\# Response:  
\`\`\`json  
{  
  "area\_id": "e7b8c1d2-3f4a-4b5c-9d6e-0f1a2b3c4d5e",  
  "heads": \[  
    {  
      "employee\_id": "EMP-1002",  
      "full\_name": "สมนึก ตัวอย่าง",  
      "assigned\_at": "2025-02-01T09:00:00Z",  
      "assigned\_by": "EMP-0001"  
    }  
  \]  
}  
\`\`\`

\---

\#\#\# 8.7 Add Area Head — \`POST /api/areas/{area\_id}/heads\`  
Traceability: Page \= \`Area Detail\`, \`Area Heads (Global)\` · Action \= \`add:head\` · Journey \= \`G\`    
Headers (required/optional): Authorization: Bearer \<token\>, X-Idempotency-Key: \<uuid\> (required)

\#\#\#\# Request:  
\`\`\`json  
{ "employee\_id": "EMP-1010" }  
\`\`\`

\#\#\#\# Response (success 201):  
\`\`\`json  
{ "area\_id": "e7b8c1d2-3f4a-4b5c-9d6e-0f1a2b3c4d5e", "employee\_id": "EMP-1010", "assigned\_at": "2025-11-02T07:00:00Z" }  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "VALIDATION\_FAILED", "message": "employee is inactive", "details": \[{ "field": "employee\_id", "message": "ERP employee inactive" }\], "trace\_id": "req-5566" }  
\`\`\`

\---

\#\#\# 8.8 Remove Area Head — \`DELETE /api/areas/{area\_id}/heads/{employee\_id}\`  
Traceability: Page \= \`Area Detail\`, \`Area Heads (Global)\` · Action \= \`remove:head\` · Journey \= \`H\`    
Headers (required/optional): Authorization: Bearer \<token\>

\#\#\#\# Response (success 204):  
(empty body)

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "NOT\_FOUND", "message": "Head assignment not found", "details": \[\], "trace\_id": "req-7788" }  
\`\`\`

\---

\#\#\# 8.9 List Directors — \`GET /api/roles/directors\`  
Traceability: Page \= \`Directors (Sub-Tab)\` · Action \= \`view:list\` · Journey \= \`E\`    
Headers (required/optional): Authorization: Bearer \<token\>

\#\#\#\# Response:  
\`\`\`json  
{  
  "items": \[  
    { "employee\_id": "EMP-0005", "full\_name": "สมชาย ตัวอย่าง", "email": "somchai@example.com", "dept": "Admin", "assigned\_at": "2025-01-10T08:00:00Z" }  
  \],  
  "page": 1,  
  "total": 5  
}  
\`\`\`

\---

\#\#\# 8.10 Add Director — \`POST /api/roles/directors\`  
Traceability: Page \= \`Directors (Sub-Tab)\` · Action \= \`add:director\` · Journey \= \`E\`    
Headers (required/optional): Authorization: Bearer \<token\>, X-Idempotency-Key: \<uuid\> (required)

\#\#\#\# Request:  
\`\`\`json  
{ "employee\_id": "EMP-2001" }  
\`\`\`

\#\#\#\# Response (success 201):  
\`\`\`json  
{ "employee\_id": "EMP-2001", "assigned\_at": "2025-11-02T07:30:00Z" }  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "CONFLICT", "message": "employee already a director", "details": \[\], "trace\_id": "req-9900" }  
\`\`\`

\---

\#\#\# 8.11 Remove Director — \`DELETE /api/roles/directors/{employee\_id}\`  
Traceability: Page \= \`Directors (Sub-Tab)\` · Action \= \`remove:director\` · Journey \= \`F\`    
Headers (required/optional): Authorization: Bearer \<token\>

\#\#\#\# Response (success 204):  
(empty body)

\---

\#\#\# 8.12 List Extension Codes — \`GET /api/extension-codes\`  
Traceability: Page \= \`Extension Codes (List)\` / \`Extension Officers\` · Action \= \`view:list\` · Journey \= \`M\`    
Headers (required/optional): Authorization: Bearer \<token\>

Query params:  
| Name | Type | Req | Default | Description |  
|---|---:|---:|---|---|  
| q | string | no |  | ค้นหา display\_code หรือ employee |  
| area\_id | string | no |  | กรองตาม Area |  
| status | enum | no |  | EMPTY, OCCUPIED |  
| page | int | no | 1 | หน้า |  
| page\_size | int | no | 25 | จำนวนต่อหน้า |  
| sort | string | no | updated\_at desc | sort field |

\#\#\#\# Response (success):  
\`\`\`json  
{  
  "items": \[  
    {  
      "ext\_code\_id": "f1e2d3c4-b5a6-4c7d-9e8f-0123456789ab",  
      "display\_code": "0123",  
      "area\_id": "e7b8c1d2-3f4a-4b5c-9d6e-0f1a2b3c4d5e",  
      "area\_name": "พื้นที่ภาคกลาง",  
      "status": "EMPTY",  
      "note": "สำรอง",  
      "version": 1,  
      "created\_at": "2025-06-01T09:00:00Z"  
    }  
  \],  
  "page": 1,  
  "page\_size": 25,  
  "total": 432  
}  
\`\`\`

\---

\#\#\# 8.13 Extension Code Detail — \`GET /api/extension-codes/{ext\_code\_id}\`  
Traceability: Page \= \`Extension Code Detail\` · Action \= \`view:detail\` · Journey \= \`I/J/K/L\`    
Headers (required/optional): Authorization: Bearer \<token\>

\#\#\#\# Response (success):  
\`\`\`json  
{  
  "ext\_code\_id": "f1e2d3c4-b5a6-4c7d-9e8f-0123456789ab",  
  "display\_code": "0123",  
  "area\_id": "e7b8c1d2-3f4a-4b5c-9d6e-0f1a2b3c4d5e",  
  "area\_name": "พื้นที่ภาคกลาง",  
  "status": "OCCUPIED",  
  "note": "งานทดลอง",  
  "version": 2,  
  "assigned": {  
    "ext\_code\_id": "f1e2d3c4-b5a6-4c7d-9e8f-0123456789ab",  
    "employee\_id": "EMP-3001",  
    "assigned\_at": "2025-09-01T08:30:00Z",  
    "assigned\_by": "EMP-0001"  
  },  
  "created\_at": "2025-06-01T09:00:00Z"  
}  
\`\`\`

\---

\#\#\# 8.14 Create Extension Code — \`POST /api/extension-codes\`  
Traceability: Page \= \`Create Extension Code (Modal)\`, \`Extension Codes (List)\` · Action \= \`create:code\` · Journey \= \`I\`    
Headers (required/optional): Authorization: Bearer \<token\>, X-Idempotency-Key: \<uuid\> (required)

\#\#\#\# Request:  
\`\`\`json  
{  
  "area\_id": "e7b8c1d2-3f4a-4b5c-9d6e-0f1a2b3c4d5e",  
  "display\_code": "1234",  
  "note": "สำรองสำหรับแผน 2"  
}  
\`\`\`

\#\#\#\# Response (success 201):  
\`\`\`json  
{  
  "ext\_code\_id": "f1e2d3c4-b5a6-4c7d-9e8f-0123456789ab",  
  "display\_code": "1234",  
  "status": "EMPTY",  
  "created\_at": "2025-11-02T08:00:00Z"  
}  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "VALIDATION\_FAILED", "message": "display\_code must match ^\\\\d{4}$", "details": \[{ "field": "display\_code", "message": "invalid format" }\], "trace\_id": "req-2233" }  
\`\`\`

\---

\#\#\# 8.15 Rename Extension Code — \`PUT /api/extension-codes/{ext\_code\_id}/rename\`  
Traceability: Page \= \`Rename Code (Modal)\`, \`Extension Code Detail\` · Action \= \`rename:code\` · Journey \= \`J\`    
Headers (required/optional): Authorization: Bearer \<token\>, If-Match: "\<version\>" (required)

\#\#\#\# Request:  
\`\`\`json  
{ "new\_display\_code": "4321" }  
\`\`\`

\#\#\#\# Response:  
\`\`\`json  
{ "ext\_code\_id": "f1e2d3c4-b5a6-4c7d-9e8f-0123456789ab", "old\_display\_code": "1234", "new\_display\_code": "4321", "version": 3 }  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "CONFLICT", "message": "display\_code already exists", "details": \[\], "trace\_id": "req-4455" }  
\`\`\`

\---

\#\#\# 8.16 Assign Officer — \`POST /api/extension-codes/{ext\_code\_id}/assign\`  
Traceability: Page \= \`Assign Officer (Modal)\`, \`Extension Code Detail\` · Action \= \`assign:code\` · Journey \= \`K\`    
Headers (required/optional): Authorization: Bearer \<token\>, X-Idempotency-Key: \<uuid\> (required)

\#\#\#\# Request:  
\`\`\`json  
{ "employee\_id": "EMP-4001" }  
\`\`\`

\#\#\#\# Response (success 200):  
\`\`\`json  
{  
  "ext\_code\_id": "f1e2d3c4-b5a6-4c7d-9e8f-0123456789ab",  
  "display\_code": "0123",  
  "status": "OCCUPIED",  
  "assigned": { "employee\_id": "EMP-4001", "assigned\_at": "2025-11-02T09:00:00Z", "assigned\_by": "EMP-0001" }  
}  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "CONFLICT", "message": "employee already has an active code", "details": \[\], "trace\_id": "req-6677" }  
\`\`\`

\---

\#\#\# 8.17 Reassign Officer — \`POST /api/extension-codes/{from\_id}/reassign\`  
Traceability: Page \= \`Reassign Modal\` · Action \= \`reassign:code\` · Journey \= \`L\`    
Headers (required/optional): Authorization: Bearer \<token\>, X-Idempotency-Key: \<uuid\> (required)

\#\#\#\# Request:  
\`\`\`json  
{ "to\_id": "a7b8c9d0-e1f2-4a3b-8c7d-0123456789ff", "employee\_id": "EMP-4001" }  
\`\`\`

\#\#\#\# Response (success 200):  
\`\`\`json  
{  
  "from\_id": "f1e2d3c4-b5a6-4c7d-9e8f-0123456789ab",  
  "to\_id": "a7b8c9d0-e1f2-4a3b-8c7d-0123456789ff",  
  "employee\_id": "EMP-4001",  
  "at": "2025-11-02T09:30:00Z"  
}  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "LOCKED", "message": "reassign failed due to concurrent operation", "details": \[\], "trace\_id": "req-8899" }  
\`\`\`

\---

\#\#\# 8.18 Export Areas — \`GET /api/areas/export\`  
Traceability: Page \= \`Areas (List)\` · Action \= \`export:csv\` · Journey \= \`M\`    
Headers (required/optional): Authorization: Bearer \<token\>

Explain: หากระบบสนับสนุน synchronous CSV จะคืน 200 with CSV body; ถ้าเป็น async จะคืน 202 และต้องใช้ job polling endpoint (not specified). Implementation to choose (per NFR large exports should be async).

\---

\#\#\# 8.19 Export Extension Codes — \`GET /api/extension-codes/export\`  
Traceability: Page \= \`Extension Codes (List)\` · Action \= \`export:csv\` · Journey \= \`M\`    
Headers (required/optional): Authorization: Bearer \<token\>

Explain: Same semantics as 8.18.

\---

\#\#\# 8.20 Integrations: ERP Employee Lookup & Address Master  
Traceability: Page \= \`All pages with employee/address lookup\` · Action \= \`integration:lookup\` · Journey \= \`Various\`    
Headers (required/optional): Authorization: Bearer \<token\>

Examples:  
\- \`GET /api/erp/employees?q={q}\` — returns ErpEmployees\[\] for PersonSelect  
\- \`GET /api/geo/subdistricts?district\_id=\` and \`GET /api/geo/postal?subdistrict\_id=\` — used to populate postal\_code (RO)

\#\#\#\# Response (ERP example):  
\`\`\`json  
{  
  "items": \[  
    { "employee\_id": "EMP-4001", "full\_name": "อ้อม ตัวอย่าง", "email": "om@example.com", "dept": "Field", "title": "Officer", "status": "active" }  
  \]  
}  
\`\`\`

\---

\# 9\. API Contract — Notes & Conventions

9.1 Security & Headers  
\- Authentication: Bearer JWT (Authorization: Bearer \<token\>) \+ RBAC/Scopes enforced server-side per action (System Admin, Director, Area Head, Extension Officer, Audit).  
\- Required headers:  
  \- X-Idempotency-Key: required for all POST that create/assign/reassign (areas, extension-codes, roles, assignments).  
  \- If-Match: required for any PUT/PATCH/rename/status that uses optimistic locking. Value is the resource version (int) or ETag string as agreed.  
  \- Responses for GET/Detail should include ETag or version in body to be used by client for If-Match.  
\- Responses may include standard observability header (e.g., X-Request-Id) for tracing.

9.2 Error Model & Codes  
\- Use HTTP status codes semantically:  
  \- 400 VALIDATION\_FAILED — invalid format/required/regex.  
  \- 401/403 AUTHZ\_FAILED — unauthenticated/unauthorized (RBAC).  
  \- 404 NOT\_FOUND — missing resource (area/code/employee).  
  \- 409 CONFLICT — domain conflicts (duplicate display\_code, code not EMPTY, employee already assigned).  
  \- 412 PRECONDITION\_FAILED — If-Match missing/mismatch (optimistic locking).  
  \- 423 LOCKED — race condition on atomic reassign.  
  \- 424 FAILED\_DEPENDENCY — external dependency down (ERP/address).  
  \- 422 Unprocessable Entity — business validation (ERP inactive).  
  \- 500 Internal Server Error — unexpected.  
\- Error body format (consistent):  
\`\`\`json  
{ "code": "…", "message": "…", "details": \[ { "field": "…", "message": "…" } \], "trace\_id": "…" }  
\`\`\`  
\- UX guidance:  
  \- 412 → client should fetch latest, show merge/conflict dialog and allow retry.  
  \- 409 → show inline explanation (e.g., "พนักงานถูกผูกกับโค้ดแล้ว") and steps to resolve.  
  \- 423 → offer retry with backoff; show race/conflict guidance.

9.3 Rate Limits & Required Headers  
\- Default rate guidance (unless NFR overrides): 120 requests/minute per consumer.  
\- 429 responses must include Retry-After header (seconds).  
\- Require X-Idempotency-Key on POSTs that create/change assignments; server uses this to dedupe retries.

9.4 Idempotency & Concurrency  
\- POST operations that create/assign/reassign must be idempotent using X-Idempotency-Key. Clients MUST generate unique idempotency keys per logical user action.  
\- PUT/PATCH/rename/status require optimistic locking using If-Match with version (int) or ETag. Server returns 412 on mismatch.  
\- Concurrency semantics:  
  \- 409 for domain-level conflicts (duplicate or guard violated).  
  \- 412 for version mismatch — client should fetch latest and merge.  
  \- 423 for locked/transaction race (reassign). Retry policy: exponential backoff \+ fresh read.  
\- Server-side atomic transaction must be used for reassign (from→EMPTY, to→OCCUPIED) to avoid split-brain.

9.5 Example Requests (cURL)  
\- List Areas (with filters):  
curl \-H "Authorization: Bearer \<token\>" "\<base\_url\>/api/areas?q=ภาค\&province\_id=10\&page=1\&page\_size=25\&sort=area\_name%20asc"

\- Create Area (X-Idempotency-Key):  
curl \-X POST \-H "Authorization: Bearer \<token\>" \-H "X-Idempotency-Key: abcd-1234" \-H "Content-Type: application/json" "\<base\_url\>/api/areas" \-d '{  
  "area\_name": "พื้นที่ภาคเหนือทดลอง",  
  "province\_id": "57",  
  "district\_id": "5701",  
  "subdistrict\_id": "570101",  
  "address\_line": "หมู่บ้านตัวอย่าง 12",  
  "description": "พื้นที่ใช้งานทดลอง"  
}'

\- Update Area (If-Match):  
curl \-X PUT \-H "Authorization: Bearer \<token\>" \-H "If-Match: \\"3\\"" \-H "Content-Type: application/json" "\<base\_url\>/api/areas/e7b8c1d2-3f4a-4b5c-9d6e-0f1a2b3c4d5e" \-d '{  
  "area\_name": "พื้นที่ภาคกลาง (ปรับปรุง)",  
  "province\_id": "10",  
  "district\_id": "1001",  
  "subdistrict\_id": "100101",  
  "address\_line": "ถนนประชา 2",  
  "description": "อัพเดตข้อมูล"  
}'

\- Assign Extension Code (X-Idempotency-Key):  
curl \-X POST \-H "Authorization: Bearer \<token\>" \-H "X-Idempotency-Key: assign-5678" \-H "Content-Type: application/json" "\<base\_url\>/api/extension-codes/f1e2d3c4-b5a6-4c7d-9e8f-0123456789ab/assign" \-d '{  
  "employee\_id": "EMP-4001"  
}'

\- Reassign Extension Code (atomic):  
curl \-X POST \-H "Authorization: Bearer \<token\>" \-H "X-Idempotency-Key: reassign-9012" \-H "Content-Type: application/json" "\<base\_url\>/api/extension-codes/f1e2d3c4-b5a6-4c7d-9e8f-0123456789ab/reassign" \-d '{  
  "to\_id": "a7b8c9d0-e1f2-4a3b-8c7d-0123456789ff",  
  "employee\_id": "EMP-4001"  
}'

9.6 Notes (Integrations & Export)  
\- Export: prefer async jobs for large datasets. If synchronous CSV is supported, ensure response Content-Type: text/csv and pagination/filters applied. For async, return 202 with job\_id and job polling endpoint (not specified here).  
\- Outbound events (must be emitted per Integrations section):  
  \- ext\_code.assigned { ext\_code\_id, display\_code, area\_id, employee\_id, assigned\_at }  
  \- ext\_code.reassigned { employee\_id, from\_code, to\_code, area\_id, at }  
  \- ext\_code.renamed { ext\_code\_id, old\_code, new\_code, at }  
  \- area.updated { area\_id, fields\_changed, at, actor }  
\- Webhooks: not specified in inputs — define consumer URL, signing/secret, retry & backoff policy when implementing.  
\- PII / Masking: employee email and other PII should be masked in audit where appropriate. Logs must not contain raw secrets. Audit trail must record actor (employee\_id), timestamp, and snapshot before/after.  
\- Integrations (ERP / Address Master): treat as failed dependency (424) when unavailable; UI must show degraded mode and allow retry.  
\- Pagination & Sorting defaults: page\_size default 25; sort default updated\_at desc.  
\- IDs: area\_id, ext\_code\_id are UUID v4 (as specified) — clients must accept 36-char UUIDs. employee\_id is ERP string (e.g., EMP-1001).  
\- Child arrays: denote with \[\] (e.g., heads\[\], items\[\]).  
\- Dates/times: ISO-8601 UTC (e.g., 2025-01-01T00:00:00Z).  
\- Conventions: JSON field names in snake\_case.

\---

\#\# 10.0 Data Schema

\#\#\# 10.0.1 ภาพรวมเอนทิตี (Entity Overview)  
\- Areas — บันทึกพื้นที่เชิงภูมิศาสตร์ ใช้ในการผูก ExtensionCodes และ Area Head; ความสัมพันธ์: 1 Areas ||--o{ ExtensionCodes, 1 Areas ||--o{ AreaHeadAssignments    
\- ExtensionCodes — รหัสต่อสาย (4 หลัก) ที่เป็นของ Area เดียว; ความสัมพันธ์: ExtensionCodes ||--o{ ExtensionCodeAssignments (current active mapping as 1:1 via unique)    
\- ExtensionCodeAssignments — ตารางเก็บ mapping ปัจจุบันของ code → employee (active assignments) (1:1 ระหว่าง ext\_code ↔ assignment; employee ↔ assignment เป็น 1:1 ตามนโยบายธุรกิจ)    
\- AreaHeadAssignments — บันทึกหัวหน้าพื้นที่ปัจจุบัน (หลายหัวหน้าต่อ Area ได้)    
\- Directors — บันทึกผู้กำกับระบบ (global role)    
\- ErpEmployees (read-only mirror/lookup) — ข้อมูลพนักงานจาก ERP สำหรับการตรวจสอบสถานะ/ข้อมูลพื้นฐาน (ไม่ใช่แหล่งแก้ไข)

\#\#\# 10.0.2 สคีมาตามตาราง (Table-by-Table)

\#\#\# ตาราง areas — พื้นที่เชิงภูมิศาสตร์และเมตาดาต้า  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`ARE-{SEQ}\`) — UNIQUE    
\- UK: \`uq\_areas\_area\_name\` (area\_name) — UNIQUE (สมมติองค์กรเดียว)    
\- FK: none (parent-of): ExtensionCodes.row\_id; Child-of: none

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---:|---|---:|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | pk | คีย์ภายใน (UUID v4) — ใช้เป็น API area\_id |  
| id | varchar(14) | UNIQUE | NO | trigger | CHECK (id \~ '^ARE-\\d{10}$') | uq\_areas\_id | รหัสสั้นอ่านง่าย (ARE-0000000001) |  
| created\_at | timestamptz | \- | NO | now() | \- | idx\_areas\_created\_at | วันที่สร้าง (UTC) |  
| updated\_at | timestamptz | \- | NO | now() | \- | idx\_areas\_updated\_at | วันที่แก้ไขล่าสุด (UTC) |  
| version | integer | \- | NO | 1 | CHECK (version \> 0\) | \- | optimistic locking |  
| area\_name | varchar(255) | \- | NO | | \- | idx\_areas\_area\_name | ชื่อพื้นที่ (unique within org) |  
| province\_id | varchar(10) | \- | NO | | \- | idx\_areas\_province\_id | รหัสจังหวัด (จาก geo master) |  
| district\_id | varchar(20) | \- | NO | | \- | idx\_areas\_district\_id | รหัสอำเภอ |  
| subdistrict\_id | varchar(20) | \- | NO | | \- | idx\_areas\_subdistrict\_id | รหัสตำบล |  
| postal\_code | varchar(5) | \- | NO | | CHECK (postal\_code \~ '^\\d{5}$') | idx\_areas\_postal\_code | ได้จาก Address Master (read-only ใน UI) |  
| address\_line | text | \- | YES | NULL | \- | \- | บรรทัดที่อยู่เพิ่มเติม |  
| description | text | \- | YES | NULL | \- | \- | คำอธิบาย |  
| status | text | \- | NO | 'Active' | CHECK (status IN ('Active','Inactive')) | idx\_areas\_status | สถานะพื้นที่ (Active/Inactive) |  
| created\_by | varchar(50) | \- | YES | NULL | \- | idx\_areas\_created\_by | ผู้สร้าง (ERP employee\_id as string, e.g., EMP-1001) |  
| updated\_by | varchar(50) | \- | YES | NULL | \- | idx\_areas\_updated\_by | ผู้แก้ไขล่าสุด (ERP employee\_id string) |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- API field \`area\_id\` ↔ DB \`row\_id\` (UUID v4). API รายงาน/รับ area\_id เป็น UUID (ตามตัวอย่าง API).    
\- DB มี \`id\` (ARE-...) เป็น public short-id (ไม่ได้ถูกใช้เป็น primary key ใน API ปัจจุบัน). Mapping บันทึกใน 10.5.

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- row\_id: 3fa85f64-5717-4562-b3fc-2c963f66afa6    
\- id: ARE-0000000001    
\- area\_name: "พื้นที่ภาคกลาง"    
\- province\_id: "10"    
\- district\_id: "1001"    
\- subdistrict\_id: "100101"    
\- postal\_code: "10110"    
\- address\_line: "ถนนประชา"    
\- description: "ศูนย์ทดลอง"    
\- status: "Active"    
\- version: 3    
\- created\_at: 2025-01-01T08:00:00Z    
\- created\_by: "EMP-1001"

\---

\#\#\# ตาราง extension\_codes — รหัสต่อสาย (Extension Codes)  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`EXT-{SEQ}\`) — UNIQUE    
\- UK: \`uq\_extension\_codes\_display\_code\` (lower(display\_code)) — UNIQUE (global)    
\- FK: \`area\_row\_id → areas.row\_id (ON UPDATE CASCADE ON DELETE RESTRICT)\`    
\- Parent-of: ExtensionCodeAssignments.row\_id / Child-of: Areas.row\_id

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---:|---|---:|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | pk | internal UUID (API ext\_code\_id maps to this) |  
| id | varchar(14) | UNIQUE | NO | trigger | CHECK (id \~ '^EXT-\\d{10}$') | uq\_extension\_codes\_id | public short-id |  
| created\_at | timestamptz | \- | NO | now() | \- | idx\_extension\_codes\_created\_at | สร้างเมื่อ |  
| updated\_at | timestamptz | \- | NO | now() | \- | idx\_extension\_codes\_updated\_at | แก้ไขล่าสุด |  
| version | integer | \- | NO | 1 | CHECK (version \> 0\) | \- | optimistic locking |  
| display\_code | varchar(4) | \- | NO | | CHECK (display\_code \~ '^\\d{4}$') | idx\_extension\_codes\_display\_code | รหัส 4 หลัก (normalized) |  
| display\_code\_normalized | varchar(4) | \- | NO | | CHECK (display\_code\_normalized \~ '^\\d{4}$') | uq\_extension\_codes\_display\_code | lower/normalized copy for uniqueness (enforced unique) |  
| area\_row\_id | uuid | FK → areas.row\_id | NO | | \- | idx\_extension\_codes\_area\_row\_id | FK ไปยัง areas.row\_id |  
| note | text | \- | YES | NULL | \- | \- | หมายเหตุ |  
| status | text | \- | NO | 'EMPTY' | CHECK (status IN ('EMPTY','OCCUPIED')) | idx\_extension\_codes\_status | สถานะอนุมานจากการมี assignment (อ่านได้) |  
| created\_by | varchar(50) | \- | YES | NULL | \- | \- | ผู้สร้าง (ERP employee\_id string) |  
| updated\_by | varchar(50) | \- | YES | NULL | \- | \- | ผู้แก้ไขล่าสุด (ERP employee\_id string) |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- API \`ext\_code\_id\` ↔ DB \`row\_id\` (UUID v4).    
\- API \`display\_code\` ↔ DB \`display\_code\` (เก็บเป็น string 4 หลัก); DB เก็บ \`display\_code\_normalized\` เพื่อบังคับ unique (case-insensitive — แม้เป็นตัวเลข, แต่ใช้ normalized column เพื่อตรงตามกฎ).

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- row\_id: f1e2d3c4-b5a6-4c7d-9e8f-0123456789ab    
\- id: EXT-0000000001    
\- display\_code: "0123"    
\- display\_code\_normalized: "0123"    
\- area\_row\_id: 3fa85f64-5717-4562-b3fc-2c963f66afa6 (อ้างอิง areas.row\_id)    
\- status: "EMPTY"    
\- note: "สำรอง"    
\- version: 1    
\- created\_at: 2025-06-01T09:00:00Z

\---

\#\#\# ตาราง extension\_code\_assignments — การมอบหมายโค้ด (active mapping)  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`ECA-{SEQ}\`) — UNIQUE    
\- UK: \`uq\_eca\_ext\_code\_row\_id\` (ext\_code\_row\_id) — UNIQUE (R1: ext\_code only one active assignment)    
\- UK: \`uq\_eca\_employee\_id\` (employee\_id) — UNIQUE (R2: officer มี active code ได้เพียงหนึ่ง)    
\- FK: \`ext\_code\_row\_id → extension\_codes.row\_id (ON UPDATE CASCADE ON DELETE CASCADE)\`    
\- FK: \`area\_row\_id → areas.row\_id (ON UPDATE CASCADE ON DELETE RESTRICT)\` (denormalized for quick lookup; derived from ext\_code)    
\- Parent-of: none / Child-of: ExtensionCodes, Areas

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---:|---|---:|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | pk | internal UUID |  
| id | varchar(14) | UNIQUE | NO | trigger | CHECK (id \~ '^ECA-\\d{10}$') | uq\_eca\_id | public short-id |  
| created\_at | timestamptz | \- | NO | now() | \- | idx\_eca\_created\_at | timestamp of assignment |  
| assigned\_at | timestamptz | \- | NO | now() | \- | idx\_eca\_assigned\_at | เวลา assign |  
| ext\_code\_row\_id | uuid | FK → extension\_codes.row\_id | NO | | | idx\_eca\_ext\_code\_row\_id | FK (unique) |  
| employee\_id | varchar(50) | \- | NO | | | idx\_eca\_employee\_id | ERP employee id string (e.g., EMP-4001) — unique active constraint |  
| area\_row\_id | uuid | FK → areas.row\_id | NO | | | idx\_eca\_area\_row\_id | denormalized area of the code (for quick filtering) |  
| assigned\_by | varchar(50) | \- | YES | NULL | | idx\_eca\_assigned\_by | actor (ERP employee id string) |  
| version | integer | \- | NO | 1 | CHECK (version \> 0\) | \- | optimistic locking |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- API uses \`ext\_code\_id\` (UUID) → maps to \`ext\_code\_row\_id\` (linking column). API returns \`assigned.employee\_id\` etc. For write operations, API receives ext\_code\_id as path UUID which maps to ext\_code\_row\_id.

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- row\_id: 9b1d6f50-8b6f-4d2a-9c0b-1234567890ab    
\- id: ECA-0000000001    
\- ext\_code\_row\_id: f1e2d3c4-b5a6-4c7d-9e8f-0123456789ab    
\- employee\_id: "EMP-4001"    
\- area\_row\_id: 3fa85f64-5717-4562-b3fc-2c963f66afa6    
\- assigned\_at: 2025-11-02T09:00:00Z    
\- assigned\_by: "EMP-0001"

\---

\#\#\# ตาราง area\_head\_assignments — การมอบหมายหัวหน้าพื้นที่ (current)  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`AHD-{SEQ}\`) — UNIQUE    
\- UK: \`uq\_area\_head\_area\_row\_id\_employee\_id\` (area\_row\_id, employee\_id) — UNIQUE (ห้ามซ้ำ)    
\- FK: \`area\_row\_id → areas.row\_id (ON UPDATE CASCADE ON DELETE CASCADE)\`    
\- Parent-of: none / Child-of: Areas

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---:|---|---:|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | pk | internal UUID |  
| id | varchar(14) | UNIQUE | NO | trigger | CHECK (id \~ '^AHD-\\d{10}$') | uq\_area\_head\_id | public short-id |  
| area\_row\_id | uuid | FK → areas.row\_id | NO | | | idx\_area\_head\_area\_row\_id | FK |  
| employee\_id | varchar(50) | \- | NO | | | idx\_area\_head\_employee\_id | ERP employee id |  
| assigned\_at | timestamptz | \- | NO | now() | \- | idx\_area\_head\_assigned\_at | เวลา assign |  
| assigned\_by | varchar(50) | \- | YES | NULL | \- | \- | actor |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- API path uses \`area\_id\` (UUID) → maps to \`areas.row\_id\` → used to filter area head records.

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- row\_id: a12b3c4d-5e6f-7a8b-9c0d-1234567890ab    
\- id: AHD-0000000001    
\- area\_row\_id: 3fa85f64-5717-4562-b3fc-2c963f66afa6    
\- employee\_id: "EMP-1002"    
\- assigned\_at: 2025-02-01T09:00:00Z    
\- assigned\_by: "EMP-0001"

\---

\#\#\# ตาราง directors — ผู้กำกับ (global role assignments)  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`DIR-{SEQ}\`) — UNIQUE    
\- UK: \`uq\_directors\_employee\_id\` (employee\_id) — UNIQUE    
\- FK: none / Parent-of: none

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---:|---|---:|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | pk | internal UUID |  
| id | varchar(14) | UNIQUE | NO | trigger | CHECK (id \~ '^DIR-\\d{10}$') | uq\_directors\_id | public short-id |  
| employee\_id | varchar(50) | \- | NO | | | idx\_directors\_employee\_id | ERP employee id |  
| assigned\_at | timestamptz | \- | NO | now() | \- | idx\_directors\_assigned\_at | เวลา assign |  
| assigned\_by | varchar(50) | \- | YES | NULL | \- | \- | actor |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- API uses \`employee\_id\` strings for director endpoints; DB stores same in employee\_id column; internal row\_id used for internal joins if needed.

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- row\_id: b21c3d4e-6f7a-8b9c-0d1e-0987654321ab    
\- id: DIR-0000000001    
\- employee\_id: "EMP-0005"    
\- assigned\_at: 2025-01-10T08:00:00Z

\---

\#\#\# ตาราง erp\_employees — อ่านอย่างเดียว (mirror/lookup)  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`ERP-{SEQ}\`) — UNIQUE (internal short id for mirror)    
\- UK: \`uq\_erp\_employees\_employee\_id\` (employee\_id) — UNIQUE    
\- FK: none / Parent-of: none

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---:|---|---:|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | pk | internal UUID |  
| id | varchar(14) | UNIQUE | NO | trigger | CHECK (id \~ '^ERP-\\d{10}$') | uq\_erp\_id | public short-id (mirror) |  
| employee\_id | varchar(50) | \- | NO | | | idx\_erp\_employee\_id | ERP native id string (e.g., EMP-4001) |  
| full\_name | varchar(255) | \- | YES | NULL | \- | \- | ชื่อเต็ม |  
| email | varchar(320) | \- | YES | NULL | CHECK (email \~ '^\[^@\\s\]+@\[^@\\s\]+\\.\[^@\\s\]+$') | idx\_erp\_email | อีเมล |  
| dept | varchar(100) | \- | YES | NULL | \- | \- | แผนก |  
| title | varchar(100) | \- | YES | NULL | \- | \- | ตำแหน่ง |  
| status | text | \- | NO | 'active' | CHECK (status IN ('active','inactive')) | idx\_erp\_status | สถานะจาก ERP (active/inactive) |  
| last\_synced\_at | timestamptz | \- | YES | NULL | \- | idx\_erp\_last\_synced\_at | เวลา sync ล่าสุด (mirror) |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- ERP lookup API returns employee objects; server maps to this mirror table for read operations. Other tables store actor as employee\_id string; if foreign-key joins are required, reference erp\_employees.row\_id (optional) per integration.

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- row\_id: c31d4e5f-6a7b-8c9d-0e1f-1234509876ab    
\- id: ERP-0000000001    
\- employee\_id: "EMP-4001"    
\- full\_name: "อ้อม ตัวอย่าง"    
\- email: "om@example.com"    
\- dept: "Field"    
\- title: "Officer"    
\- status: "active"    
\- last\_synced\_at: 2025-11-01T00:00:00Z

\#\#\#\#= 10.0.3 แนวทางการตั้งดัชนี (Indexing Hints)  
\- สร้างดัชนีสำหรับทุก FK: idx\_extension\_codes\_area\_row\_id, idx\_eca\_ext\_code\_row\_id, idx\_eca\_area\_row\_id, idx\_area\_head\_area\_row\_id.    
\- Exact-lookup indexes: uq\_extension\_codes\_display\_code (on display\_code\_normalized), idx\_areas\_area\_name, idx\_erp\_employee\_id, idx\_extension\_codes\_status.    
\- Composite index suggestion: idx\_areas\_status\_updated\_at (status, updated\_at DESC) เพื่อ support default sort.    
\- ดัชนีชื่อชัดเจนตามนโยบาย: idx\_\<table\>\_\<col\> / uq\_\<table\>\_\<cols\>.

\---

\#\# 10.1 ERD  
\`\`\`mermaid  
erDiagram  
  AREAS ||--o{ EXTENSION\_CODES : "has"  
  AREAS ||--o{ AREA\_HEAD\_ASSIGNMENTS : "has"  
  EXTENSION\_CODES ||--o{ EXTENSION\_CODE\_ASSIGNMENTS : "has"  
  DIRECTORS ||--o{ : "global"  
  ERPEMPLOYEES ||--o{ : "lookup"

  AREAS {  
    uuid row\_id PK  
    varchar id  
    varchar area\_name  
    varchar province\_id  
    varchar district\_id  
    varchar subdistrict\_id  
    varchar postal\_code  
    text address\_line  
    text description  
    text status  
  }  
  EXTENSION\_CODES {  
    uuid row\_id PK  
    varchar id  
    varchar display\_code  
    uuid area\_row\_id FK  
    text note  
    text status  
  }  
  EXTENSION\_CODE\_ASSIGNMENTS {  
    uuid row\_id PK  
    varchar id  
    uuid ext\_code\_row\_id FK  
    varchar employee\_id  
    uuid area\_row\_id FK  
    timestamptz assigned\_at  
  }  
  AREA\_HEAD\_ASSIGNMENTS {  
    uuid row\_id PK  
    varchar id  
    uuid area\_row\_id FK  
    varchar employee\_id  
    timestamptz assigned\_at  
  }  
  DIRECTORS {  
    uuid row\_id PK  
    varchar id  
    varchar employee\_id  
    timestamptz assigned\_at  
  }  
  ERPEMPLOYEES {  
    uuid row\_id PK  
    varchar id  
    varchar employee\_id  
    varchar full\_name  
    varchar email  
    text status  
  }  
\`\`\`

(ความหมายความสัมพันธ์: AREAS ||--o{ EXTENSION\_CODES \= 1:N; EXTENSION\_CODES }o--o{ EXTENSION\_CODE\_ASSIGNMENTS \= implemented as 1:1 via unique constraint on ext\_code\_row\_id; AREA\_HEAD\_ASSIGNMENTS 1:N to AREAS)

\#\# 10.2 ไฮไลท์ DDL & นโยบายคีย์  
\- Extension prerequisite:  
  \- CREATE EXTENSION IF NOT EXISTS pgcrypto;  
\- PK: ทุกตารางมี \`row\_id UUID PRIMARY KEY DEFAULT gen\_random\_uuid()\`.  
\- Public ID:  
  \- ทุกตารางมี \`id VARCHAR(\<prefix\_len \+ 1 \+ 10\>) NOT NULL UNIQUE\` \+ CHECK regex \`'^\<PREFIX\>-\\d{10}$'\`.  
  \- Sequence \+ trigger per ตาราง: seq\_\<table\>\_public\_id และ fn\_\<table\>\_make\_public\_id() \+ trg\_\<table\>\_public\_id BEFORE INSERT (ตามเทมเพลตใน Guideline).  
  \- Prefixes ใช้: Areas=ARE, ExtensionCodes=EXT, ExtensionCodeAssignments=ECA, AreaHeadAssignments=AHD, Directors=DIR, ErpEmployees=ERP. digits\_len=10 (default).  
\- FK policy:  
  \- ทุก FK อ้างอิง parent.row\_id; ดีฟอลต์: ON UPDATE CASCADE ON DELETE RESTRICT ยกเว้นตารางประเภท \*\_assignments/\*\_history ที่มี ON DELETE CASCADE (เช่น ext\_code\_assignments.ext\_code\_row\_id → extension\_codes.row\_id ON DELETE CASCADE).  
  \- ตัวอย่าง: fk\_extension\_codes\_area\_row\_id → areas.row\_id (ON UPDATE CASCADE ON DELETE RESTRICT).  
\- Unique & business constraints:  
  \- uq\_extension\_codes\_display\_code on display\_code\_normalized (global unique) — enforce regex ^\\d{4}$ ผ่าน CHECK.  
  \- ext\_code\_assignments: uq\_eca\_ext\_code\_row\_id (ext\_code\_row\_id unique) และ uq\_eca\_employee\_id (employee\_id unique) — บังคับ R1, R2.  
  \- area\_name unique (uq\_areas\_area\_name) — สมมติองค์กรเดียว (assumption บันทึกใน 10.5).  
\- Checks:  
  \- status fields stored as TEXT with CHECK lists per Canonical (Active/Inactive; EMPTY/OCCUPIED).  
  \- postal\_code CHECK ^\\d{5}$.  
\- Concurrency:  
  \- optimistic locking via version integer CHECK (version \> 0). All PUT/PATCH require If-Match header mapped to version.  
\- Idempotency:  
  \- Server expects X-Idempotency-Key on POST create/assign/reassign; application-level de-dup handled outside DB (or via idempotency table not modeled here).  
\- Index naming conventions:  
  \- FK name: fk\_\<child\>\_\<parent\>\_\<column\> e.g., fk\_extension\_codes\_areas\_area\_row\_id  
  \- UNIQUE: uq\_\<table\>\_\<cols\>  
  \- INDEX: idx\_\<table\>\_\<col1\>\_\<col2\>  
\- Note on ExtensionCodes deletion:  
  \- Physical DELETE disallowed by policy R6 — enforce at application layer; DB may omit ON DELETE CASCADE for extension\_codes to prevent accidental deletes; prefer soft-delete if required.

\#\# 10.3 พจนานุกรมข้อมูล (Field Dictionary แบบเต็ม)

\- ตาราง: areas  
  \- row\_id: uuid; 36; NOT NULL; gen\_random\_uuid(); PK; ตัวอย่าง: 3fa85f64-5717-4562-b3fc-2c963f66afa6; PII: NO  
  \- id: varchar(14); 14; NOT NULL; trigger; 'ARE-0000000001'; Public short id; PII: NO  
  \- area\_name: varchar(255); 255; NOT NULL; ; 'พื้นที่ภาคกลาง'; PII: NO  
  \- province\_id: varchar(10); 10; NOT NULL; ; '10'; PII: NO  
  \- district\_id: varchar(20); 20; NOT NULL; ; '1001'; PII: NO  
  \- subdistrict\_id: varchar(20); 20; NOT NULL; ; '100101'; PII: NO  
  \- postal\_code: varchar(5); 5; NOT NULL; ; '10110'; Source: Address Master; Read-only in UI; PII: NO  
  \- address\_line: text; \-; NULL; NULL; 'ถนนประชา'; PII: YES (address) — Masking at API layer by RBAC  
  \- description: text; \-; NULL; NULL; 'ศูนย์ทดลอง'; PII: NO  
  \- status: text; \-; NOT NULL; 'Active'; Allowed: Active, Inactive; PII: NO  
  \- version: integer; \-; NOT NULL; 1; CHECK \>0; PII: NO  
  \- created\_at: timestamptz; \-; NOT NULL; now(); 2025-01-01T08:00:00Z; PII: NO  
  \- created\_by: varchar(50); 50; NULL; NULL; 'EMP-1001'; PII: NO (employee id) — mask sensitive display if required  
  \- updated\_at: timestamptz; \-; NOT NULL; now(); 2025-03-01T10:00:00Z; PII: NO  
  \- updated\_by: varchar(50); 50; NULL; NULL; 'EMP-1002'; PII: NO

\- ตาราง: extension\_codes  
  \- row\_id: uuid; 36; NOT NULL; gen\_random\_uuid(); PK; f1e2d3c4-b5a6-...; PII: NO  
  \- id: varchar(14); 14; NOT NULL; trigger; 'EXT-0000000001'; PII: NO  
  \- display\_code: varchar(4); 4; NOT NULL; ; '0123'; CHECK ^\\d{4}$; PII: NO  
  \- display\_code\_normalized: varchar(4); 4; NOT NULL; ; '0123'; Used for case-insensitive uniqueness; PII: NO  
  \- area\_row\_id: uuid; 36; NOT NULL; FK → areas.row\_id; ; PII: NO  
  \- note: text; \-; NULL; NULL; 'สำรอง'; PII: NO  
  \- status: text; \-; NOT NULL; 'EMPTY'; CHECK IN ('EMPTY','OCCUPIED'); PII: NO  
  \- version: integer; \-; NOT NULL; 1; CHECK \>0; PII: NO  
  \- created\_at: timestamptz; \-; NOT NULL; now(); 2025-06-01T09:00:00Z; PII: NO  
  \- created\_by: varchar(50); 50; NULL; NULL; 'EMP-1002'; PII: NO

\- ตาราง: extension\_code\_assignments  
  \- row\_id: uuid; 36; NOT NULL; gen\_random\_uuid(); PK; 9b1d6f50-...; PII: NO  
  \- id: varchar(14); 14; NOT NULL; trigger; 'ECA-0000000001'; PII: NO  
  \- ext\_code\_row\_id: uuid; 36; NOT NULL; FK → extension\_codes.row\_id; ; PII: NO  
  \- employee\_id: varchar(50); 50; NOT NULL; ; 'EMP-4001'; Employee ERP id; PII: NO (masking per RBAC)  
  \- area\_row\_id: uuid; 36; NOT NULL; FK → areas.row\_id; ; denormalized for fast queries; PII: NO  
  \- assigned\_at: timestamptz; \-; NOT NULL; now(); 2025-11-02T09:00:00Z; PII: NO  
  \- assigned\_by: varchar(50); 50; NULL; NULL; 'EMP-0001'; actor; PII: NO  
  \- version: integer; \-; NOT NULL; 1; CHECK \>0; PII: NO

\- ตาราง: area\_head\_assignments  
  \- row\_id: uuid; 36; NOT NULL; gen\_random\_uuid(); PK; a12b3c4d-...; PII: NO  
  \- id: varchar(14); 14; NOT NULL; trigger; 'AHD-0000000001'; PII: NO  
  \- area\_row\_id: uuid; 36; NOT NULL; FK → areas.row\_id; ; PII: NO  
  \- employee\_id: varchar(50); 50; NOT NULL; ; 'EMP-1002'; PII: NO  
  \- assigned\_at: timestamptz; \-; NOT NULL; now(); 2025-02-01T09:00:00Z; PII: NO  
  \- assigned\_by: varchar(50); 50; NULL; NULL; 'EMP-0001'; PII: NO

\- ตาราง: directors  
  \- row\_id: uuid; 36; NOT NULL; gen\_random\_uuid(); PK; b21c3d4e-...; PII: NO  
  \- id: varchar(14); 14; NOT NULL; trigger; 'DIR-0000000001'; PII: NO  
  \- employee\_id: varchar(50); 50; NOT NULL; ; 'EMP-0005'; PII: NO  
  \- assigned\_at: timestamptz; \-; NOT NULL; now(); 2025-01-10T08:00:00Z; PII: NO  
  \- assigned\_by: varchar(50); 50; NULL; NULL; 'EMP-0001'; PII: NO

\- ตาราง: erp\_employees  
  \- row\_id: uuid; 36; NOT NULL; gen\_random\_uuid(); PK; c31d4e5f-...; PII: NO  
  \- id: varchar(14); 14; NOT NULL; trigger; 'ERP-0000000001'; PII: NO  
  \- employee\_id: varchar(50); 50; NOT NULL; ; 'EMP-4001'; Native ERP id; PII: NO  
  \- full\_name: varchar(255); 255; NULL; NULL; 'อ้อม ตัวอย่าง'; PII: YES (mask at API layer)  
  \- email: varchar(320); 320; NULL; NULL; 'om@example.com'; PII: YES (mask)  
  \- dept: varchar(100); 100; NULL; NULL; 'Field'; PII: NO  
  \- title: varchar(100); 100; NULL; NULL; 'Officer'; PII: NO  
  \- status: text; \-; NOT NULL; 'active'; CHECK IN ('active','inactive'); PII: NO  
  \- last\_synced\_at: timestamptz; \-; NULL; NULL; 2025-11-01T00:00:00Z; PII: NO

(หมายเหตุ: PII/Masking — email, full\_name, address\_line เป็น PII; masking ต้องทำใน API layer ตาม RBAC)

\#\# 10.4 Enums & Patterns  
\- status (Areas): TEXT \+ CHECK (status IN ('Active','Inactive')) — canonical mapping: active → Active; inactive → Inactive    
\- status (ExtensionCodes): TEXT \+ CHECK (status IN ('EMPTY','OCCUPIED')) — canonical mapping preserved    
\- roles (ในระบบ RBAC): System Admin, Director, Area Head, Extension Officer (ใช้ในบริการ auth ไม่เป็น DB enum)    
\- Patterns / Regex:  
  \- display\_code: ^\\d{4}$    
  \- postal\_code: ^\\d{5}$    
  \- Public id format: ^ARE-\\d{10}$, ^EXT-\\d{10}$, ^ECA-\\d{10}$, ^AHD-\\d{10}$, ^DIR-\\d{10}$, ^ERP-\\d{10}$

\#\# 10.5 Conflict Log & Candidate Fields  
\- ความขัดแย้ง Canonical ↔ API และการตัดสินใจ:  
  1\. Canonical/API ระบุ area\_id / ext\_code\_id เป็น UUID v4 (เป็นตัวระบุที่ API ใช้). แต่นโยบาย Short-ID บังคับให้มี public short-id \`id\`. ตัดสินใจ: เก็บ \`row\_id UUID PK\` และ expose API \`area\_id\`/\`ext\_code\_id\` เป็นค่า \`row\_id\` (ยอมให้ legacy API ยังคงใช้ UUID). เพิ่มคอลัมน์ \`id\` (ARE-/EXT-...) เป็น public short-id ตามนโยบาย. บันทึก: mapping API area\_id/ext\_code\_id ↔ DB row\_id. (เหตุผล: เคารพ Canonical ที่ API ใช้ UUID และปฏิบัติตาม Short-ID policy โดยเพิ่ม public short-id สำหรับอนาคต)    
  2\. Canonical ระบุ area\_id / ext\_code\_id เป็น "pk" — ปรับให้ \`row\_id\` เป็น PK แทน และ treat API UUID เป็น same-as row\_id. บันทึกในช่องนี้ว่าเราไม่ได้สร้าง separate business UUID column named area\_id; API area\_id \= row\_id.  
\- ฟิลด์จาก API ที่ไม่อยู่ใน Canonical (Candidate Fields):  
  \- \`display\_code\_normalized\` (technical) — candidate เพื่อบังคับ unique case-insensitive (แม้เป็นตัวเลข)    
  \- \`id\` (public short-id) — เพิ่มตาม Short-ID policy (candidate/technical)    
  \- \`area\_row\_id\` ใน extension\_code\_assignments — denormalized column เพื่อประสิทธิภาพ (candidate)    
\- สมมติที่เติมเอง (และเหตุผล):  
  \- digits\_len \= 10 สำหรับ public id (ตาม Default)    
  \- Prefixes: ARE, EXT, ECA, AHD, DIR, ERP (เลือก 3 ตัวอักษรสื่อความหมาย)    
  \- area\_name unique constraint: ตั้งเป็น UNIQUE เพราะอินพุตกล่าว "unique within org" แต่ไม่มี org\_id ในโมเดล — สมมติระบบเป็น org เดียวหรือ scope global; ถ้ามีหลาย org ในอนาคต ต้องปรับ schema โดยเพิ่ม org\_row\_id และเปลี่ยน unique เป็น (org\_row\_id, area\_name). (documented)    
  \- เก็บ \`status\` ใน extension\_codes แม้จะเป็น "derived" — เก็บเพื่อการค้นหา/ดัชนี แต่ต้องรักษาความสอดคล้องโดย application/trigger (บันทึกว่าเป็น derived).    
  \- created\_by/assigned\_by เก็บเป็น ERP employee\_id string (ไม่บังคับ FK) เพื่อความยืดหยุ่น/ไม่ผูกแน่นกับ mirror; สามารถเพิ่ม assigned\_by\_row\_id (FK) ในอนาคตถ้าต้องการ. (สาเหตุ: API ตัวอย่างส่ง/รับ assigned\_by เป็น employee\_id strings)  
\- Mapping/API ↔ DB representation differences:  
  \- API \`area\_id\`, \`ext\_code\_id\`, \`ext\_code\_assignments.\*.ext\_code\_id\` are UUIDs; map to DB \`row\_id\`. Documented mapping required in server layer.    
  \- Public short-id \`id\` exists in DB but API currently uses UUIDs; server may choose to include both in responses (e.g., { "area\_id": "\<uuid\>", "id": "ARE-000..." }).  
  \- display\_code uniqueness enforced via \`display\_code\_normalized\` (database) to ensure global uniqueness case-insensitive; API will accept/display \`display\_code\` (normalized at server).  
\- ฟิลด์จาก API ที่ไม่ได้เก็บใน DB (โดยเจตนา):  
  \- No physical deletion of extension\_codes allowed (R6) — DB does not provide DELETE; application enforces.

\#\# 10.6 Data Lineage & Integration Notes  
\- แหล่งความจริง / Integration:  
  \- ErpEmployees: Source of truth \= ERP system. DB stores read-only mirror for lookups; any authoritative employee status checks should call ERP or mirror should be synced frequently. Action validation (R11) must verify ERP employee status (active) prior to assignment; if ERP unreachable → return 424 FAILED\_DEPENDENCY.  
  \- Postal\_code: Source of truth \= Address Master (geo service). UI read-only; DB stores postal\_code populated from geo service during create/update of Area (or via background sync). Any change to subdistrict\_id should re-resolve postal\_code from geo master.  
  \- Extension Code assignments: current active mapping stored in extension\_code\_assignments (single source of truth for active assignment). Full audit/history must be stored in separate audit/history table (not modeled here) — recommended to emit outbox events and persist change snapshots in audit store.  
  \- Status derivation: extension\_codes.status \= derived from existence of active assignment in extension\_code\_assignments; we store status for efficient queries but must reconcile via transactional updates on assign/reassign/unassign.  
\- การออกแบบเพื่อหลีกเลี่ยง duplicated business facts:  
  \- ไม่เก็บ duplicate assignment history ในตาราง active mapping; ใช้ separate audit/history table or event store for historical records.  
  \- Area effective officers derived via join ext\_code\_assignments → extension\_codes → areas (do not duplicate officer lists in areas table).  
\- Events / outbound integration (recommended per API notes):  
  \- ext\_code.assigned, ext\_code.reassigned, ext\_code.renamed, area.updated — ส่ง event พร้อม payload keys (ext\_code\_id, display\_code, area\_row\_id, employee\_id, timestamps) เพื่อให้ downstream ระบบ (analytics / export / sync) อัพเดต.

\---