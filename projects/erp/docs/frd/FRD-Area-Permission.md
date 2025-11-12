\# 1\. Feature Overview  
\- Feature Id : feat\_area-permission\_20251109120000  
\- Feature Name : พื้นที่และการกำหนดสิทธิ์  
\- Module : AGM การบริหาร / การควบคุมการเข้าถึง  
\- Base Path : /agm/admin/area-permission  
\- Menu Trail : AGM \> การบริหาร \> พื้นที่และการกำหนดสิทธิ์

\---

\# 2\. Objective & Background

\#\# 2.1 Objectives  
\- มี authoritative source สำหรับ Area และ Extension Code ที่รองรับการสร้าง แก้ไข เปิด/ปิด และการจัดการวงจรชีวิตของโค้ด (create/rename/assign/reassign) ภายในระบบ AGM  
\- มอบหมาย/ย้ายความเป็นเจ้าของ (ownership) ของ Extension Code ให้ผู้ปฏิบัติงานคนเดียวต่อโค้ด โดยยืนยันเงื่อนไข uniqueness (4-digit display\_code) และ 1 person \= 1 active code  
\- ให้การบริหารบทบาทรวมศูนย์ (Directors, Area Heads, Extension Officers) ที่สามารถเพิ่ม/ลบ และกำหนดสิทธิ์การเข้าถึงตามบทบาทได้  
\- ส่ง outbound domain events (ext\_code.assigned, ext\_code.reassigned, ext\_code.renamed, area.updated) เมื่อมีการ assign/reassign/rename/area.updated เพื่อให้ downstream systems สามารถอัพเดตการมองเห็นได้  
\- บังคับความสอดคล้องเชิงเทคนิคโดยใช้ X-Idempotency-Key สำหรับการเรียกซ้ำที่ปลอดภัย และ If-Match/version (optimistic locking) เพื่อป้องกัน race condition

\#\# 2.2 Business Context  
\- ปัญหาปัจจุบัน: ไม่มีแหล่งข้อมูลอ้างอิงเดียวสำหรับพื้นที่ปฏิบัติการและโค้ดเจ้าหน้าที่ ทำให้ downstream system ไม่สามารถอ้างอิง area\_id/ext\_code ที่เชื่อถือได้  
\- ทำไมต้องทำตอนนี้: ต้องการลดความผิดพลาดในการมองเห็นข้อมูลและการอ้างอิงผู้สร้างในระบบ downstream (Farmer/Quota ฯลฯ) และรองรับการควบคุมสิทธิ์แบบรวมศูนย์  
\- สภาพที่ต้องการ: ระบบกลางที่เป็น authoritative source สำหรับ Area/Extension Code พร้อมการบังคับกฎความเป็นเอกลักษณ์ ส่ง event ไปยังระบบอื่นเมื่อมีการเปลี่ยนแปลง เพื่อให้ downstream สามารถดึงค่า area\_id/ext\_code ได้ถูกต้อง  
\- Journey หลักที่ต้องรองรับ: สร้าง/แก้ไข/เปิด-ปิด Area (Areas tab → Create/Edit/Toggle) เพื่อให้ข้อมูลพื้นที่เป็น authoritative source  
\- Journey หลักที่ต้องรองรับ: สร้าง/เปลี่ยนชื่อ/มอบหมาย/ย้าย Extension Code (Extension Codes page / Roles → Officers) โดยต้องรองรับ atomic reassign และ guard ความเป็นเอกลักษณ์  
\- Journey หลักที่ต้องรองรับ: การจัดการบทบาทแบบรวมศูนย์ (Directors, Area Heads, Extension Officers) เพื่อควบคุมการเข้าถึงและการมอบหมาย

\#\# 2.3 Success Metrics (KPIs)  
\- KPI: Success rate ของ Assign/Reassign ≥ 99.5% (เปอร์เซ็นต์ของคำสั่ง assign/reassign ที่สำเร็จ)  
\- KPI: End-to-end Assign/Reassign p95 ≤ 10s (รวมเวลาที่ใช้ในการค้นหา ERP)  
\- KPI: 0 ต่อเดือน ของ data consistency violations สำหรับ R1 และ R2 (เช่น duplicate display\_code หรือ employee มีมากกว่า 1 active code)  
\- KPI: Rename collisions \< 0.5% ต่อเดือน (การชนกันของการเปลี่ยนชื่อโค้ด)  
\- KPI: Export failures ≤ 1% ต่อเดือน (ความล้มเหลวของการส่งออก CSV)

\#\#\# Warnings (if any)  
\- ขอบเขตการควบคุมเมนูบนระดับแพลตฟอร์มอยู่นอกฟีเจอร์นี้ (Menu visibility ถูกควบคุมโดย platform)  
\- ระดับการรับประกันการส่ง event (delivery guarantees, retry/backoff) ไม่ได้ระบุรายละเอียดระบบ event bus ที่ใช้ — ข้อมูลนี้ยังไม่ชัดเจน  
\- รายละเอียด schema ของ outbound events นอกเหนือจากฟิลด์ที่ระบุอาจต้องกำหนดเพิ่มเติมระหว่างการออกแบบการบูรณาการ

\# 3\. Scope & Constraints

\#\# 3.1 In Scope  
\- การทำ CRUD สำหรับ Areas (Create, Read, Update; ยกเว้น Delete) รวมถึงการเปิด/ปิด (activate/deactivate) พร้อม guards (เช่น ห้าม deactivate ถ้ามี Extension Codes ที่ OCCUPIED)  
\- วงจรชีวิตของ Extension Codes: create (EMPTY), rename (If-Match), assign (EMPTY → OCCUPIED), reassign (OCCUPIED → EMPTY target) โดยไม่มีการลบโค้ด  
\- หน้าจอและฟังก์ชันการจัดการบทบาท: Directors, Area Heads, Extension Officers (global management)  
\- การค้นหา ERP แบบอ่านอย่างเดียว (ERP employee directory read-only) และ cascade ที่อยู่พร้อม postal auto-fill โดยอิงจาก Address Master  
\- รายการ/การส่งออก (export CSV) ของ Areas, Roles, Extension Codes และ timeline ของ audit สำหรับกิจกรรมสำคัญ  
\- หน้าที่ครอบคลุม (จาก Page Definitions):  
  \- หน้าที่ครอบคลุม: Areas tab (Route: /agm/admin/area-permission?tab=areas) — ตารางรายการ, ค้นหา/กรอง, Create Area, Export, pagination  
  \- หน้าที่ครอบคลุม: Area Detail (Route: /agm/admin/areas/:id) — Overview, Area Heads management, Extension Codes ของ Area, Audit timeline  
  \- หน้าที่ครอบคลุม: Extension Codes (Route: /agm/admin/extension-codes) และ Extension Code Detail (/agm/admin/extension-codes/:id) — สร้าง, เปิด, Assign/Reassign, Rename  
\- Journey-specific coverage (จาก User Journeys):  
  \- Journey หลัก: สร้าง Area (Areas tab → Create Area → POST /api/areas) พร้อม validations และ deep-link ไปยัง Area Detail  
  \- Journey หลัก: Assign/Reassign Extension Code (Roles → Officers หรือ Extension Codes page → POST /api/extension-codes/:id/assign หรือ /:from\_id/reassign) โดยต้องเป็น atomic operation และส่ง event หลังการเปลี่ยนแปลง  
  \- Journey หลัก: บริหารบทบาท Directors/Area Heads (Roles tab → POST/DELETE /api/roles/directors และ /api/areas/:id/heads)

\#\# 3.2 Out of Scope  
\- การบังคับกรองข้อมูลในระบบ downstream (Farmer/Quota) — downstream ต้องดึง area\_id/ext\_code เองตามข้อมูลจาก event/API  
\- การควบคุมการมองเห็นเมนูระดับแพลตฟอร์ม (menu visibility)  
\- Effective-dating windows หรือประวัติสถานะเวอร์ชันแบบมีช่วงเวลา — assignments เป็น current-only เท่านั้น  
\- การลบ (delete) ของ Areas หรือ Extension Codes

\#\# 3.3 Assumptions  
\- ERP Employee Directory พร้อมใช้แบบ read-only ผ่าน GET /api/erp/employees?query= และให้ข้อมูล employee\_id, active status, email  
\- Address Master พร้อมให้บริการผ่าน /api/geo/\* และคืน postal\_code จาก subdistrict\_id  
\- Clients จะส่ง X-Idempotency-Key สำหรับคำร้องที่ต้อง idempotent (create/assign/reassign)  
\- API clients จะส่ง If-Match/version header สำหรับการแก้ไขที่ต้อง optimistic locking  
\- ฐานข้อมูลจะบังคับ unique constraints ที่จำเป็น (เช่น unique display\_code per system, unique assignment per employee) ตาม R1–R7  
\- มีระบบ event bus หรือ message broker เพื่อส่ง outbound domain events ตามรายการใน Integrations  
\- RBAC enforcement ถูกเตรียมในระบบ (Admin/Director full; Area Head limited to own area; Officer read-only)

\#\# 3.4 Dependencies & Integrations  
\- Upstream (Inbound, read-only):  
  \- ERP Employee Directory — GET /api/erp/employees?query= (ใช้สำหรับค้นหา/validate employee\_id และสถานะ active)  
  \- Address Master — GET /api/geo/provinces, /api/geo/districts, /api/geo/subdistricts; GET /api/geo/postal?subdistrict\_id= (ใช้สำหรับ cascade ที่อยู่และ postal auto-fill)  
\- Downstream (Outbound events):  
  \- ext\_code.assigned {ext\_code\_id, display\_code, area\_id, employee\_id, assigned\_at}  
  \- ext\_code.reassigned {employee\_id, from\_code, to\_code, area\_id, at}  
  \- ext\_code.renamed {ext\_code\_id, old\_code, new\_code, at}  
  \- area.updated {area\_id, fields\_changed, at, actor}  
\- Observability:  
  \- ทุกคำขอควรบรรจุ request\_id ใน logs  
  \- เก็บ metrics ของ assign/reassign/rename counts และ failure rates; instrument p95 latency สำหรับ assign/reassign  
\- API Endpoints (จาก Page Definitions/ Journeys):  
  \- Areas: GET /api/areas, POST /api/areas, PUT /api/areas/{id}, PATCH /api/areas/{id}/status, GET /api/areas/:id  
  \- Extension Codes: GET /api/extension-codes, POST /api/extension-codes, PUT /api/extension-codes/:id/rename, POST /api/extension-codes/:id/assign, POST /api/extension-codes/:from\_id/reassign  
  \- Roles: GET/POST/DELETE endpoints for /api/roles/directors and /api/areas/:id/heads

\#\#\# Warnings (if any)  
\- ข้อมูลเกี่ยวกับระบบ event bus (URL, protocol, delivery semantics, retry policy) ยังไม่ระบุ — ต้องตกลงก่อนการดำเนินการอินทิเกรชันเชิงลึก  
\- ความต้องการด้าน authorization scopes (OAuth scopes, service account) สำหรับการเรียก ERP/Address Master และการส่ง event ไม่ได้ระบุอย่างชัดเจน  
\- ข้อจำกัด "area anchor ถูกสมมติไว้" ระบุในสโคป — หากต้องเปลี่ยนเป็น multi-anchor จะกระทบโมเดลข้อมูลและต้องเพิ่มเติมข้อกำหนดอีกครั้ง

\# 4\. Target Users & RBAC

\> Feature: พื้นที่และการกำหนดสิทธิ์ · Module: AGM การบริหาร / การควบคุมการเข้าถึง · Base Path: /agm/admin/area-permission · Menu: AGM \> การบริหาร \> พื้นที่และการกำหนดสิทธิ์

\#\# 4.1 Personas / Roles  
\- \*\*System Admin (platform)\*\* — ผู้ดูแลระบบระดับแพลตฟอร์ม: ควบคุมเต็มรูปแบบสำหรับการตั้งค่า สร้าง/แก้ไข/ลบ/สถานะของ Areas และ Extension Codes, มอบหมายเจ้าหน้าที่ และเข้าถึง audit/export ทั้งระบบ  
\- \*\*Director (global role)\*\* — ผู้กำกับระดับสูง: มองเห็นและบริหารจัดการบทบาทระดับโลก (เพิ่ม/ลบ Directors) และมองเห็นทุก Area/Code; มีสิทธิ์ระดับสูงใกล้เคียง Admin สำหรับการจัดการเชิงกำกับ  
\- \*\*Area Head\*\* — หัวหน้าพื้นที่: มองเห็นข้อมูลและรายละเอียดเฉพาะ Area ที่ได้รับมอบหมาย (Area-scoped read & limited management such as request change); ไม่ได้มีสิทธิ์แก้ไขข้อมูล Master โดยตรง แต่สามารถร้องขอการเปลี่ยนแปลงให้ Admin/Director ดำเนินการ  
\- \*\*Extension Officer\*\* — เจ้าหน้าที่ภาคสนาม: ทำงานเฉพาะใน Extension Code ที่ถูกมอบหมาย (tagged by ext\_code ของตน); มองเห็นข้อมูล downstream เฉพาะที่เกี่ยวข้องกับ ext\_code ของตน (read-only)  
\- \*\*Audit/QA\*\* — ผู้ตรวจสอบ/คุณภาพ: สิทธิ์อ่านอย่างเดียวสำหรับรายการ รายละเอียด และ audit trails; ไม่สามารถแก้ไขหรือเปลี่ยนสถานะใดๆ  
\- \*\*Admin/Owner\*\* — (ใช้สลับกับ System Admin เมื่อเรียกทั่วไป): รับผิดชอบการทำงานเชิงปฏิบัติการและการกำหนดนโยบายการเข้าถึง (ใช้คำนี้ในเอกสารเชื่อมโยงว่าเป็นเจ้าของ Feature/Module)

\#\# 4.2 Action Taxonomy, Route & API patterns, Row/Field-level constraints

Action Taxonomy (standard \+ journey-specific)  
\- view:list  
\- view:detail  
\- search/filter  
\- export:csv  
\- create  
\- update  
\- delete:soft  
\- restore  
\- status:activate  
\- status:inactivate|suspend|reactivate  
\- approve  
\- reject  
\- bulk:\<action\>  
\- assign (journey: assign officer to ExtensionCode)  
\- reassign (journey: reassign officer from one ExtensionCode to another)  
\- rename (journey: rename display\_code via rename endpoint)  
\- export:pdf (not present in inputs — หมายเหตุใน Warnings หากจำเป็น)  
\- open:view-only (used for opening Code/Area detail)  
\- audit:view (ดู audit timeline)

Route & API patterns (derived from base\_path and entities)  
\- Pages (routes)  
  \- /agm/admin/area-permission  
  \- /agm/admin/area-permission?tab=areas  
  \- /agm/admin/areas/create  
  \- /agm/admin/areas/:id  
  \- /agm/admin/areas/:id/edit  
  \- /agm/admin/roles/directors  
  \- /agm/admin/roles/heads  
  \- /agm/admin/roles/officers  
  \- /agm/admin/extension-codes  
  \- /agm/admin/extension-codes/create  
  \- /agm/admin/extension-codes/:id  
  \- /agm/admin/extension-codes/:id/rename  
  \- /agm/admin/extension-codes/:id/assign  
  \- /agm/admin/extension-codes/:id/reassign  
\- APIs (patterns)  
  \- GET /api/areas  
  \- POST /api/areas  
  \- GET /api/areas/{id}  
  \- PUT /api/areas/{id}  
  \- PATCH /api/areas/{id}/status  
  \- GET /api/areas/{id}/heads  
  \- POST /api/areas/{id}/heads  
  \- DELETE /api/areas/{id}/heads/{employee\_id}  
  \- GET /api/extension-codes  
  \- POST /api/extension-codes  
  \- GET /api/extension-codes/{id}  
  \- PUT /api/extension-codes/{id}/rename  
  \- POST /api/extension-codes/{id}/assign  
  \- POST /api/extension-codes/{from\_id}/reassign  
  \- GET /api/roles/directors  
  \- POST /api/roles/directors  
  \- DELETE /api/roles/directors/{employee\_id}  
  \- Export endpoints (per Lists): GET /api/areas/export, GET /api/extension-codes/export (pattern: GET /export endpoints / export:csv)

Row / Field-level constraints (จาก Use Cases / Roles)  
\- Area Head: สามารถ view:list / view:detail เฉพาะ Areas ที่เป็นของตน (area-scoped filter)  
\- Extension Officer: สามารถ view:list / view:detail เฉพาะ records ที่มี tagging ด้วย ext\_code ของตน (ext\_code-scoped)  
\- Director: มองเห็นทุก Area/Code (global)  
\- Queries/exports ต้องถูกกรองตาม RBAC ก่อนจัดส่ง (Any authorized user can search/filter/export แต่ผลลัพธ์ถูกจำกัดตามบทบาท)  
\- Field-level: postal\_code เป็น read-only (RO) ใน create (auto-populated) และ edit สำหรับ Admin/Director (ตาม Journey); ไม่อนุญาตแก้ไขโดย Area Head/Officer

Permission Matrix (symbol: ✓ \= อนุญาต, — \= ไม่อนุญาต, C \= อนุญาตแบบมีเงื่อนไข)  
\- Entities: Areas, ExtensionCodes, ExtensionCodeAssignments (assignments represented via assign/reassign actions)  
\- Roles columns: System Admin | Director | Area Head | Extension Officer | Audit/QA

Areas (entity: Areas)  
| Action / Role | System Admin | Director | Area Head | Extension Officer | Audit/QA |  
|---|---:|---:|---:|---:|---:|  
| view:list | ✓ | ✓ | ✓ (C: only own Area) | ✓ (C: only related ext\_code areas?) | ✓ |  
| view:detail | ✓ | ✓ | ✓ (C: only own Area) | ✓ (C: read-only for related code) | ✓ |  
| search/filter | ✓ | ✓ | ✓ (C: scoped) | ✓ (C: scoped) | ✓ |  
| export:csv | ✓ | ✓ | C (only export own Area data) | C (minimal/own data only) | ✓ |  
| create | ✓ | ✓ | — | — | — |  
| update | ✓ | ✓ | — (C: only request change; no direct update) | — | — |  
| delete:soft | ✓ | ✓ | — | — | — |  
| restore | ✓ | ✓ | — | — | — |  
| status:activate | ✓ | ✓ | — | — | — |  
| status:inactivate | ✓ | ✓ | — | — | — |  
| bulk:\<action\> | ✓ | ✓ | C (limited to own Area operations if any) | — | — |  
| audit:view | ✓ | ✓ | ✓ (own Area) | ✓ (own code only) | ✓ |

Conditions (Areas)  
\- Area Head: view/update/export are scoped to Areas they head (C \= must pass area\_id match).  
\- Extension Officer: view rights limited to Areas that contain their assigned ExtensionCode(s).  
\- Deactivate guard: status:inactivate blocked if Area has OCCUPIED codes (enforced by System).

ExtensionCodes (entity: ExtensionCodes)  
| Action / Role | System Admin | Director | Area Head | Extension Officer | Audit/QA |  
|---|---:|---:|---:|---:|---:|  
| view:list | ✓ | ✓ | ✓ (C: only codes in own Area) | ✓ (C: only own code(s)) | ✓ |  
| view:detail | ✓ | ✓ | ✓ (C: read) | ✓ (C: read for own code) | ✓ |  
| search/filter | ✓ | ✓ | ✓ (scoped) | ✓ (scoped) | ✓ |  
| export:csv | ✓ | ✓ | C (Area-scoped) | C (own-code only) | ✓ |  
| create | ✓ | ✓ | — | — | — |  
| rename | ✓ | ✓ | — | — | — |  
| assign | ✓ | ✓ | — | — | — |  
| reassign | ✓ | ✓ | — | — | — |  
| delete:soft | ✓ | ✓ | — | — | — |  
| audit:view | ✓ | ✓ | ✓ (Area) | ✓ (own code) | ✓ |

Conditions (ExtensionCodes)  
\- rename: enforced as rename-only via PUT /api/extension-codes/{id}/rename with If-Match (optimistic lock)  
\- assign: allowed only when Code.status \== EMPTY; employee must not have active code  
\- reassign: atomic move; target must be EMPTY; race conditions may return 423  
\- Area Head: read-only for codes in their Area  
\- Extension Officer: read-only only for their own assigned code(s)

ExtensionCodeAssignments (assign/reassign operations)  
| Action / Role | System Admin | Director | Area Head | Extension Officer | Audit/QA |  
|---|---:|---:|---:|---:|---:|  
| assign (create assignment) | ✓ | ✓ | — | — | — |  
| reassign (move assignment) | ✓ | ✓ | — | — | — |  
| view assignments | ✓ | ✓ | ✓ (Area-scoped) | ✓ (own assignment) | ✓ |

Additional conditional notes  
\- All write operations that mutate resources (create/PUT/rename/assign/reassign/status) use optimistic concurrency: If-Match required; POST create endpoints support X-Idempotency-Key where specified.  
\- Exports must be filtered by RBAC server-side.  
\- Audit trails: accessible to roles with audit:view (all roles have some audit visibility per scope; Audit/QA has full read).

Approval / Status definitions  
\- Canonical statuses per Canonical Map: Active/Inactive for Areas; EMPTY/OCCUPIED for ExtensionCodes.  
\- Deactivation guard: Area cannot be set to Inactive if any ExtensionCode in Area is OCCUPIED (Journey C).  
\- Approval flows: No multi-step approval flows specified in inputs; mark in Warnings if required.

\#\# 4.3 Page / Tab / Modal → Action mapping (with RBAC binding)

Top-level Page: /agm/admin/area-permission (Tabbed)  
\- Default tab: Areas  
\- Available to: System Admin, Director, Area Head (view-scoped), Extension Officer (read-scoped), Audit/QA (read)  
\- Actions on page: navigation only; tab switching no special permission

Tab: Areas (Route: /agm/admin/area-permission?tab=areas)  
\- Components → Actions:  
  \- Search bar / Filters → search/filter (view:list) — permitted per RBAC (Server filters results)  
  \- Create Area button → open Area Create Drawer → create (POST /api/areas) — allowed: System Admin, Director  
  \- Export → export:csv (GET /api/areas/export) — allowed: System Admin, Director; Area Head / Officer conditional (scoped)  
  \- Table row actions:  
    \- Open → view:detail (GET /api/areas/{id}) — allowed per scoped view  
    \- Edit → update (PUT /api/areas/{id}) — allowed: System Admin, Director  
    \- Toggle status → status:activate / status:inactivate (PATCH /api/areas/{id}/status) — allowed: System Admin, Director (blocked if OCCUPIED codes)

Page: Area Detail (Route: /agm/admin/areas/:id)  
\- Sections & Actions:  
  \- Overview card → view:detail — visible per RBAC  
  \- Area Heads tab:  
    \- GET /api/areas/:id/heads → view:list (heads) — System Admin, Director, Area Head (if own Area), Audit/QA  
    \- Add Head (ERP search) → POST /api/areas/:id/heads — System Admin, Director  
    \- Remove Head → DELETE /api/areas/:id/heads/{employee\_id} — System Admin, Director  
  \- Extension Codes tab:  
    \- GET /api/extension-codes?area\_id=:id → view:list — scoped per RBAC  
    \- Actions per code: open (view:detail), rename, assign/reassign — rename/assign/reassign only System Admin/Director  
  \- Audit timeline → audit:view — allowed per RBAC scope (Audit/QA full, others scoped)

Page: Area Create (Drawer) (Route: /agm/admin/areas/create)  
\- Actions:  
  \- create → POST /api/areas (X-Idempotency-Key) — System Admin, Director  
  \- postal\_code: read-only auto-populated (RO)  
\- Permissions: Admin/Director only

Page: Area Edit (Drawer) (Route: /agm/admin/areas/:id/edit)  
\- Actions:  
  \- update → PUT /api/areas/{id} (If-Match) — System Admin, Director  
  \- postal\_code: RO, cannot be edited  
\- Permissions: Admin/Director only

Tab: Roles (Route: /agm/admin/area-permission?tab=roles) — Sub-tabs: Directors / Area Heads / Extension Officers  
\- Directors sub-tab (Route: /agm/admin/roles/directors)  
  \- GET /api/roles/directors — view:list — System Admin, Director  
  \- POST /api/roles/directors {employee\_id} — create Director — System Admin, Director  
  \- DELETE /api/roles/directors/{employee\_id} — System Admin, Director  
  \- Export — export:csv — System Admin, Director  
\- Area Heads sub-tab (Route: /agm/admin/roles/heads)  
  \- GET area lists with heads — view:list — System Admin, Director  
  \- POST /api/areas/:area\_id/heads — add head — System Admin, Director  
  \- DELETE /api/areas/:area\_id/heads/{employee\_id} — remove head — System Admin, Director  
\- Extension Officers sub-tab (Route: /agm/admin/roles/officers)  
  \- GET /api/extension-codes — list codes — System Admin, Director, Area Head (scoped)  
  \- Create Code → POST /api/extension-codes (modal) — System Admin, Director  
  \- Assign → POST /api/extension-codes/:id/assign — System Admin, Director  
  \- Reassign → POST /api/extension-codes/:from\_id/reassign — System Admin, Director  
  \- Rename → PUT /api/extension-codes/:id/rename (If-Match) — System Admin, Director

Page: Extension Codes (Full screen) (Route: /agm/admin/extension-codes)  
\- Actions:  
  \- view:list / search / filter / export — permitted per RBAC (Director full, Head scoped, Officer scoped)  
  \- Create Code (modal) → create — System Admin, Director  
  \- Row actions:  
    \- Open → view:detail — permitted per RBAC  
    \- Assign → assign — System Admin, Director (only if EMPTY)  
    \- Reassign → reassign — System Admin, Director  
    \- Rename → rename — System Admin, Director

Page: Extension Code Detail (Route: /agm/admin/extension-codes/:id)  
\- Actions:  
  \- view:detail — permitted per RBAC (Head if within area; Officer if own code; Director/System Admin global)  
  \- rename → PUT /api/extension-codes/:id/rename (If-Match) — System Admin/Director  
  \- assign → POST /api/extension-codes/:id/assign — System Admin/Director (when EMPTY)  
  \- reassign → POST /api/extension-codes/:id/reassign — System Admin/Director (when OCCUPIED \-\> target EMPTY)  
  \- audit:view — see audit timeline — permitted per RBAC scope

Modals  
\- Create Extension Code (/agm/admin/extension-codes/create) — create → System Admin/Director  
\- Rename Code (/agm/admin/extension-codes/:id/rename) — rename → System Admin/Director (If-Match)  
\- Assign Officer (/agm/admin/extension-codes/:id/assign) — assign → System Admin/Director  
\- Reassign Officer (/agm/admin/extension-codes/:id/reassign) — reassign → System Admin/Director

Bindings from Journeys → Pages/Actions (high-level)  
\- Journey A (Areas: Create) → Page: Area Create Drawer → Action: create (POST /api/areas) — System Admin/Director  
\- Journey B (Areas: Edit) → Page: Area Edit Drawer → Action: update (PUT /api/areas/{id}) — System Admin/Director  
\- Journey C (Activate/Deactivate) → Areas table row / Area Detail → Action: status:activate/status:inactivate (PATCH /api/areas/{id}/status) — System Admin/Director (guard: no OCCUPIED codes)  
\- Journey I/J/K/L (ExtensionCodes create/rename/assign/reassign) → Extension Codes page / Detail / Modals → Actions: create, rename, assign, reassign — System Admin/Director  
\- Journey M (Lists: Search/Filter/Export) → Areas / ExtensionCodes pages → Actions: search/filter/export:csv — results always RBAC-filtered server-side

Warnings (ข้อควรระวัง / ข้อที่ไม่ชัดเจน)  
\- ไม่มี API หรือ field ระบุสำหรับ "Area Head ร้องขอการเปลี่ยนแปลง" (journey ระบุว่า Area Head สามารถร้องขอการเปลี่ยนแปลง แต่ไม่พบ endpoint เช่น POST /api/areas/:id/requests) — หากต้องการ flow นี้ จำเป็นต้องเพิ่ม API/UX ระบุ request/approval model  
\- ไม่มีการระบุ Approval workflow (approve/reject) สำหรับการเปลี่ยนแปลงหรือมอบหมาย: inputs ไม่ได้กำหนดขั้นตอนอนุมัติหลายขั้น ดังนั้นตารางใช้สิทธิ์ตรง (no approver role) — หากต้องการ multi-step approval โปรดระบุ  
\- ไม่พบการกล่าวถึง export:pdf หรือ download:doc ใน Use Cases/Pages — หากต้องการให้มี ให้เพิ่มเส้นทาง/endpoint ที่ชัดเจน  
\- ขอบเขตการมองเห็นของ Extension Officer กับ Areas: ระบุว่า “มองเห็นข้อมูลใน downstream เฉพาะเรคคอร์ดที่มี tagging ด้วย ext\_code ของตน” — ไม่ชัดเจนว่ารวมถึงการเห็น Area-level metadata หรือเฉพาะ records; กำหนดเป็น "C: read-only for related code" แต่หากต้องการจำกัดมากขึ้น โปรดระบุรายละเอียด  
\- การ mapping ของ "Officer minimal" ใน Tab: Areas (Page Definitions) กับ fields/columns ที่ Officer จะเห็นไม่ได้ระบุชัด (เช่น heads\_count, codes\_count อาจเป็นข้อมูล summary ที่ Officer ไม่ต้องเห็น) — โปรดยืนยันรายการคอลัมน์ที่ต้องซ่อนสำหรับ Officer  
\- การจัดการ concurrency/locking: Journeys ระบุ If-Match/optimistic lock และ error codes แต่ไม่มีรายละเอียดเกี่ยวกับ version field name/version policy — สมมติใช้ header If-Match กับ resource version; ถ้าต้องการชื่อฟิลด์/รูปแบบ ให้ระบุเพิ่มเติม

(สิ้นสุด Section 4\)

\# 6\. Capabilities Overview & Layout Patterns

\> Feature: \*\*พื้นที่และการกำหนดสิทธิ์\*\* · Module: \*\*AGM การบริหาร / การควบคุมการเข้าถึง\*\* · Base Path: \*\*/agm/admin/area-permission\*\* · Menu: \*\*AGM \> การบริหาร \> พื้นที่และการกำหนดสิทธิ์\*\*

\#\# 6.1 เป้าหมายและกรอบความสามารถ (ยึดตาม use cases)  
\- รองรับการจัดการ Areas และ Extension Codes (Create / Read / Update / status toggle)  
\- รองรับการมอบ/ย้าย/ลบบทบาท: Directors, Area Heads, Extension Officers  
\- รายการ (Lists) ต้องมี Search / Filters / Sorting / Pagination / Export CSV  
\- สร้าง/มอบหมาย/ย้ายต้องรองรับ Idempotency (X-Idempotency-Key) สำหรับ POST  
\- แก้ไข/เปลี่ยนสถานะต้องใช้ Optimistic Locking (If-Match / ETag)  
\- บันทึก Audit (create/edit/status/assignment/rename/reassign) และส่ง event/webhook (ตาม Journey)  
\- บังคับใช้ RBAC ตามบทบาท (Admin/Director/Area Head/Officer/Audit) และ scope-filter server-side  
\- ตรวจจับ Conflict/Concurrency (409/412/423/424) และโชว์ inline errors / dialog guidance

\#\# 6.2 Layout Patterns (ตัวอย่างอ้างอิง — ให้ AI สร้างจริงตามอินพุต)  
\- List Page  
  \- Header: Breadcrumb \+ H1 title \+ subtitle \[\*\*Card\*\*\]  
  \- Toolbar: \[\*\*SearchBar\*\*\] \+ Filters (province/district/status) \+ Action buttons (Export, Primary CTA)  
  \- Main: \[\*\*MasterDataTable\*\*\] (checkbox leftmost, fixed header, compact rows)  
  \- Footer: \[\*\*PaginationControls\*\*\] \+ results summary  
\- Create / Edit Drawer  
  \- Drawer (slide-in right, width=40%): Header \[\*\*DrawerHeader\*\*\], Form body \[\*\*FormLayout\*\*\], sticky footer with primary action \[\*\*Button(primary)\*\*\]  
  \- Use Idempotency for Create; If-Match for Edit; postal\_code field read-only (RO)  
\- Detail Page (Overview \+ Tabs)  
  \- Header: title \+ status badge \+ actions (Edit, Toggle Status)  
  \- Tabs row: Overview | Area Heads | Extension Codes | Audit  
  \- Body: Overview card (Key–Value 2-col), Tabs panels (Tables \+ action bars), Audit timeline  
  \- If no matching library template → render as custom full-screen layout (tabs \+ KPI \+ content)  
\- Dialogs / Modals / Drawers  
  \- Confirmations: center modal, focus trap, Cancel / Confirm (danger) patterns  
  \- Create/Rename/Assign/Reassign: modal forms with validation, optimistic headers as required  
\- Cross-cutting  
  \- Primary action button always right-most in toolbar/footer  
  \- Table rules: checkbox leftmost, numeric right-aligned, badges centered  
  \- Accessibility: aria-labels, role attributes, logical focus order, WCAG 2.1 AA

\#\# 6.3 Navigation Rules  
\- URLs (standardized): List=\`\<base\_path\>\`, Create=\`\<base\_path\>/new\`, Detail=\`\<base\_path\>/:id\`, Edit=\`\<base\_path\>/:id/edit\`  
\- ห้ามเข้าหน้า \*\*Edit\*\* เมื่อสถานะเป็น \*\*Archived\*\* (จะ redirect ไป List \+ toast 403\)  
\- หาก RBAC ไม่เพียงพอ → redirect ไป List \+ show \*\*toast 403\*\* (ข้อความไทย)  
\- Create/Update สำเร็จ → navigate → Detail (deep-link) \+ toast success  
\- 412 (ETag mismatch) → fetch latest → show "มีการเปลี่ยนแปลงแล้ว" dialog ช่วย merge / retry

\#\# 6.4 Microcopy & States (i18n/A11y)  
\- โทนคริปต์มาตรฐาน (ไทย): success / error / empty / 403 / 409 / 412  
\- ทุกปุ่ม/ลิงก์/รายการมี aria-label หรือ aria-labelledby  
\- Focus order: Toolbar → Search/Filters → Table → Action (modal focus trap)  
\- Error feedback: inline field message (aria-invalid \+ aria-describedby) และ global toast (role="status")  
\- Empty states ต้องมีแอ็กชันแนะนำ (เช่น \*\*สร้างพื้นที่ใหม่\*\*)

\#\# 6.5 Page–Journey Cohesion (ใหม่)  
\- แต่ละหน้า/โมดัลต้องผูกกับ Journey step: ปุ่ม/เมนู → journey\_id → API (method+path) → preconditions (RBAC/Status/Validation) → post-effects (navigate/toast/events)  
\- Visibility & Action Gating: เรียกใช้ RBAC matrix (A2) และ guards จาก A3 (e.g., block deactivate when OCCUPIED codes)  
\- Templates: เลือกเทมเพลตจากไลบรารีก่อน ถ้าไม่พอ → custom layout (บันทึก template\_source=custom)

\#\#\# Warnings (ข้อควรระวัง)  
\- เทมเพลตไลบรารีมี List/Drawer/Modal templates แต่ไม่มีเทมเพลต "Detail full-screen with Tabs \+ KPI row" ที่ตรงกันทั้งหมด → จะใช้ \*\*Custom ASCII\*\* สำหรับ Area Detail และ Extension Code Detail (template\_source=custom, reason=needs full-screen tabs \+ audit timeline)    
\- ไม่พบ API สำหรับ "unassign only" (ลบ assignment โดยไม่ reassign) ใน inputs → หากต้องการ ให้เพิ่ม endpoint (Warnings: missing\_unassign\_endpoint)    
\- Approval workflow แบบ multi-step ไม่ได้ถูกกำหนดในอินพุต (Inputs ใช้ immediate-effect) — ถ้าต้องการโปรดเพิ่ม (Warnings: approval\_missing)  

\---

\# 7\. Page Inventory (URLs & Screens)

\> Feature: \*\*พื้นที่และการกำหนดสิทธิ์\*\* · Base Path: \*\*/agm/admin/area-permission\*\*

\#\# 7.1 URLs & Routing  
\- \*\*List\*\*: \`/agm/admin/area-permission\` — เริ่ม \`?tab=areas\&page=1\&page\_size=25\&sort=area\_name\`  
\- \*\*Create (Area Drawer)\*\*: \`/agm/admin/areas/create\`  
\- \*\*Detail (Area)\*\*: \`/agm/admin/areas/:id\`  
\- \*\*Edit (Area Drawer)\*\*: \`/agm/admin/areas/:id/edit\`  
\- \*\*Roles (Tabbed)\*\*: \`/agm/admin/area-permission?tab=roles\`  
\- \*\*Directors\*\*: \`/agm/admin/roles/directors\`  
\- \*\*Area Heads (global)\*\*: \`/agm/admin/roles/heads\`  
\- \*\*Extension Officers (global)\*\*: \`/agm/admin/roles/officers\`  
\- \*\*Extension Codes (Full Screen)\*\*: \`/agm/admin/extension-codes\`  
\- \*\*Extension Code Detail\*\*: \`/agm/admin/extension-codes/:id\`  
\- \*\*Create Extension Code (Modal)\*\*: \`/agm/admin/extension-codes/create\`  
\- \*\*Rename Code (Modal)\*\*: \`/agm/admin/extension-codes/:id/rename\`  
\- \*\*Assign Officer (Modal)\*\*: \`/agm/admin/extension-codes/:id/assign\`  
\- \*\*Reassign Officer (Modal)\*\*: \`/agm/admin/extension-codes/:id/reassign\`  
\- \*\*Routing guards\*\*: ห้ามเข้า Edit เมื่อ resource.status=\`Archived\`; RBAC ไม่พอ → redirect List \+ \*\*toast 403\*\*

\---

\#\# 7.2 Page Definitions  
(ทำซ้ำหนึ่งบล็อกต่อหนึ่งหน้า/แท็บ/โมดัล ตามอินพุต)

\#\#\# 7.2.1 Root: Area & Permission (Tabbed) — \`/agm/admin/area-permission\`  
\*\*Purpose\*\*: ทางเข้าเดสก์ท็อปของฟีเจอร์; แสดง Tabs: \*\*Areas\*\* (default) และ \*\*Roles\*\*

\#\#\#\# Layout  
\- Custom full-width page with top Breadcrumb \+ H1 \+ Tabs row; 12-col grid; Tabs control main content (slot-based)  
\- Grid Spec: 12col; header blocks; tabs row; content pane full-width

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| Breadcrumbs: AGM › การบริหาร › พื้นที่และการกำหนดสิทธิ์                      |  
\+------------------------------------------------------------------------------+  
| H1: พื้นที่และการกำหนดสิทธิ์                                                 |  
| Subtitle: จัดการ Areas, Extension Codes และการมอบหมายบทบาท                  |  
\+------------------------------------------------------------------------------+  
| Tabs: \[Areas (active)\]  |  \[Roles\]                                           |  
\+------------------------------------------------------------------------------+  
| Content (tab panel)                                                       ▼ |  
|  \--------------------------------------------------------------- \----------- |  
| | Left (main)                                                       | Right | |  
| |                                                                     |  \-   | |  
| |  \-- เมื่อเลือก Areas: render Areas List page (slot)               |      | |  
| |  \-- เมื่อเลือก Roles: render Roles Tabs (Directors / Heads /Off)  |      | |  
| |                                                                     |      | |  
|  \---------------------------------------------------------------------      |  
\+------------------------------------------------------------------------------+  
| Footer: \[Help\]                                 \[Last updated: —\] \[ \]        |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \`breadcrumb\` → \[\*\*Breadcrumbs\*\*\]  
\- \`page\_header\` → \[\*\*PageHeader\*\*\] (title, subtitle)  
\- \`tabs\` → \[\*\*Tabs\*\*\] (Areas, Roles)  
\- \`tab\_panel\` → renders either Areas List (7.2.2) or Roles container (7.2.7)  
\- \`toast\_host\` → \[\*\*Toast (status)\*\*\]

\#\#\#\# Actions / Events & Binding  
\- Tab switch → client update query param \`?tab=\`; no API call until inner tab requests  
\- On initial load → call GET \`/api/areas\` (when Areas tab) or GET Directors/Areas as needed (when Roles tab)  
\- Guard: if user lacks view:list → redirect to 403 toast

\#\#\#\# Validation  
\- N/A (navigation container)

\#\#\#\# RBAC & Status Gating  
\- Visible to: System Admin, Director, Area Head (scoped), Extension Officer (scoped), Audit/QA (read)  
\- Tab "Roles" actions gated to Admin/Director only (add/remove)

\#\#\#\# Microcopy (i18n/A11y)  
\- Tabs: aria-controls, aria-selected; H1 uses role="heading" level=1  
\- Empty tab panel shows guidance in Thai and primary CTA

\#\#\#\# Journey Bindings  
\- \`Journey M\`: switching to Areas → triggers List fetch with RBAC-scoped query  
\- \`Journey E/F/G/H/I-L\`: navigation hub to respective pages/modals

\#\#\#\# Notes  
\- template\_source=custom (reason: Tab container with content slots; no direct template entry in library)

\---

\#\#\# 7.2.2 Areas (List) — \`/agm/admin/area-permission?tab=areas\`  
\*\*Purpose\*\*: รายการ Areas — ค้นหา/กรอง/สร้าง/Export/Quick actions (edit / toggle status / open detail)

\#\#\#\# Layout  
\- Template: packingList.v1 (List)  
\- Grid Spec: 12col; fixed-header; toolbar right-aligned buttons; table compact; checkbox first column

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| Breadcrumbs: AGM › การบริหาร › พื้นที่และการกำหนดสิทธิ์                      |  
\+------------------------------------------------------------------------------+  
| H1 Title: พื้นที่ (Areas)                                                    |  
| H2 Subtitle: จัดการพื้นที่ปฏิบัติการ, สถานะ และหัวหน้าพื้นที่               |  
\+------------------------------------------------------------------------------+  
| 🔍 ค้นหา: \[ ค้นหาชื่อพื้นที่, รหัส, ... \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ \]          |  
|                                Filter: จังหวัด • อำเภอ • สถานะ ▾           |  
\+------------------------------------------------------------------------------+  
|                             \[ Export CSV \]  \[ สร้างพื้นที่ \]                |  
\+------------------------------------------------------------------------------+  
| \[ \] area\_id | \*\*ชื่อพื้นที่\*\* →C | จังหวัด | \#Heads | \#Codes | สถานะ | Actions |  
|--------------+------------------+----------+--------+--------+--------+------|  
| … (rows rendered by API; numeric → right, badges → center)                   |  
\+------------------------------------------------------------------------------+  
| Showing 1-25 of xxx            « Previous  \[1\]  Next »                      |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \`breadcrumb\` → \[\*\*Breadcrumbs\*\*\]  
\- \`header\_title\` → \[\*\*PageHeaderTitle\*\*\]  
\- \`header\_desc\` → \[\*\*PageDescription\*\*\]  
\- \`toolbar\_left\` → \[\*\*SearchBar\*\*\] (q)  
\- \`controls\_top\_right\` → \[\*\*FilterDropdown\*\*\] (province/district/status), \[\*\*AdvancedFilterDrawer\*\*\]  
\- \`toolbar\_right\` → \[\*\*Button(export)\*\*\], \[\*\*Button(Create Area)\*\* primary\]  
\- \`main\` → \[\*\*MasterDataTable\*\*\] columns defined below  
\- \`pagination\` → \[\*\*PaginationControls\*\*\]

Components-per-field (table columns / React-friendly)  
\- Checkbox column → \[\*\*Checkbox\*\*\] (row select)  
\- Column \`area\_id\` → hidden PK (row key)  
\- Column \`area\_name\` → \[\*\*TextCell\*\*\] (clickable → open Area Detail)  
\- Column \`province\` → \[\*\*TextCell\*\*\]  
\- Column \`heads\_count\` → \[\*\*Badge\*\*\]  
\- Column \`codes\_count\` → \[\*\*Badge\*\*\]  
\- Column \`status\` → \[\*\*StatusBadge\*\*\] (Active/Inactive)  
\- Column \`actions\` → \[\*\*ActionMenu\*\*\] with items: Open, Edit, Toggle Status

\#\#\#\# Actions / Events & Binding  
\- Initial load / search / filter → GET \`/api/areas?q={q}\&province\_id={}\&district\_id={}\&status={}\&sort={}\&page={}\&page\_size={}\`  
\- Export → GET \`/api/areas/export?q=...\` (server-side RBAC filter)  
\- Create Area (primary) → open Drawer \`/agm/admin/areas/create\`  
\- Row Open → navigate → GET \`/api/areas/{id}\` → Area Detail (\`/agm/admin/areas/:id\`)  
\- Row Edit → open Drawer \`/agm/admin/areas/{id}/edit\`  
\- Row Toggle Status → PATCH \`/api/areas/{id}/status\` header: \`If-Match: \<etag\>\` (precondition: no OCCUPIED codes)  
\- Bulk actions (if multiple selected) → POST \`/api/areas:bulk\` (only if API supports — otherwise show warning)

\#\#\#\# Validation  
\- Search inputs sanitized; Filters validated client-side  
\- Toggle Status: pre-check via lightweight API for OCCUPIED codes or server returns 409  
\- Create button visible only to roles Admin/Director

\#\#\#\# RBAC & Status Gating  
\- Admin/Director: full toolbar (Create, Export, Edit, Toggle)  
\- Area Head: row visibility scoped to own Areas (server filtered); actions disabled  
\- Extension Officer: minimal row columns (server filtered)  
\- Audit/QA: read-only

\#\#\#\# Microcopy (i18n/A11y)  
\- Search placeholder: \*\*ค้นหาชื่อพื้นที่หรือรหัส\*\* (aria-label="ค้นหา พื้นที่")  
\- Create button: \*\*สร้างพื้นที่\*\* (aria-label)  
\- Status badge: "เปิดใช้งาน" / "ปิดใช้งาน"  
\- 403/500 errors: show error banner with Retry button (aria-live="assertive")

\#\#\#\# Journey Bindings  
\- \`Journey A\` (Areas: Create): Areas page / \*\*Create Area\*\* → open Area Create Drawer → POST \`/api/areas\` (X-Idempotency-Key). Preconditions: role ∈ {Admin, Director}. On success: toast \+ list refresh \+ navigate to \`/agm/admin/areas/{id}\`.  
\- \`Journey C\` (Activate/Deactivate): Areas page / row \*\*Toggle Status\*\* → PATCH \`/api/areas/{id}/status\` (If-Match). Preconditions: Admin/Director; check no OCCUPIED codes. On conflict 409 → show inline error modal.  
\- \`Journey M\` (Lists: Search/Filter/Export): Areas page / Search/Filters/Export → GET \`/api/areas\` / GET \`/api/areas/export\` (server filters by RBAC)

\#\#\#\# Notes  
\- template\_source=packingList.v1 (library template)

\---

\#\#\# 7.2.3 Area Detail — \`/agm/admin/areas/:id\`  
\*\*Purpose\*\*: ดูข้อมูล metadata ของ Area; จัดการ Area Heads (สำหรับ Area นี้); ดู Extension Codes ที่ผูกกับ Area; ดู Audit timeline

\#\#\#\# Layout  
\- Custom full-screen Detail page with:  
  \- Header (H1, status badge, actions Edit / Toggle Status / More)  
  \- Tabs (Overview | Area Heads | Extension Codes | Audit)  
  \- Body: Overview card (Key–Value 2-col left), Tabs panels (tables/cards) right  
\- Grid Spec: 12col; header \+ tabs; content area two-column on Overview (8/4) or full-width for tables

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| Breadcrumbs: AGM › การบริหาร › พื้นที่และการกำหนดสิทธิ์ › \[ชื่อพื้นที่\]        |  
\+------------------------------------------------------------------------------+  
| H1: \*\*ชื่อพื้นที่\*\*                            \[ แก้ไข \] \[สลับสถานะ\] \[Export\] |  
| Status: \[ เปิดใช้งาน \]  · Updated: 2025-xx-xx by …                            |  
\+------------------------------------------------------------------------------+  
| Tabs: \[Overview\] | \[Area Heads\] | \[Extension Codes\] | \[Audit\]                |  
\+------------------------------------------------------------------------------+  
| Overview (left 8 cols)                          | Right (4 cols)           |  
| \+--------------------------------------------+ | \+----------------------+ |  
| | Key–Value 2-col                             | | Summary / KPIs        | |  
| | • \*\*ชื่อพื้นที่\*\* : XYZ                       | | • \#Heads: 2           | |  
| | • \*\*ที่อยู่\*\* : จังหวัด / อำเภอ / ตำบล        | | • \#Codes: 10          | |  
| | • \*\*postal\_code\*\* : 10110 (RO)               | | • Created: …          | |  
| | • …                                         | |                      | |  
| \+--------------------------------------------+ | \+----------------------+ |  
\+------------------------------------------------------------------------------+  
| Tab Panel: Area Heads  (table)                                            |  
| \[ Add Head \]  Filters: (search ERP)                                        |  
| \[ \] employee\_id | ชื่อ-สกุล | email | assigned\_at | Actions(remove)         |  
\+------------------------------------------------------------------------------+  
| Tab Panel: Extension Codes (table)                                        |  
| \[ Create Code \]  Filters: Area=This | Status=EMPTY/OCCUPIED                |  
| display\_code | status | assigned\_to | note | Actions(open/rename/assign)   |  
\+------------------------------------------------------------------------------+  
| Audit timeline: (scrollable)                                              |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \`header\` → \[\*\*PageHeader\*\*\] (title, status \[\*\*StatusBadge\*\*\], actions \[\*\*Button\*\*\])  
\- \`tabs\` → \[\*\*Tabs\*\*\]  
\- \`overview\` → \[\*\*Card(KeyValueGrid-2col)\*\*\] fields below  
\- \`right\_summary\` → \[\*\*StatCard\*\*\], \[\*\*Button\*\* (Edit)\]  
\- \`area\_heads\_table\` → \[\*\*MasterDataTable\*\*\]  
\- \`extension\_codes\_table\` → \[\*\*MasterDataTable\*\*\]  
\- \`audit\_timeline\` → \[\*\*ActivityLog\*\*\]

Components-per-field (Overview)  
\- \*\*ชื่อพื้นที่\*\* \[\*\*Text\*\*\] (field: \*\*area\_name\*\*) → \[\*\*KeyValueText\*\*\]  
\- \*\*province\_id / district\_id / subdistrict\_id\*\* → \[\*\*KeyValueText\*\*\] (display labels)  
\- \*\*postal\_code\*\* \[\*\*Text (RO)\*\*\] (field: \*\*postal\_code\*\*) → \[\*\*KeyValueText\*\*, readonly\]  
\- \*\*address\_line\*\* → \[\*\*KeyValueText\*\*\]  
\- \*\*description\*\* → \[\*\*KeyValueText\*\*\]  
\- Metadata \*\*created\_at / created\_by / updated\_at / updated\_by\*\* → \[\*\*MetaRow\*\*\]

\#\#\#\# Actions / Events & Binding  
\- On load → GET \`/api/areas/{id}\` (include Accept: application/json)  
\- Area Heads:  
  \- GET \`/api/areas/{id}/heads\`  
  \- Add Head → POST \`/api/areas/{id}/heads\` { employee\_id } (If role ∈ {Admin, Director})  
  \- Remove Head → DELETE \`/api/areas/{id}/heads/{employee\_id}\`  
\- Extension Codes (for this Area):  
  \- GET \`/api/extension-codes?area\_id={id}\`  
  \- Row Open → navigate to \`/agm/admin/extension-codes/{ext\_code\_id}\`  
  \- Rename / Assign / Reassign → open modals (7.2.11–7.2.14)  
\- Edit Area → open Edit Drawer \`/agm/admin/areas/{id}/edit\`  
\- Toggle Status → PATCH \`/api/areas/{id}/status\` header: \`If-Match: \<etag\>\` (guard: no OCCUPIED codes)

\#\#\#\# Validation  
\- Add Head: ERP employee must be active (server returns 422\)  
\- Remove Head: existence validated (404 if not found)  
\- Toggle Status: server validates OCCUPIED guard → 409 if blocked

\#\#\#\# RBAC & Status Gating  
\- Admin/Director: full actions (Edit, Add/Remove head, manage codes)  
\- Area Head: read-only for this Area (no add/remove)  
\- Extension Officer / Audit: read-only (scoped)

\#\#\#\# Microcopy (i18n/A11y)  
\- Status badge alt text: \`"สถานะ: เปิดใช้งาน"\` (aria-label)  
\- Add Head button: \*\*เพิ่มหัวหน้าพื้นที่\*\* (aria-haspopup="dialog")  
\- Postal microcopy: \*\*หมายเหตุ: รหัสไปรษณีย์อัตโนมัติ (อ่านเท่านั้น)\*\* (aria-describedby to field helper)

\#\#\#\# Journey Bindings  
\- \`Journey B\` (Edit): Area Detail / \*\*แก้ไข\*\* → open Edit Drawer → PUT \`/api/areas/{id}\` (If-Match). Preconditions: Admin/Director. On 412 → show merge dialog.  
\- \`Journey C\` (Toggle): Area Detail / \*\*สลับสถานะ\*\* → PATCH \`/api/areas/{id}/status\` (If-Match). Preconditions: no OCCUPIED codes.  
\- \`Journey G/H\` (Area Heads add/remove): Area Detail / Area Heads tab → Add/Remove calls POST/DELETE \`/api/areas/{id}/heads...\`  
\- \`Journey D\` (View): opening this page is the Journey D happy path

\#\#\#\# Notes  
\- template\_source=custom (reason: full-screen detail with Tabs \+ Audit timeline not in template list)

\---

\#\#\# 7.2.4 Area Create (Drawer) — \`/agm/admin/areas/create\`  
\*\*Purpose\*\*: ฟอร์มสร้าง Area (address cascade \+ postal auto-fill (RO))

\#\#\#\# Layout  
\- Template: createDrawer.v1 (Create Drawer — Standard)  
\- Grid Spec: Drawer:right; width=40%; vertical form; footer sticky (\[Cancel\], \[Create\])

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| Drawer: สร้างพื้นที่ใหม่                                \[ Expand \] \[  ✕  \]     |  
\+------------------------------------------------------------------------------+  
| H1: สร้างพื้นที่                                                    Subtext   |  
\+------------------------------------------------------------------------------+  
| Section: ข้อมูลพื้นที่                                                       |  
| | \*\*ชื่อพื้นที่\*\* \[\*\*Input\*\*\] (field: \*\*area\_name\*\*)                        |  
| | \*\*จังหวัด\*\* \[\*\*Select\*\* ▾\] (field: \*\*province\_id\*\*)                      |  
| | \*\*อำเภอ\*\* \[\*\*Select\*\* ▾\] (field: \*\*district\_id\*\*)                        |  
| | \*\*ตำบล\*\* \[\*\*Select\*\* ▾\] (field: \*\*subdistrict\_id\*\*)                      |  
| | \*\*รหัสไปรษณีย์\*\* : 10110 (อ่านอย่างเดียว) \[\*\*Text (RO)\*\*\] (field:\*\*postal\_code\*\*) |  
| | \*\*ที่อยู่ (เพิ่มเติม)\*\* \[\*\*Textarea\*\*\] (field: \*\*address\_line\*\*)         |  
| | \*\*คำอธิบาย\*\* \[\*\*Textarea\*\*\] (field: \*\*description\*\*)                    |  
\+------------------------------------------------------------------------------+  
| Left: \[ยกเลิก\]                                 Right: \[สร้าง\] \[บันทึกชั่วคราว\] |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \`drawer\_header\` → \[\*\*DrawerHeader\*\*\] (title, subtitle)  
\- \`form\_body\` → \[\*\*FormLayout\*\*\]  
\- \`form\_sections\` → \[\*\*FormSection\*\*\] fields below  
\- \`footer\_buttons\` → \[\*\*Button(cancel)\*\*\], \[\*\*Button(create)\*\* primary\]

Components-per-field (React-friendly)  
\- \*\*ชื่อพื้นที่\*\* \[\*\*Input\*\*\] (field: \*\*area\_name\*\*) → component: \`\<InputField name="area\_name" /\>\`  
\- \*\*province\_id\*\* \[\*\*Select\*\*\] (field: \*\*province\_id\*\*) → \`\<SelectDropdown name="province\_id" /\>\`  
\- \*\*district\_id\*\* \[\*\*Select\*\*\] (field: \*\*district\_id\*\*) → \`\<SelectDropdown name="district\_id" /\>\`  
\- \*\*subdistrict\_id\*\* \[\*\*Select\*\*\] (field: \*\*subdistrict\_id\*\*) → \`\<SelectDropdown name="subdistrict\_id" /\>\`  
\- \*\*postal\_code\*\* \[\*\*Text (RO)\*\*\] (field: \*\*postal\_code\*\*) → \`\<ReadOnlyField name="postal\_code" /\>\`  
\- \*\*address\_line\*\* \[\*\*Textarea\*\*\] (field: \*\*address\_line\*\*) → \`\<Textarea name="address\_line" /\>\`  
\- \*\*description\*\* \[\*\*Textarea\*\*\] (field: \*\*description\*\*) → \`\<Textarea name="description" /\>\`

\#\#\#\# Actions / Events & Binding  
\- On submit Create → POST \`/api/areas\`    
  \- Headers: \`X-Idempotency-Key: \<uuid\>\`    
  \- Body: { area\_name, province\_id, district\_id, subdistrict\_id, address\_line, description }    
\- On province/district/subdistrict selection → call Address master/lookup API (client) to populate postal\_code (RO)  
\- On success → 201 with resource { area\_id, version } → navigate to \`/agm/admin/areas/{area\_id}\` \+ toast success \+ refresh list  
\- On validation error → show inline messages (422)  
\- On duplicate name → 409 → show inline duplicate message  
\- On address master down → 424 → show banner with retry

\#\#\#\# Validation  
\- Required: \*\*area\_name\*\*, \*\*province\_id\*\*, \*\*district\_id\*\*, \*\*subdistrict\_id\*\*  
\- \*\*postal\_code\*\* must match ^\\d{5}$ (derived, read-only)  
\- \*\*area\_name\*\* unique (server returns 409\)  
\- Client-side: trimming, max-length checks

\#\#\#\# RBAC & Status Gating  
\- Visible/usable: Admin, Director only  
\- If user not allowed → hide Create button on Areas list and disable drawer open (client redirect \+ toast 403\)

\#\#\#\# Microcopy (i18n/A11y)  
\- Field labels in Thai; helper: "รหัสไปรษณีย์จะถูกเติมอัตโนมัติจากฐานข้อมูลที่อยู่" (aria-describedby)  
\- Create button: \*\*สร้าง\*\* (aria-label="สร้างพื้นที่")  
\- Error messages: inline under field \+ aria-live region for general errors

\#\#\#\# Journey Bindings  
\- \`Journey A\`: Areas tab / \*\*Create Area\*\* → this drawer → POST \`/api/areas\` (X-Idempotency-Key). Preconditions: role Admin/Director; postal populated via address master. On success: toast \+ list refresh \+ deep-link to Area Detail.

\#\#\#\# Notes  
\- template\_source=createDrawer.v1

\---

\#\#\# 7.2.5 Area Edit (Drawer) — \`/agm/admin/areas/:id/edit\`  
\*\*Purpose\*\*: แก้ไขข้อมูล Area (postal remains read-only)

\#\#\#\# Layout  
\- Template: editStepperDrawer.v1 (Edit Drawer template chosen because library has edit-drawer variant)  
\- Grid Spec: Drawer:right; width=45%; stepper optional but used as single-step edit; footer sticky with Save

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| Drawer: แก้ไขพื้นที่                                 \[ Expand \] \[  ✕  \]        |  
\+------------------------------------------------------------------------------+  
| H1: แก้ไขพื้นที่ — \[area\_id\]                                                  |  
| Sub: แก้ไขข้อมูลพื้นที่ (postal ไม่สามารถแก้ไขได้)                            |  
\+------------------------------------------------------------------------------+  
| Section: ข้อมูลพื้นที่                                                       |  
| | \*\*ชื่อพื้นที่\*\* \[\*\*Input\*\*\] (field: \*\*area\_name\*\*)                        |  
| | \*\*จังหวัด\*\* \[\*\*Select\*\* ▾\] (field: \*\*province\_id\*\*)                      |  
| | \*\*อำเภอ\*\* \[\*\*Select\*\* ▾\] (field: \*\*district\_id\*\*)                        |  
| | \*\*ตำบล\*\* \[\*\*Select\*\* ▾\] (field: \*\*subdistrict\_id\*\*)                      |  
| | \*\*รหัสไปรษณีย์\*\* : 10110 (อ่านอย่างเดียว) \[\*\*Text (RO)\*\*\]               |  
| | \*\*ที่อยู่ (เพิ่มเติม)\*\* \[\*\*Textarea\*\*\] (field: \*\*address\_line\*\*)         |  
| | \*\*คำอธิบาย\*\* \[\*\*Textarea\*\*\] (field: \*\*description\*\*)                    |  
\+------------------------------------------------------------------------------+  
| Left: \[ยกเลิก\]                         Right: \[ ← Back \] \[บันทึก/Update\]      |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \`drawer\_header\` → \[\*\*DrawerHeader\*\*\] (meta: entity\_code)  
\- \`content\_sections\` → \[\*\*FormLayout\*\*\]  
\- \`footer\_buttons\` → \[\*\*Button(cancel)\*\*\], \[\*\*Button(save)\*\* primary\]

Components-per-field (React-friendly)  
\- Same mapping as Create; plus hidden PK \*\*area\_id\*\* and header shows \*\*version\*\* for If-Match

\#\#\#\# Actions / Events & Binding  
\- On open → GET \`/api/areas/{id}\` (get ETag/version)  
\- On submit Save → PUT \`/api/areas/{id}\`    
  \- Headers: \`If-Match: "\<etag|version\>"\`    
  \- Body: full or patch payload per API contract    
\- On 412 → show conflict dialog with option to Fetch latest / Overwrite? (per design: fetch latest \+ show diff)  
\- On 424 → show dependency error (address master)

\#\#\#\# Validation  
\- Same as Create; additionally cannot change \*\*area\_id\*\*  
\- Postal read-only (RO)

\#\#\#\# RBAC & Status Gating  
\- Edit allowed only for Admin/Director  
\- If resource.status \= Archived → Edit button hidden (guard) and Edit route blocked client-side

\#\#\#\# Microcopy (i18n/A11y)  
\- Version info: "เวอร์ชันปัจจุบัน: {version} (ใช้ If-Match header)"  
\- Conflict message for 412: "ข้อมูลเปลี่ยนแปลงแล้ว กรุณารีเฟรชเพื่อดูเวอร์ชันล่าสุด"

\#\#\#\# Journey Bindings  
\- \`Journey B\`: Area Detail → \*\*แก้ไข\*\* → this drawer → PUT \`/api/areas/{id}\` (If-Match). On success toast \+ fields updated.

\#\#\#\# Notes  
\- template\_source=editStepperDrawer.v1 (used as Edit Drawer template)  
\- Ensure client includes If-Match header using retrieved version/ETag

\---

\#\#\# 7.2.6 Roles (Tab container) — \`/agm/admin/area-permission?tab=roles\`  
\*\*Purpose\*\*: Container for Directors / Area Heads / Extension Officers sub-tabs

\#\#\#\# Layout  
\- Tabs container (within root tab panel) — render sub-tab lists (7.2.7–7.2.9)

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| H2: บทบาท (Roles)                                                            |  
\+------------------------------------------------------------------------------+  
| Tabs: \[Directors\] | \[Area Heads\] | \[Extension Officers\]                      |  
\+------------------------------------------------------------------------------+  
| Content: (renders the selected sub-tab list and toolbar)                      |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \`tabs\` → \[\*\*Tabs\*\*\]  
\- \`tab\_panel\` → renders Directors/Heads/Officers pages

\#\#\#\# Actions / Events & Binding  
\- Switching sub-tab triggers respective GET APIs (see each sub-tab)

\#\#\#\# Validation / RBAC  
\- Only Admin/Director can add/remove roles; others read-only scoped

\#\#\#\# Journey Bindings  
\- \`Journey E–H, K–L\` map into respective sub-tab actions

\#\#\#\# Notes  
\- template\_source=custom (simple container)

\---

\#\#\# 7.2.7 Directors (Sub-Tab) — \`/agm/admin/roles/directors\`  
\*\*Purpose\*\*: เพิ่ม/ลบ Directors (global)

\#\#\#\# Layout  
\- Template: packingList.v1 (List)  
\- Grid Spec: 12col; table list for directors; search ERP input \+ Add button

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| H1: Directors                                                               |  
\+------------------------------------------------------------------------------+  
| ERP ค้นหา: \[ ค้นหาพนักงาน ERP \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ \]   \[ เพิ่ม Director \]     |  
\+------------------------------------------------------------------------------+  
| employee\_id | ชื่อ-สกุล | Email | Dept/Title | assigned\_at | Actions(remove)    |  
| \-----------------------------------------------------------------------------|  
| … rows …                                                                     |  
\+------------------------------------------------------------------------------+  
| Showing 1-25 of xx                  « Previous  \[1\]  Next »                 |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \`toolbar\_left\` → \[\*\*InputField\*\*\] (ERP search)  
\- \`toolbar\_right\` → \[\*\*Button(add)\*\*\], \[\*\*Button(export)\*\*\]  
\- \`main\` → \[\*\*MasterDataTable\*\*\] (columns below)

Components-per-field  
\- \*\*employee\_id\*\* → row key  
\- \*\*full\_name\*\* → \[\*\*TextCell\*\*\]  
\- \*\*email\*\* → \[\*\*TextCell\*\*\]  
\- \*\*dept/title\*\* → \[\*\*TextCell\*\*\]  
\- \*\*assigned\_at\*\* → \[\*\*DateCell\*\*\]  
\- Actions → \[\*\*IconButton\*\* remove\] (triggers DELETE)

\#\#\#\# Actions / Events & Binding  
\- GET \`/api/roles/directors\`  
\- POST \`/api/roles/directors\` { employee\_id } (Add) — validates ERP active; server returns 409 if already director  
\- DELETE \`/api/roles/directors/{employee\_id}\` (Remove) — 404 if not found

\#\#\#\# Validation  
\- Block inactive ERP employees (422)  
\- Duplicate → 409

\#\#\#\# RBAC & Status Gating  
\- Add/Remove allowed for Admin, Director  
\- Other roles: read-only

\#\#\#\# Microcopy (i18n/A11y)  
\- Add button: \*\*เพิ่ม Director\*\* (aria-haspopup)  
\- Remove confirmation: inline toast on success, or modal if chosen (not specified)

\#\#\#\# Journey Bindings  
\- \`Journey E\` (Add Director): Add button → POST \`/api/roles/directors\` (pre: ERP active)  
\- \`Journey F\` (Remove Director): Remove action → DELETE \`/api/roles/directors/{employee\_id}\`

\#\#\#\# Notes  
\- template\_source=packingList.v1

\---

\#\#\# 7.2.8 Area Heads (Global) — \`/agm/admin/roles/heads\`  
\*\*Purpose\*\*: จัดการหัวหน้าพื้นที่แบบรวม (เพิ่ม/ลบ สำหรับ Area ใดก็ได้)

\#\#\#\# Layout  
\- Template: packingList.v1  
\- Grid Spec: 12col; filters: Area select; ERP search; Add Head button

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| H1: Area Heads (Global)                                                      |  
\+------------------------------------------------------------------------------+  
| Filter: พื้นที่ \[ Select ▾ \]   ERP ค้นหา: \[ \_\_\_\_\_\_\_\_ \]   \[ เพิ่มหัวหน้า \]     |  
\+------------------------------------------------------------------------------+  
| employee\_id | ชื่อ-สกุล | area\_name | assigned\_at | Actions(remove)            |  
| \-----------------------------------------------------------------------------|  
| … rows …                                                                     |  
\+------------------------------------------------------------------------------+  
| Pagination                                                                   |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \`controls\_top\_right\` → \[\*\*FilterDropdown\*\*\] (Area)  
\- \`toolbar\_left\` → \[\*\*InputField\*\*\] (ERP search)  
\- \`toolbar\_right\` → \[\*\*Button(add)\*\*\], \[\*\*Button(export)\*\*\]  
\- \`main\` → \[\*\*MasterDataTable\*\*\]

Components-per-field  
\- \*\*area\_id\*\* (display area\_name) → \[\*\*TextCell\*\*\]  
\- \*\*employee\_id\*\*, \*\*full\_name\*\*, \*\*assigned\_at\*\* mapped as above

\#\#\#\# Actions / Events & Binding  
\- GET \`/api/areas?with=heads\&area\_id=\`  
\- POST \`/api/areas/{area\_id}/heads\` { employee\_id } — validate ERP active  
\- DELETE \`/api/areas/{area\_id}/heads/{employee\_id}\`

\#\#\#\# Validation  
\- Block inactive ERP employees (422)  
\- 404 if area/employee not found

\#\#\#\# RBAC & Status Gating  
\- Admin/Director allowed add/remove; Area Head / Officer read-only

\#\#\#\# Microcopy (i18n/A11y)  
\- Add Head helper: "ค้นหาใน ERP และเลือกพนักงานเพื่อเพิ่มเป็นหัวหน้า"

\#\#\#\# Journey Bindings  
\- \`Journey G\` (Add Area Head): Add → POST \`/api/areas/:area\_id/heads\`  
\- \`Journey H\` (Remove Area Head): Remove → DELETE \`/api/areas/:area\_id/heads/:employee\_id\`

\#\#\#\# Notes  
\- template\_source=packingList.v1

\---

\#\#\# 7.2.9 Extension Officers (Global) — \`/agm/admin/roles/officers\`  
\*\*Purpose\*\*: จัดการการมอบหมายเจ้าหน้าที่ผ่าน Extension Codes แบบรวม (Assign/Reassign/Rename/Open)

\#\#\#\# Layout  
\- Template: packingList.v1  
\- Grid Spec: 12col; Filters: Area, Status; ERP search; Table with actions

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| H1: Extension Officers                                                       |  
\+------------------------------------------------------------------------------+  
| Filter: พื้นที่ \[ Select ▾ \]  สถานะ \[ All / EMPTY / OCCUPIED \]  ERP ค้นหา: \[\] |  
|                                 \[ Create Code \]  \[ Export \]                 |  
\+------------------------------------------------------------------------------+  
| display\_code | area\_name | assigned\_to | status | Actions(Open/Assign/Name) |  
| \-----------------------------------------------------------------------------|  
| … rows …                                                                     |  
\+------------------------------------------------------------------------------+  
| Pagination                                                                   |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \`controls\_top\_right\` → \[\*\*FilterDropdown\*\*\] (Area, Status)  
\- \`toolbar\_left\` → \[\*\*InputField\*\*\] (ERP search)  
\- \`toolbar\_right\` → \[\*\*Button(Create Code)\*\*\], \[\*\*Button(export)\*\*\]  
\- \`main\` → \[\*\*MasterDataTable\*\*\]

Components-per-field  
\- \*\*display\_code\*\* → \[\*\*TextCell\*\*\]  
\- \*\*area\_name\*\* → \[\*\*TextCell\*\*\]  
\- \*\*assigned\_to\*\* → \[\*\*TextCell\*\* / \*\*Avatar\*\*\]  
\- \*\*status\*\* → \[\*\*StatusBadge\*\*\] (EMPTY/OCCUPIED)  
\- Actions → \[\*\*ActionMenu\*\*\] items: Open, Assign (when EMPTY), Reassign (when OCCUPIED), Rename

\#\#\#\# Actions / Events & Binding  
\- GET \`/api/extension-codes?q=\&area\_id=\&status=\&page=\&page\_size=\`  
\- Create Code → open modal (7.2.11) → POST \`/api/extension-codes\` (X-Idempotency-Key)  
\- Assign → open Assign modal (7.2.13) → POST \`/api/extension-codes/{id}/assign\` (X-Idempotency-Key)  
\- Reassign → open Reassign modal (7.2.14) → POST \`/api/extension-codes/{from\_id}/reassign\` (X-Idempotency-Key)  
\- Rename → open Rename modal (7.2.12) → PUT \`/api/extension-codes/{id}/rename\` (If-Match)

\#\#\#\# Validation  
\- Create: \*\*display\_code\*\* regex ^\\d{4}$; unique globally (409)  
\- Assign: employee must be active and have no active code (409 if already has)  
\- Reassign: target must be EMPTY; atomic server transaction (423 on race)  
\- Rename: If-Match required; unique format

\#\#\#\# RBAC & Status Gating  
\- Admin/Director: full actions  
\- Area Head: read-only for codes in their Area  
\- Extension Officer: read-only for their own code

\#\#\#\# Microcopy (i18n/A11y)  
\- display\_code helper: "รูปแบบต้องเป็นตัวเลข 4 หลัก เช่น 0123"  
\- Assign button aria: "มอบหมายเจ้าหน้าที่ให้กับโค้ด"

\#\#\#\# Journey Bindings  
\- \`Journey I\` (Create Code) → Create Code modal → POST \`/api/extension-codes\` (X-Idempotency-Key)  
\- \`Journey K\` (Assign Officer) → Assign modal → POST \`/api/extension-codes/{id}/assign\`  
\- \`Journey L\` (Reassign) → Reassign modal → POST \`/api/extension-codes/{from\_id}/reassign\`  
\- \`Journey J\` (Rename) → Rename modal → PUT \`/api/extension-codes/{id}/rename\` (If-Match)

\#\#\#\# Notes  
\- template\_source=packingList.v1

\---

\#\#\# 7.2.10 Extension Codes (Standalone Full Screen) — \`/agm/admin/extension-codes\`  
\*\*Purpose\*\*: พื้นที่ทำงานเต็มหน้าจอสำหรับ Extension Codes (เหมือน Roles \> Officers แต่มี Create)

\#\#\#\# Layout  
\- Uses List template packingList.v1 adapted; full-screen header \+ table \+ action bar  
\- Grid Spec: 12col; toolbar with Create/Export; table compact

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| Breadcrumbs: AGM › การบริหาร › พื้นที่และการกำหนดสิทธิ์ › Extension Codes   |  
\+------------------------------------------------------------------------------+  
| H1: Extension Codes                                                          |  
| Subtitle: จัดการโค้ดขยาย (สร้าง / มอบหมาย / ย้าย / เปลี่ยนชื่อ)            |  
\+------------------------------------------------------------------------------+  
| 🔍 ค้นหา: \[ display\_code หรือ พนักงาน \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ \]  Filters: Area ▾ |  
|                                 \[ Create Code \]   \[ Export CSV \]           |  
\+------------------------------------------------------------------------------+  
| display\_code | area\_name | assigned\_to | status | Actions(Open/Assign/Rename)|  
| \-----------------------------------------------------------------------------|  
| … rows …                                                                     |  
\+------------------------------------------------------------------------------+  
| Pagination                                                                   |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- same as 7.2.9 (controls \+ master table)

Components-per-field  
\- same as 7.2.9 mapping

\#\#\#\# Actions / Events & Binding  
\- GET \`/api/extension-codes\`  
\- Create Code → POST \`/api/extension-codes\` (X-Idempotency-Key)  
\- Row Open → navigate \`/agm/admin/extension-codes/{id}\`  
\- Rename/Assign/Reassign → modals & respective APIs

\#\#\#\# Validation / RBAC / Microcopy  
\- As per 7.2.9

\#\#\#\# Journey Bindings  
\- \`Journey I/J/K/L\` bound as above

\#\#\#\# Notes  
\- template\_source=packingList.v1

\---

\#\#\# 7.2.11 Extension Code Detail — \`/agm/admin/extension-codes/:id\`  
\*\*Purpose\*\*: ดูรายละเอียดของ Extension Code; ไล่สถานะ/ผู้รับมอบหมาย;ทำ Rename/Assign/Reassign

\#\#\#\# Layout  
\- Custom full-screen Detail page: Header (display\_code, status, actions), Meta card, Current Officer card (if OCCUPIED), Audit timeline, Actions  
\- Grid Spec: 12col; header \+ tabs/panels

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| Breadcrumbs: AGM › การบริหาร › Extension Codes › \[display\_code\]             |  
\+------------------------------------------------------------------------------+  
| H1: รหัส: \*\*1234\*\*                              \[ Assign \] \[ Rename \]       |  
| Status: \[ OCCUPIED / EMPTY \]   Area: \[ชื่อพื้นที่\]   Created: …             |  
\+------------------------------------------------------------------------------+  
| Meta (left 8 cols)                              | Current Officer (right 4\) |  
| \+--------------------------------------------+ | \+-----------------------+ |  
| | display\_code: 1234                           | | If OCCUPIED:          | |  
| | area\_name: ชื่อพื้นที่                       | | • ชื่อ: …             | |  
| | status: EMPTY / OCCUPIED                     | | • assigned\_at: …      | |  
| | note: …                                     | | Actions: Reassign     | |  
| \+--------------------------------------------+ | \+-----------------------+ |  
\+------------------------------------------------------------------------------+  
| Audit timeline / Related Area link / Buttons                                   |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \`header\` → \[\*\*PageHeader\*\*\] with actions  
\- \`meta\_card\` → \[\*\*KeyValueGrid-2col\*\*\]  
\- \`current\_officer\` → \[\*\*Card\*\*\] (shows assigned employee)  
\- \`audit\` → \[\*\*ActivityLog\*\*\]

Components-per-field  
\- \*\*display\_code\*\* → \[\*\*TextCell\*\*\] (field: \*\*display\_code\*\*)  
\- \*\*area\_id / area\_name\*\* → \[\*\*TextCell\*\*\]  
\- \*\*status\*\* → \[\*\*StatusBadge\*\*\]  
\- \*\*note\*\* → \[\*\*Text\*\*\]  
\- \*\*assigned\_to\*\* → \[\*\*PersonCard\*\*\] (employee lookup)

\#\#\#\# Actions / Events & Binding  
\- GET \`/api/extension-codes/{id}\`  
\- Rename → open Rename modal → PUT \`/api/extension-codes/{id}/rename\` (If-Match)  
\- Assign → open Assign modal → POST \`/api/extension-codes/{id}/assign\` (X-Idempotency-Key)  
\- Reassign → open Reassign modal → POST \`/api/extension-codes/{from\_id}/reassign\` (X-Idempotency-Key)  
\- Link to Area → navigate \`/agm/admin/areas/{area\_id}\`

\#\#\#\# Validation  
\- Rename: new\_display\_code regex ^\\d{4}$ \+ unique (409)  
\- Assign: employee active \+ no existing active code (409)

\#\#\#\# RBAC & Status Gating  
\- Admin/Director: full actions  
\- Area Head: read if code in their area  
\- Extension Officer: read if assigned

\#\#\#\# Microcopy (i18n/A11y)  
\- Rename modal aria: "เปลี่ยนหมายเลขโค้ด"  
\- Assign modal helper: "พนักงานจะต้องไม่ถูกผูกกับโค้ดอื่น"

\#\#\#\# Journey Bindings  
\- \`Journey J\` (Rename): Code Detail / Rename → PUT \`/api/extension-codes/{id}/rename\` (If-Match)  
\- \`Journey K\` (Assign): Code Detail / Assign → POST \`/api/extension-codes/{id}/assign\`  
\- \`Journey L\` (Reassign): Code Detail / Reassign → POST \`/api/extension-codes/{from\_id}/reassign\`

\#\#\#\# Notes  
\- template\_source=custom (reason: full-screen detail with person card \+ audit not in library)

\---

\#\#\# 7.2.12 Modal: Create Extension Code — \`/agm/admin/extension-codes/create\`  
\*\*Purpose\*\*: สร้าง Extension Code ใหม่ (EMPTY) และเชื่อมกับ Area

\#\#\#\# Layout  
\- Modal centered (use ModalDialog pattern); width ≈ 480px; focus trap

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
|                สร้าง Extension Code (Modal)                                  |  
\+------------------------------------------------------------------------------+  
| \*\*เลือกพื้นที่\*\* \[\*\*Select\*\* ▾\] (field: \*\*area\_id\*\*)                         |  
| \*\*หมายเลขโค้ด (4 หลัก)\*\* \[\*\*Input\*\*\] (field: \*\*display\_code\*\*)              |  
| \*\*หมายเหตุ\*\* \[\*\*Textarea\*\*\] (field: \*\*note\*\*)                               |  
\+------------------------------------------------------------------------------+  
| Left: \[ยกเลิก\]                                Right: \[สร้าง (X-Idempotency)\]  |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \`modal\_header\` → \[\*\*ModalTitle\*\*\]  
\- \`modal\_body\` → \[\*\*FormSection\*\*\] fields as below  
\- \`modal\_footer\` → \[\*\*Button(cancel)\*\*\], \[\*\*Button(create)\*\* primary\]

Components-per-field  
\- \*\*area\_id\*\* → \[\*\*SelectDropdown\*\*\] (areas list)  
\- \*\*display\_code\*\* → \[\*\*Input\*\*\] (regex ^\\d{4}$)  
\- \*\*note\*\* → \[\*\*Textarea\*\*\]

\#\#\#\# Actions / Events & Binding  
\- Submit → POST \`/api/extension-codes\`    
  \- Headers: \`X-Idempotency-Key: \<uuid\>\`    
  \- Body: { area\_id, display\_code, note }    
\- On success → Close modal \+ toast \+ navigate to new Code Detail or refresh list

\#\#\#\# Validation  
\- Required: \*\*area\_id\*\*, \*\*display\_code\*\*  
\- display\_code format ^\\d{4}$; server returns 409 if duplicate  
\- X-Idempotency-Key required for idempotent safety

\#\#\#\# RBAC & Status Gating  
\- Admin/Director only

\#\#\#\# Microcopy (i18n/A11y)  
\- Input helper: "กรอกตัวเลข 4 หลัก เช่น 0123" (aria-describedby)  
\- Error for duplicate: "หมายเลขโค้ดซ้ำ กรุณาใช้หมายเลขอื่น"

\#\#\#\# Journey Bindings  
\- \`Journey I\`: Create Code modal → POST \`/api/extension-codes\` (X-Idempotency-Key)

\#\#\#\# Notes  
\- template\_source=ModalDialog (library generic modal)

\---

\#\#\# 7.2.13 Modal: Rename Code — \`/agm/admin/extension-codes/:id/rename\`  
\*\*Purpose\*\*: เปลี่ยนค่า \*\*display\_code\*\* (rename-only, If-Match required)

\#\#\#\# Layout  
\- Modal centered; small form with new\_display\_code field

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
|                   เปลี่ยนหมายเลขโค้ด (Rename)                                |  
\+------------------------------------------------------------------------------+  
| \*\*หมายเลขโค้ดใหม่ (4 หลัก)\*\* \[\*\*Input\*\*\] (field: \*\*new\_display\_code\*\*)      |  
| (hidden) version: \*\*{version}\*\*                                              |  
\+------------------------------------------------------------------------------+  
| Left: \[ยกเลิก\]                                Right: \[เปลี่ยน (If-Match)\]     |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \`modal\_body\` → \[\*\*InputField\*\*\] (new\_display\_code)  
\- \`modal\_footer\` → \[\*\*Button(cancel)\*\*\], \[\*\*Button(rename)\*\* primary\]

Components-per-field  
\- \*\*new\_display\_code\*\* → \[\*\*Input\*\*\]  
\- \*\*version\*\* → hidden; used for \`If-Match\`

\#\#\#\# Actions / Events & Binding  
\- Submit → PUT \`/api/extension-codes/{id}/rename\`    
  \- Headers: \`If-Match: "\<etag|version\>"\`    
  \- Body: { new\_display\_code }    
\- On 409 → show duplicate error; on 412 → show conflict merge dialog

\#\#\#\# Validation  
\- new\_display\_code regex ^\\d{4}$; uniqueness check

\#\#\#\# RBAC & Status Gating  
\- Admin/Director only

\#\#\#\# Microcopy (i18n/A11y)  
\- Helper: "รูปแบบต้องมี 4 ตัวเลข" (aria-describedby)

\#\#\#\# Journey Bindings  
\- \`Journey J\` (Rename): Rename modal → PUT \`/api/extension-codes/{id}/rename\` (If-Match)

\#\#\#\# Notes  
\- template\_source=ModalDialog

\---

\#\#\# 7.2.14 Modal: Assign Officer (EMPTY only) — \`/agm/admin/extension-codes/:id/assign\`  
\*\*Purpose\*\*: มอบหมายเจ้าหน้าที่ให้กับโค้ดที่เป็น EMPTY

\#\#\#\# Layout  
\- Modal small: ERP employee search \+ Add button

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
|                      มอบหมายเจ้าหน้าที่ให้โค้ด 1234                          |  
\+------------------------------------------------------------------------------+  
| ERP ค้นหา: \[ ค้นหาพนักงาน ERP \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ \]                         |  
| Selected: \[ ชื่อ พนง. • email \]                                              |  
\+------------------------------------------------------------------------------+  
| Left: \[ยกเลิก\]                                Right: \[มอบหมาย (X-Idempotency)\] |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \`modal\_body\` → \[\*\*InputField\*\*\] (ERP search \+ select)  
\- \`modal\_footer\` → \[\*\*Button(cancel)\*\*\], \[\*\*Button(assign)\*\* primary\]

Components-per-field  
\- \*\*employee\_id\*\* → \[\*\*PersonSelect\*\*\] (single select from ERP lookup)

\#\#\#\# Actions / Events & Binding  
\- Submit → POST \`/api/extension-codes/{id}/assign\`    
  \- Headers: \`X-Idempotency-Key: \<uuid\>\`    
  \- Body: { employee\_id }    
\- Precondition: Code status \== EMPTY; employee active; employee has no active code  
\- On success → set Code=OCCUPIED; emit event; audit; close modal; toast

\#\#\#\# Validation  
\- Client validate selection; server: 409 if employee already has code / code not EMPTY; 404 if employee not found

\#\#\#\# RBAC & Status Gating  
\- Admin/Director only; Assign button hidden if code.status \!= EMPTY

\#\#\#\# Microcopy (i18n/A11y)  
\- Helper: "พนักงานต้องไม่มีโค้ดที่ใช้งานอยู่" (aria-describedby)

\#\#\#\# Journey Bindings  
\- \`Journey K\`: Assign modal → POST \`/api/extension-codes/{id}/assign\` (X-Idempotency-Key)

\#\#\#\# Notes  
\- template\_source=ModalDialog

\---

\#\#\# 7.2.15 Modal: Reassign Officer — \`/agm/admin/extension-codes/:id/reassign\`  
\*\*Purpose\*\*: ย้ายเจ้าหน้าที่จากโค้ด OCCUPIED ไปยังโค้ด EMPTY (atomic)

\#\#\#\# Layout  
\- Modal: search/select target Area (optional) → select EMPTY target code → confirmation

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
|                     ย้ายเจ้าหน้าที่จากโค้ด 1234 → เลือกโค้ดว่าง                 |  
\+------------------------------------------------------------------------------+  
| ผู้ถูกย้าย: ชื่อ พนักงาน (employee\_id)                                      |  
| Filter: พื้นที่ \[ Select ▾ \]                                                 |  
| เลือกโค้ดเป้าหมาย: \[ Select empty code ▾ \] (to\_ext\_code\_id)                 |  
\+------------------------------------------------------------------------------+  
| Left: \[ยกเลิก\]                                Right: \[ย้าย (X-Idempotency)\]     |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \`modal\_body\` → \[\*\*PersonCard (readonly)\*\*\], \[\*\*SelectDropdown\*\*\] for to\_area\_id, \[\*\*SelectDropdown\*\* for to\_ext\_code\_id\]  
\- \`modal\_footer\` → \[\*\*Button(cancel)\*\*\], \[\*\*Button(reassign)\*\* primary\]

Components-per-field  
\- \*\*to\_area\_id\*\* → \[\*\*SelectDropdown\*\*\] (optional)  
\- \*\*to\_ext\_code\_id\*\* → \[\*\*SelectDropdown\*\*\] (must be EMPTY)  
\- \*\*employee\_id\*\* → displayed readonly

\#\#\#\# Actions / Events & Binding  
\- Submit → POST \`/api/extension-codes/{from\_id}/reassign\`    
  \- Headers: \`X-Idempotency-Key: \<uuid\>\`    
  \- Body: { to\_id, employee\_id }    
\- Server performs atomic transaction: from→EMPTY, to→OCCUPIED  
\- On 423 (race) → show conflict and allow retry

\#\#\#\# Validation  
\- Target code must be EMPTY (serverwise guard 409\)  
\- Employee must match current assignment (server verify)

\#\#\#\# RBAC & Status Gating  
\- Admin/Director only

\#\#\#\# Microcopy (i18n/A11y)  
\- Warning text: "การย้ายทำแบบอะตอม มั่นใจว่าทำในครั้งเดียว" (aria-live)

\#\#\#\# Journey Bindings  
\- \`Journey L\`: Reassign modal → POST \`/api/extension-codes/{from\_id}/reassign\` (X-Idempotency-Key)

\#\#\#\# Notes  
\- template\_source=ModalDialog

\---

\#\# 7.3 Screen Components (React-friendly names)  
\- Pages: \`AreasListPage\`, \`AreaDetailPage\`, \`AreaCreateDrawer\`, \`AreaEditDrawer\`, \`RolesTabContainer\`, \`DirectorsListPage\`, \`AreaHeadsListPage\`, \`ExtensionOfficersListPage\`, \`ExtensionCodesListPage\`, \`ExtensionCodeDetailPage\`  
\- Common/Shared: \`SearchBar\`, \`FilterDropdown\`, \`AdvancedFilterDrawer\`, \`MasterDataTable\`, \`PaginationControls\`, \`CSVExporter\`, \`ToastHost\`, \`PageHeader\`, \`DrawerHeader\`, \`ModalDialog\`, \`ActivityLog\`, \`StatusBadge\`, \`PersonSelect\`, \`KeyValueGrid\`, \`FormLayout\`, \`InputField\`, \`SelectDropdown\`, \`Textarea\`, \`Button\`, \`ActionMenu\`, \`StatCard\`, \`PersonCard\`

\#\# 7.4 Client Flows (Create/Update/Delete/Restore/Bulk)  
\- Create Area (Journey A):  
  \- Client: validate → POST \`/api/areas\` (+Header \`X-Idempotency-Key\`)  
  \- Server: 201 → return { area\_id, version } → client navigate \`/agm/admin/areas/{area\_id}\`, show toast, refresh list  
  \- Errors: 409 (duplicate), 422 (validation), 424 (address master)  
\- Update Area (Journey B):  
  \- Client: GET \`/api/areas/{id}\` (store ETag/version) → edit → PUT \`/api/areas/{id}\` (Header \`If-Match: \<version\>\`)  
  \- Success: 200 → show toast; on 412 → load latest \+ conflict dialog  
\- Toggle Area Status (Journey C):  
  \- PATCH \`/api/areas/{id}/status\` (Header \`If-Match\`) → server verifies no OCCUPIED codes → 200 or 409  
\- Create Extension Code (Journey I):  
  \- POST \`/api/extension-codes\` (X-Idempotency-Key) → 201 (status=EMPTY)  
\- Rename (Journey J):  
  \- PUT \`/api/extension-codes/{id}/rename\` (If-Match)  
\- Assign (Journey K):  
  \- POST \`/api/extension-codes/{id}/assign\` (X-Idempotency-Key) → server sets OCCUPIED; 409 if violations  
\- Reassign (Journey L):  
  \- POST \`/api/extension-codes/{from\_id}/reassign\` { to\_id, employee\_id } (X-Idempotency-Key) → atomic; 423 on race

\#\# 7.5 Microcopy / Empty / Error States (i18n & A11y)  
\- Empty Areas: "ยังไม่มีพื้นที่ กรุณาเพิ่มพื้นที่ใหม่" \+ \*\*สร้างพื้นที่\*\*  
\- Create Success toast: "สร้างพื้นที่สำเร็จ"  
\- Edit Success: "บันทึกการแก้ไขสำเร็จ"  
\- 403 toast: "คุณไม่มีสิทธิ์ดำเนินการนี้"  
\- 409 conflict: inline error message (เช่น "รายการซ้ำ / พนักงานถูกผูกกับโค้ดแล้ว")  
\- 412: "ข้อมูลถูกแก้ไขแล้ว กรุณารีเฟรชและลองอีกครั้ง"  
\- All toasts use aria-live="polite"; modals use role="dialog" and focus trap

\#\# 7.6 Journey ↔ Page Crosswalk (ใหม่ แนะนำ)  
\- Journey A → AreasListPage (Create Area btn) → AreaCreateDrawer → POST /api/areas  
\- Journey B → AreaDetailPage (Edit btn) → AreaEditDrawer → PUT /api/areas/{id}  
\- Journey C → AreasListPage / AreaDetailPage (Toggle Status) → PATCH /api/areas/{id}/status  
\- Journey D → AreaDetailPage (view)  
\- Journey E/F → DirectorsListPage (Add/Remove) → POST/DELETE /api/roles/directors  
\- Journey G/H → AreaDetailPage / AreaHeadsListPage (Add/Remove) → POST/DELETE /api/areas/{area\_id}/heads  
\- Journey I → ExtensionCodesListPage / ExtensionOfficersListPage → Create Extension Code modal → POST /api/extension-codes  
\- Journey J → ExtensionCodeDetailPage → Rename modal → PUT /api/extension-codes/{id}/rename  
\- Journey K → ExtensionOfficersListPage / ExtensionCodeDetailPage → Assign modal → POST /api/extension-codes/{id}/assign  
\- Journey L → ExtensionOfficersListPage / ExtensionCodeDetailPage → Reassign modal → POST /api/extension-codes/{from\_id}/reassign  
\- Journey M → AreasListPage / ExtensionCodesListPage → Search/Filter/Export → GET /api/... & /export

\#\#\# Warnings (ข้อควรระวัง)  
\- template\_source=custom สำหรับ: Root Tabbed page, Area Detail page, Extension Code Detail page (เหตุผล: ต้องการ full-screen Tabs \+ Audit timeline / KPIs ซึ่งไม่มีในไลบรารีเทมเพลต)    
\- ไม่พบ endpoint สำหรับ "unassign only" (ลบ assignment โดยไม่ reassign) ในอินพุต — ถ้าต้องการ ให้เพิ่ม API (Warnings: missing\_unassign\_endpoint)    
\- ฟิลด์ \`version\`/ETag ถูกอ้างอิงแต่รูปแบบ header/value ในอินพุตไม่ระบุชัด (สมมติ If-Match ใช้ string version/etag) — โปรดยืนยันรูปแบบ (Warnings: unknown\_etag\_format)    
\- การแสดงคอลัมน์สำหรับ Extension Officer ในหน้า Areas ไม่ได้กำหนดชัดเจน (เช่น heads\_count หรือ codes\_count สำหรับ Officer ควรซ่อนหรือแสดง) — โปรดยืนยันรายละเอียดการซ่อนคอลัมน์ (Warnings: column\_visibility\_for\_officer)    
\- ไม่มีการระบุ export:pdf endpoints — ปัจจุบันรองรับเฉพาะ CSV (Warnings: export\_pdf\_missing)    
\- หากต้องการ modal/confirm สำหรับ Remove actions (Directors/Heads) UI จะต้องตกลงรูปแบบ (instant delete vs confirm modal); อินพุตไม่ได้กำหนด → ปล่อยเป็นการลบทันทีแต่แนะนำ confirm modal (Warnings: remove\_confirm\_not\_specified)

\---

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

\# Journey  
\# Journey: สร้างพื้นที่ (Create Area) (Actor: System Admin / Director)  
\*\*Entry:\*\* จากหน้า Areas List (\`/agm/admin/area-permission?tab=areas\`) → คลิกปุ่ม \`สร้างพื้นที่\` (open Create Drawer \`/agm/admin/areas/create\`)    
\*\*Preconditions:\*\* ผู้ใช้มีสิทธิ์ (RBAC \= Admin หรือ Director); เครือข่ายเชื่อมต่อกับ Address Master; มี token Authorization; client สามารถอ่านรายการจังหวัด/อำเภอ/ตำบล จาก \`/api/geo/\*\`    
\*\*Exit / Postconditions:\*\* เรียก POST /api/areas สำเร็จ (201) → resource สร้างแล้ว (area\_id, version, status=active) → navigate ไป \`/agm/admin/areas/{area\_id}\`; event telemetry \`area.created\` ถูกปล่อย; list cache invalidated

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Areas List / btn-create-area\*\* — ผู้ใช้คลิกปุ่ม "สร้างพื้นที่"    
   \- \*\*Trigger:\*\* NAV → open Drawer \`/agm/admin/areas/create\` (DIALOG)    
   \- \*\*map\_in:\*\* none    
   \- \*\*assert:\*\* ปุ่มแสดงเฉพาะเมื่อ role ∈ {Admin, Director} (client guard)    
   \- \*\*System:\*\* เปิด Create Drawer UI; focus ไปที่ \`input-area\_name\`    
   \- \*\*map\_out:\*\* n/a    
   \- \*\*UI Feedback:\*\* Drawer เปิดขึ้น; skeleton loader จนกว่าจะโหลด options    
   \- \*\*Navigation/State:\*\* Drawer state open; query param optional \`?create=true\`    
   \- \*\*Field & Copy Checklist (บังคับในขั้นนี้):\*\*  
     \- Fields ที่ต้องกรอก:  
       \- area\_name | ชื่อพื้นที่ | text | required(yes) | default("") | validators(max\_length=200, trim) | helper\_text\_th: "ตั้งชื่อพื้นที่ให้ชัดเจน" | error\_copy\_th: "กรุณากรอกชื่อพื้นที่" | visibility(editable)  
       \- province\_id | จังหวัด | select | required(yes) | default(null) | validators(enum via /api/geo/provinces) | helper\_text\_th: "เลือกจังหวัด" | error\_copy\_th: "กรุณาเลือกจังหวัด" | visibility(editable)  
       \- district\_id | อำเภอ | select | required(yes) | default(null) | validators(dependent on province\_id) | helper\_text\_th: "เลือกอำเภอ" | visibility(editable)  
       \- subdistrict\_id | ตำบล | select | required(yes) | default(null) | validators(dependent) | helper\_text\_th: "เลือกตำบล" | visibility(editable)  
       \- postal\_code | รหัสไปรษณีย์ | text | required(no) | default(RO) | validators(^\\d{5}$) | helper\_text\_th: "รหัสไปรษณีย์จะเติมอัตโนมัติ (อ่านอย่างเดียว)" | visibility(read-only) | source(api/geo/postal)  
       \- address\_line | ที่อยู่ | textarea | required(no) | default("") | validators(max\_length=1000) | helper\_text\_th: "" | visibility(editable)  
       \- description | คำอธิบาย | textarea | required(no) | default("") | validators(max\_length=1000) | visibility(editable)  
     \- Fields ที่ต้องแสดง:  
       \- version | เวอร์ชัน | visibility(hidden until response) | source(api)  
       \- status | สถานะ | visibility(read-only) | source(api)  
     \- UI Copy / Messages:  
       \- Create confirm: "สร้างพื้นที่ใหม่" (ปุ่ม), cancel: "ยกเลิก"  
       \- Loading: "กำลังโหลดรายการจังหวัด..." ; Error: "ไม่สามารถโหลดฐานข้อมูลที่อยู่ กรุณาลองใหม่"  
     \- data-test-id ที่เกี่ยวข้อง:  
       \- areas-create-drawer (drawer container)  
       \- input-area\_name  
       \- select-province\_id  
       \- select-district\_id  
       \- select-subdistrict\_id  
       \- readonly-postal\_code  
       \- textarea-address\_line  
       \- btn-create-area-confirm  
     \- a11y:  
       \- focus order: input-area\_name → select-province\_id → select-district\_id → select-subdistrict\_id → textarea-address\_line → btn-create-area-confirm  
       \- aria-labels on inputs; modal role="dialog"; Alt+C \= create (hotkey)  
2\) \*\*Area Create Drawer / form.submit (btn-create-area-confirm)\*\* — ผู้ใช้กรอกฟอร์มแล้วกดสร้าง    
   \- \*\*Trigger:\*\* FN-API: POST /api/areas    
   \- \*\*map\_in:\*\* { area\_name, province\_id, district\_id, subdistrict\_id, address\_line?, description? }  (ห้ามส่ง postal\_code หรือ version)    
   \- \*\*assert:\*\* ทุก required field ไม่ว่าง; province/district/subdistrict ถูกเลือกและมีค่าทำงาน; client-side format checks (area\_name trim, max length). X-Idempotency-Key ถูกสร้างตาม pattern (ดูด้านล่าง)    
   \- \*\*System:\*\* เรียก POST /api/areas พร้อม header Authorization \+ X-Idempotency-Key. Server validates uniqueness area\_name, address master. ถ้าผ่าน → returns 201 { area\_id, version, status, created\_at }    
   \- \*\*map\_out:\*\* { area\_id, version, status, created\_at } → ใช้ navigate ไป /agm/admin/areas/{area\_id} และเก็บ version/ETag สำหรับ If-Match ใช้ต่อไป    
   \- \*\*UI Feedback:\*\* ปุ่มสร้างถูก disable ขณะรอ; show spinner; on success → close drawer \+ toast success "สร้างพื้นที่สำเร็จ" (aria-live=polite)    
   \- \*\*Navigation/State:\*\* navigate → Area Detail; invalidate Areas List cache; emit telemetry \`area.created\`    
   \- \*\*Field & Copy Checklist:\*\* (same fields as step 1\)    
   \- \*\*data-test-id:\*\* btn-create-area-confirm, areas-create-form  
   \- \*\*a11y:\*\* Ctrl+Enter submits; Esc closes (confirm if partially filled)  
   \- \*\*Idempotency Key Pattern:\*\* X-Idempotency-Key \= ui:{user.id}:create-area:{hash(area\_name|province\_id|district\_id|subdistrict\_id|address\_line)}    
   \- \*\*Telemetry:\*\* event \`area.created\` payload: { actor\_id, area\_id, area\_name, province\_id, subdistrict\_id, correlation\_id, idempotency\_key }    
   \- \*\*Audit Fields:\*\* actor\_id, correlation\_id (X-Request-Id), idempotency\_key, before\_snapshot=null, after\_snapshot={area\_id, area\_name,...}

\#\#\#\# Variants & Exceptions  
\- Step 2 → VALIDATION:VALIDATION\_FAILED (400/422): show inline field messages; focus first invalid field; do not close drawer.  
\- Step 2 → CONFLICT: code=CONFLICT (409) message "area\_name already exists": show inline under area\_name with action "แก้ไขชื่อพื้นที่"; focus area\_name.  
\- Step 2 → DEPENDENCY (424): address master down → show banner "ไม่สามารถดึงข้อมูลที่อยู่ขณะนี้ กรุณาลองอีกครั้ง" with Retry button; disable Create until address options loaded or allow create if postal\_code optional? (Per API, postal\_code RO but create allowed → UX: show warning and allow create with manual address\_line)  
\- Step 2 → TIMEOUT/Network: retry with exponential backoff; reuse same X-Idempotency-Key; show toast "เครือข่ายขัดข้อง กำลังพยายามอีกครั้ง"  
\- Access Control: if server returns 403 → show toast "คุณไม่มีสิทธิ์ดำเนินการนี้" and close drawer  
\- CONFLICT on idempotency (server returns existing resource for same key) → treat as success: navigate to returned resource (follow server response)

\#\#\#\# Telemetry & Audit  
\- Events: area.created { actor\_id, area\_id, area\_name, province\_id, correlation\_id, idempotency\_key }    
\- Audit Fields: actor\_id, correlation\_id, idempotency\_key, resource\_ids(area\_id), before=null, after={full\_area\_snapshot}

\#\#\#\# Test Hooks  
\- data-test-id to assert: areas-create-drawer, input-area\_name, select-province\_id, btn-create-area-confirm    
\- Acceptance (Gherkin ย่อ):  
  \- Given ผู้ใช้เป็น Admin และอยู่ในหน้า Areas    
  \- When ผู้ใช้คลิก สร้างพื้นที่ และกรอกฟิลด์ที่จำเป็น แล้วกด สร้าง    
  \- Then เรียก POST /api/areas ด้วย X-Idempotency-Key และ navigate ไปยัง Area Detail ที่สร้างใหม่

\#\#\#\# Assumptions & Confidence  
\- สมมติว่า postal\_code เติมโดย \`/api/geo/postal?subdistrict\_id=\` จะตอบทันที (Confidence: Medium)    
\- Assumed server returns {area\_id, version} เมื่อสร้างสำเร็จ (Confidence: High)

\---

\# Journey: แก้ไขพื้นที่ (Edit Area) (Actor: System Admin / Director)  
\*\*Entry:\*\* จาก Area Detail (\`/agm/admin/areas/:id\`) → คลิก \`แก้ไข\` (open Edit Drawer \`/agm/admin/areas/:id/edit\`)    
\*\*Preconditions:\*\* ผู้ใช้เป็น Admin/Director; มี latest version จาก GET \`/api/areas/{id}\`; resource.status ≠ Archived (ตาม Navigation Rules)    
\*\*Exit / Postconditions:\*\* เรียก PUT /api/areas/{id} สำเร็จ (200) → version เพิ่มขึ้น; event \`area.updated\` ถูกปล่อย; Area Detail และ List ถูก refresh

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Area Detail / btn-edit-area\*\* — ผู้ใช้คลิกปุ่ม แก้ไข    
   \- \*\*Trigger:\*\* NAV → open Edit Drawer \`/agm/admin/areas/{id}/edit\`    
   \- \*\*map\_in:\*\* none    
   \- \*\*assert:\*\* client โหลดรายละเอียด (ถ้ายังไม่มี)    
   \- \*\*System:\*\* GET /api/areas/{id} (if not cached) → response contains version; populate form; set local ETag/version for If-Match    
   \- \*\*map\_out:\*\* version stored in UI state for If-Match header    
   \- \*\*UI Feedback:\*\* Drawer shows populated fields; focus to first editable field.    
   \- \*\*data-test-id:\*\* areas-edit-drawer, input-area\_name  
2\) \*\*Area Edit Drawer / form.save (btn-save-area)\*\* — ผู้ใช้แก้ไขฟอร์มแล้วกดบันทึก    
   \- \*\*Trigger:\*\* FN-API: PUT /api/areas/{area\_id}    
   \- \*\*map\_in:\*\* { area\_name, province\_id, district\_id, subdistrict\_id, address\_line?, description? } (ไม่ส่ง postal\_code, created\_by, created\_at)    
   \- \*\*assert:\*\* client must include If-Match header \= "\<version\>" (จาก GET); client-side validation same as create    
   \- \*\*System:\*\* PUT /api/areas/{id} with If-Match. Server validates optimistic locking → on match apply update and return 200 { area\_id, version, updated\_at, updated\_by }    
   \- \*\*map\_out:\*\* { version, updated\_at, updated\_by } → update UI, Area Detail, list invalidation    
   \- \*\*UI Feedback:\*\* disable save button; show spinner; on success toast "บันทึกการแก้ไขสำเร็จ"; close drawer or keep open per UX decision (we navigate to detail updated view)    
   \- \*\*Navigation/State:\*\* close drawer; refresh Area Detail (\`GET /api/areas/{id}\`) to show authoritative snapshot    
   \- \*\*Field & Copy Checklist:\*\* same fields as Create; show current \`version\` label in header: "เวอร์ชันปัจจุบัน: {version}"    
   \- \*\*data-test-id:\*\* btn-save-area, areas-edit-form  
   \- \*\*If-Match Value:\*\* use integer version or ETag string as provided in GET; header: If-Match: "\<version\>"

\#\#\#\# Variants & Exceptions  
\- Step 2 → PRECONDITION\_FAILED (412): If-Match mismatch → action: fetch latest GET /api/areas/{id}, show modal "ข้อมูลเปลี่ยนแปลงแล้ว" with diff, options: Refresh (load latest), Overwrite (retry PUT with new If-Match after review). Do not auto-overwrite. Telemetry \`area.update\_conflict\`.  
\- Step 2 → VALIDATION\_FAILED (400/422): show inline errors; focus first invalid field.  
\- Step 2 → CONFLICT (409 duplicate area\_name): show inline under area\_name; suggestion helper "เลือกชื่ออื่น".  
\- DEPENDENCY/424: address master failures when attempting to change geo fields → show banner; allow retry.  
\- Access Control 403 → close drawer \+ toast "คุณไม่มีสิทธิ์ดำเนินการนี้".

\#\#\#\# Telemetry & Audit  
\- Events: area.updated { actor\_id, area\_id, changed\_fields\[\], correlation\_id, if\_match\_version }    
\- Audit Fields: actor\_id, correlation\_id, idempotency\_key=null, if\_match\_version, before\_snapshot, after\_snapshot

\#\#\#\# Test Hooks  
\- data-test-id: areas-edit-drawer, input-area\_name, btn-save-area    
\- Acceptance (Gherkin ย่อ): Given ผู้ใช้มีเวอร์ชันล่าสุด, When ผู้ใช้แก้ไขและกดบันทึก, Then เรียก PUT /api/areas/{id} ด้วย If-Match และแสดงผลสำเร็จ

\#\#\#\# Assumptions & Confidence  
\- Assumed If-Match uses integer \`version\` from body (Confidence: Medium — TODO confirm ETag format).

\---

\# Journey: สลับสถานะพื้นที่ (Activate/Deactivate Area) (Actor: System Admin / Director)  
\*\*Entry:\*\* จาก Areas List row action หรือ Area Detail action → คลิก \`สลับสถานะ\` (Toggle Status)    
\*\*Preconditions:\*\* ผู้ใช้เป็น Admin/Director; client มี current version (If-Match) จาก GET \`/api/areas/{id}\`; server-side guard: ไม่อนุญาต inactivate หากมี OCCUPIED extension codes    
\*\*Exit / Postconditions:\*\* เรียก PATCH /api/areas/{id}/status สำเร็จ → updated status เปลี่ยน (active↔inactive) และ version เพิ่ม; event \`area.status\_toggled\` ถูกปล่อย

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Areas List / row.action-toggle-status\*\* — ผู้ใช้คลิก toggle status บนแถว    
   \- \*\*Trigger:\*\* DIALOG → show confirmation modal "คุณต้องการปิดใช้งานพื้นที่นี้หรือไม่?"    
   \- \*\*map\_in:\*\* none    
   \- \*\*assert:\*\* client-side check: role allowed; button visible only when role permitted (Row Action Guards)    
   \- \*\*System:\*\* show modal; fetch fresh version optional (recommended) before performing patch    
   \- \*\*data-test-id:\*\* areas-row-toggle-status, modal-toggle-status-confirm  
2\) \*\*Confirm Modal / confirm.toggle-status\*\* — ผู้ใช้ยืนยัน (confirm)    
   \- \*\*Trigger:\*\* FN-API: PATCH /api/areas/{area\_id}/status    
   \- \*\*map\_in:\*\* { status } (body minimal: { "status": "inactive" } or "active" as desired)    
   \- \*\*assert:\*\* include If-Match: "\<version\>"; client must not compute OCCUPIED count — server asserts uniqueness/guards    
   \- \*\*System:\*\* PATCH with If-Match. Server verifies no OCCUPIED codes → on success returns updated { area\_id, status, version, updated\_at } or 409 if blocked    
   \- \*\*map\_out:\*\* new status, version → update row UI and Area Detail if open    
   \- \*\*UI Feedback:\*\* show spinner on confirm; on success toast "เปลี่ยนสถานะสำเร็จ"; on 409 show inline error modal with reason "ไม่สามารถปิดใช้งานพื้นที่ที่มีโค้ดที่ถูกใช้"    
   \- \*\*Navigation/State:\*\* update list cache; emit telemetry \`area.status\_toggled\`    
   \- \*\*data-test-id:\*\* btn-confirm-toggle-status

\#\#\#\# Variants & Exceptions  
\- Step 2 → CONFLICT (409): message "Cannot inactivate area with OCCUPIED codes" → show modal listing conflicting codes (server may return details) and CTA "ไปที่ Extension Codes" or "ย้าย/ปลดผูกก่อน"    
\- Step 2 → PRECONDITION\_FAILED (412): If-Match mismatch → fetch latest and prompt user to retry    
\- Step 2 → LOCKED/TIMEOUT: retry policy exponential backoff; show toast "การเปลี่ยนสถานะล้มเหลว ช่วยลองอีกครั้ง"    
\- Access Control: if client displayed button but server returns 403 → show toast "คุณไม่มีสิทธิ์"

\#\#\#\# Telemetry & Audit  
\- Events: area.status\_toggled { actor\_id, area\_id, old\_status, new\_status, correlation\_id, if\_match\_version }    
\- Audit Fields: actor\_id, correlation\_id, if\_match\_version, before\_snapshot, after\_snapshot

\#\#\#\# Test Hooks  
\- data-test-id: areas-row-toggle-status, modal-toggle-status-confirm, btn-confirm-toggle-status

\#\#\#\# Assumptions & Confidence  
\- Server returns helpful 409 details to list occupied codes (Confidence: Medium). If not, add TODO.

\---

\# Journey: ดูรายละเอียดพื้นที่ (View Area Detail) (Actor: Any role with read permission)  
\*\*Entry:\*\* จาก Areas List → คลิก area\_name → navigate to \`/agm/admin/areas/:id\`    
\*\*Preconditions:\*\* Authorization token; user has view permission (scoped by RBAC — server filters list)    
\*\*Exit / Postconditions:\*\* Page shows GET /api/areas/{id} data \+ calls GET /api/areas/{id}/heads and GET /api/extension-codes?area\_id={id} for related lists; telemetry \`area.viewed\` emitted

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Areas List / link-area-name\*\* — ผู้ใช้คลิกชื่อพื้นที่    
   \- \*\*Trigger:\*\* NAV → client navigates to \`/agm/admin/areas/{id}\`    
   \- \*\*map\_in:\*\* none    
   \- \*\*assert:\*\* route valid; user has read permission (client guard)    
   \- \*\*System:\*\* client issues GET /api/areas/{id} → populate header fields (area\_name, postal\_code RO, status, version, metadata)    
   \- \*\*map\_out:\*\* full area object stored in UI state    
   \- \*\*UI Feedback:\*\* show page skeleton until GET returns; error 404 → show "Area not found" banner and navigate back to list with toast    
   \- \*\*Navigation/State:\*\* URL deep-linkable; preserve query params when returning    
   \- \*\*data-test-id:\*\* area-detail-page, area-detail-header  
2\) \*\*Area Detail / load tabs\*\* — client loads Area Heads and Extension Codes in parallel    
   \- \*\*Trigger:\*\* FN-API: GET /api/areas/{id}/heads AND GET /api/extension-codes?area\_id={id}    
   \- \*\*map\_in:\*\* { area\_id } for both calls    
   \- \*\*assert:\*\* none beyond auth    
   \- \*\*System:\*\* populate heads tab and extension-codes tab data (counts used in UI)    
   \- \*\*map\_out:\*\* heads\[\], extension\_codes\[\] → used in tables    
   \- \*\*UI Feedback:\*\* per-tab skeletons; if integrations fail (ERP/geo) show degraded messages per tab    
   \- \*\*data-test-id:\*\* tab-heads, tab-extension-codes, area-heads-table, area-extension-codes-table

\#\#\#\# Variants & Exceptions  
\- GET /api/areas/{id} → NOT\_FOUND (404): show banner "ไม่พบพื้นที่นี้" \+ button "กลับไปหน้ารายการ"    
\- GET dependent calls → 424: show degraded mode message in relevant tab with Retry button    
\- RBAC: if user lacks scope to see heads or extension codes, server returns filtered lists; client should hide actions (Add/Assign) accordingly

\#\#\#\# Telemetry & Audit  
\- Events: area.viewed { actor\_id, area\_id, correlation\_id }    
\- Audit Fields: actor\_id, correlation\_id, resource\_snapshot\_read

\#\#\#\# Test Hooks  
\- data-test-id: area-detail-page, tab-overview, tab-heads, tab-extension-codes, action-edit-area, action-toggle-status

\#\#\#\# Assumptions & Confidence  
\- Assumed server returns \`postal\_code\` read-only in detail response (Confidence: High)

\---

\# Journey: เพิ่มหัวหน้าพื้นที่ (Add Area Head) (Actor: System Admin / Director)  
\*\*Entry:\*\* Area Detail → Tab "Area Heads" → คลิก \`เพิ่มหัวหน้าพื้นที่\` (open modal/select)    
\*\*Preconditions:\*\* User role ∈ {Admin, Director}; selected employee must exist and active in ERP \`/api/erp/employees\`    
\*\*Exit / Postconditions:\*\* POST /api/areas/{area\_id}/heads สร้าง assignment → response 201; event telemetry \`area.head.added\` emitted; heads list refreshed

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Area Detail / tab-heads / btn-add-head\*\* — ผู้ใช้เปิด modal เพิ่มหัวหน้า    
   \- \*\*Trigger:\*\* DIALOG open Add Head modal    
   \- \*\*map\_in:\*\* none    
   \- \*\*assert:\*\* button visible only for Admin/Director (client guard)    
   \- \*\*System:\*\* modal opens; focus on ERP search field    
   \- \*\*data-test-id:\*\* modal-add-head, input-erp-search-head  
2\) \*\*Add Head Modal / select employee \+ submit\*\* — ผู้ใช้ค้นหา ERP,เลือกพนักงานแล้วกดยืนยัน    
   \- \*\*Trigger:\*\* FN-API: POST /api/areas/{area\_id}/heads    
   \- \*\*map\_in:\*\* { employee\_id }    
   \- \*\*assert:\*\* client ensures selection not empty; X-Idempotency-Key present: ui:{user.id}:add-head:{area\_id}:{employee\_id}    
   \- \*\*System:\*\* POST called; server validates ERP employee active (else 422); on success returns 201 { area\_id, employee\_id, assigned\_at }    
   \- \*\*map\_out:\*\* assigned\_at → update heads table; toast success "เพิ่มหัวหน้าพื้นที่สำเร็จ"    
   \- \*\*UI Feedback:\*\* disable submit while pending; close modal on success    
   \- \*\*Navigation/State:\*\* refresh GET /api/areas/{id}/heads; emit telemetry \`area.head.added\`    
   \- \*\*data-test-id:\*\* btn-add-head-confirm  
   \- \*\*Telemetry:\*\* area.head.added { actor\_id, area\_id, employee\_id, correlation\_id, idempotency\_key }    
   \- \*\*Audit Fields:\*\* actor\_id, correlation\_id, idempotency\_key, after\_snapshot (heads list)

\#\#\#\# Variants & Exceptions  
\- Server returns VALIDATION\_FAILED/422 "employee is inactive" → show inline under employee select and focus the selector    
\- Server returns CONFLICT/409 if business rule violated (e.g., employee already head for that area?) → show inline message and steps    
\- Dependency (ERP down 424\) → show "ไม่สามารถค้นหาพนักงานขณะนี้" banner with Retry    
\- Access Control 403 → modal blocked; toast 403

\#\#\#\# Test Hooks  
\- data-test-id: modal-add-head, input-erp-search-head, btn-add-head-confirm

\#\#\#\# Assumptions & Confidence  
\- Server returns 201 with assigned\_at (Confidence: High)

\---

\# Journey: ลบหัวหน้าพื้นที่ (Remove Area Head) (Actor: System Admin / Director)  
\*\*Entry:\*\* Area Detail → Area Heads table → row action Remove → confirm    
\*\*Preconditions:\*\* Admin/Director; assignment exists    
\*\*Exit / Postconditions:\*\* DELETE /api/areas/{area\_id}/heads/{employee\_id} → 204; event \`area.head.removed\` emitted; heads list refreshed

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Area Heads Table / action-remove-head\*\* — ผู้ใช้คลิก Remove บนแถวหัวหน้า    
   \- \*\*Trigger:\*\* DIALOG → confirm modal "ยืนยันลบหัวหน้าพื้นที่?"    
   \- \*\*map\_in:\*\* none    
   \- \*\*assert:\*\* client shows confirm modal to prevent accidental delete    
   \- \*\*System:\*\* on confirm → call DELETE /api/areas/{area\_id}/heads/{employee\_id} with Authorization (If-Match optional)    
   \- \*\*map\_out:\*\* 204 → remove row from UI and refresh heads list via GET /api/areas/{area\_id}/heads    
   \- \*\*UI Feedback:\*\* success toast "ลบหัวหน้าพื้นที่สำเร็จ"    
   \- \*\*Navigation/State:\*\* refresh area head list; emit telemetry \`area.head.removed\`    
   \- \*\*data-test-id:\*\* btn-confirm-remove-head  
   \- \*\*Audit & Telemetry:\*\* area.head.removed { actor\_id, area\_id, employee\_id, correlation\_id }

\#\#\#\# Variants & Exceptions  
\- DELETE → NOT\_FOUND (404): show inline message "การมอบหมายไม่พบแล้ว" and refresh list    
\- DELETE → 412 (If-Match mismatch if server enforces) → fetch latest assignment and retry

\#\#\#\# Test Hooks  
\- data-test-id: area-heads-table-row-{employee\_id}-remove, btn-confirm-remove-head

\#\#\#\# Assumptions & Confidence  
\- Server returns 204 on success (Confidence: High)

\---

\# Journey: เพิ่ม/ลบ Director (Directors Add / Remove) (Actor: System Admin / Director)  
\*\*Entry:\*\* Roles Tab → Directors sub-tab (\`/agm/admin/roles/directors\`) → Add via ERP select OR Remove via row action    
\*\*Preconditions:\*\* Admin/Director; ERP employee active    
\*\*Exit / Postconditions:\*\* POST /api/roles/directors → 201 (add) / DELETE /api/roles/directors/{employee\_id} → 204 (remove); telemetry \`role.director.added\` / \`role.director.removed\` emitted

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Directors Page / btn-add-director\*\* — เปิด add modal/select →เลือกพนักงาน → submit    
   \- \*\*Trigger:\*\* FN-API: POST /api/roles/directors    
   \- \*\*map\_in:\*\* { employee\_id }    
   \- \*\*assert:\*\* X-Idempotency-Key set: ui:{user.id}:add-director:{employee\_id} ; employee active via ERP lookup client-side    
   \- \*\*System:\*\* server validates and returns 201 with assigned\_at; on conflict 409 "employee already a director" → show inline    
   \- \*\*map\_out:\*\* update directors list via GET; toast success    
   \- \*\*data-test-id:\*\* btn-add-director, input-erp-search-director  
   \- \*\*Telemetry:\*\* role.director.added { actor\_id, employee\_id, correlation\_id, idempotency\_key }  
2\) \*\*Directors Page / action-remove-director\*\* — user removes director row    
   \- \*\*Trigger:\*\* FN-API: DELETE /api/roles/directors/{employee\_id}    
   \- \*\*map\_in:\*\* path param employee\_id    
   \- \*\*assert:\*\* confirm modal shown    
   \- \*\*System:\*\* DELETE called → 204 → update list    
   \- \*\*data-test-id:\*\* directors-row-{employee\_id}-remove  
   \- \*\*Telemetry:\*\* role.director.removed { actor\_id, employee\_id, correlation\_id }

\#\#\#\# Variants & Exceptions  
\- Add → 409 duplicate: show message "พนักงานเป็น Director อยู่แล้ว"    
\- Add → 422 employee inactive → inline "พนักงานไม่active"    
\- Remove → 404 not found → refresh list & show toast "ไม่พบรายการ"

\#\#\#\# Test Hooks  
\- data-test-id: btn-add-director, directors-table, directors-row-{employee\_id}-remove

\#\#\#\# Assumptions & Confidence  
\- Director list API returns assigned\_at; add API requires X-Idempotency-Key (Confidence: High)

\---

\# Journey: สร้าง Extension Code (Create Extension Code) (Actor: System Admin / Director)  
\*\*Entry:\*\* Extension Codes List \`/agm/admin/extension-codes\` → คลิก \`Create Code\` (open modal \`/agm/admin/extension-codes/create\`)    
\*\*Preconditions:\*\* User role ∈ {Admin, Director}; area\_id chosen exists; display\_code matches regex ^\\d{4}$; X-Idempotency-Key required    
\*\*Exit / Postconditions:\*\* POST /api/extension-codes → 201 with new ext\_code\_id, status=EMPTY; telemetry \`ext\_code.created\` emitted; extension codes list refreshed

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Extension Codes List / btn-create-code\*\* — ผู้ใช้เปิด Create Code modal    
   \- \*\*Trigger:\*\* DIALOG open \`/agm/admin/extension-codes/create\`    
   \- \*\*map\_in:\*\* none    
   \- \*\*assert:\*\* button visible only for Admin/Director    
   \- \*\*System:\*\* modal opens; focus on select area    
   \- \*\*data-test-id:\*\* modal-create-ext-code, select-area-for-code  
2\) \*\*Create Code Modal / submit (btn-create-code-confirm)\*\* — ผู้ใช้กรอก area\_id, display\_code, note → กดสร้าง    
   \- \*\*Trigger:\*\* FN-API: POST /api/extension-codes    
   \- \*\*map\_in:\*\* { area\_id, display\_code, note? }    
   \- \*\*assert:\*\* client validates display\_code regex ^\\d{4}$; X-Idempotency-Key \= ui:{user.id}:create-ext-code:{area\_id}:{display\_code}    
   \- \*\*System:\*\* POST called; server validates uniqueness display\_code globally → on success returns 201 { ext\_code\_id, display\_code, status, created\_at }    
   \- \*\*map\_out:\*\* ext\_code\_id → navigate to Extension Code Detail or refresh list; toast success "สร้างโค้ดสำเร็จ"    
   \- \*\*UI Feedback:\*\* disable submit; spinner; on 409 show "display\_code already exists" under field    
   \- \*\*Navigation/State:\*\* refresh list; emit telemetry \`ext\_code.created\`    
   \- \*\*data-test-id:\*\* input-display\_code, btn-create-code-confirm  
   \- \*\*Telemetry:\*\* ext\_code.created { actor\_id, ext\_code\_id, display\_code, area\_id, correlation\_id, idempotency\_key }    
   \- \*\*Audit Fields:\*\* actor\_id, correlation\_id, idempotency\_key, after\_snapshot

\#\#\#\# Variants & Exceptions  
\- Step 2 → VALIDATION\_FAILED (400) display\_code format invalid: show inline message and focus field    
\- Step 2 → CONFLICT (409) display\_code duplicate: show inline and helper to suggest available codes (if server returns suggestions)    
\- DEPENDENCY/TIMEOUT → retry with same idempotency key; or show error and allow manual retry

\#\#\#\# Test Hooks  
\- data-test-id: modal-create-ext-code, select-area-for-code, input-display\_code, btn-create-code-confirm

\#\#\#\# Assumptions & Confidence  
\- display\_code uniqueness is global across areas (per API notes) (Confidence: High)

\---

\# Journey: เปลี่ยนชื่อ Extension Code (Rename) (Actor: System Admin / Director)  
\*\*Entry:\*\* Extension Code Detail \`/agm/admin/extension-codes/:id\` → คลิก \`Rename\` (open modal)    
\*\*Preconditions:\*\* User role ∈ {Admin, Director}; client has current \`version\` from GET /api/extension-codes/{id}; new\_display\_code matches ^\\d{4}$    
\*\*Exit / Postconditions:\*\* PUT /api/extension-codes/{id}/rename with If-Match success → event \`ext\_code.renamed\` emitted; UI refreshed

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Extension Code Detail / btn-rename\*\* — ผู้ใช้เปิด Rename modal    
   \- \*\*Trigger:\*\* DIALOG open \`/agm/admin/extension-codes/{id}/rename\`    
   \- \*\*map\_in:\*\* none; modal includes hidden version    
   \- \*\*map\_out:\*\* version for header If-Match    
   \- \*\*data-test-id:\*\* modal-rename-ext-code, input-new-display-code  
2\) \*\*Rename Modal / submit (btn-rename-confirm)\*\* — ผู้ใช้กรอก new\_display\_code แล้วยืนยัน    
   \- \*\*Trigger:\*\* FN-API: PUT /api/extension-codes/{ext\_code\_id}/rename    
   \- \*\*map\_in:\*\* { new\_display\_code } (body) \+ Header If-Match: "\<version\>"    
   \- \*\*assert:\*\* client validates regex; must include If-Match header; client shows confirm copy "เปลี่ยนจาก 1234 เป็น 4321"    
   \- \*\*System:\*\* Server validates uniqueness; on success returns { ext\_code\_id, old\_display\_code, new\_display\_code, version }    
   \- \*\*map\_out:\*\* update detail UI, list cache; toast success; emit telemetry \`ext\_code.renamed\`    
   \- \*\*UI Feedback:\*\* disable button while pending; on 409 show inline "display\_code already exists"; on 412 fetch latest and show conflict modal    
   \- \*\*Navigation/State:\*\* refresh GET /api/extension-codes/{id} after success    
   \- \*\*data-test-id:\*\* btn-rename-confirm  
   \- \*\*Telemetry:\*\* ext\_code.renamed { actor\_id, ext\_code\_id, old\_display\_code, new\_display\_code, correlation\_id, if\_match\_version }  
   \- \*\*Audit Fields:\*\* actor\_id, correlation\_id, if\_match\_version, before\_snapshot, after\_snapshot

\#\#\#\# Variants & Exceptions  
\- 409 → duplicate → inline error; focus input    
\- 412 → If-Match mismatch → show dialog "ข้อมูลโค้ดถูกเปลี่ยนแล้ว" with options: Refresh / Retry    
\- 424 → dependency failure (unlikely) → banner

\#\#\#\# Test Hooks  
\- data-test-id: modal-rename-ext-code, input-new-display-code, btn-rename-confirm

\#\#\#\# Assumptions & Confidence  
\- If-Match use integer version from GET (Confidence: Medium — TODO confirm ETag format)

\---

\# Journey: มอบหมายเจ้าหน้าที่ให้โค้ด (Assign Officer) (Actor: System Admin / Director)  
\*\*Entry:\*\* Extension Code Detail (code status=EMPTY) → คลิก \`Assign\` (open Assign modal)    
\*\*Preconditions:\*\* code.status \== EMPTY (client guard \+ server re-assert); employee active in ERP; employee has no other active code; X-Idempotency-Key required    
\*\*Exit / Postconditions:\*\* POST /api/extension-codes/{id}/assign → 200 response with assigned object; code.status becomes OCCUPIED; event \`ext\_code.assigned\` emitted; Area Detail/code lists updated

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Extension Code Detail / btn-assign\*\* — เปิด Assign modal    
   \- \*\*Trigger:\*\* DIALOG open \`/agm/admin/extension-codes/{id}/assign\`    
   \- \*\*map\_in:\*\* none    
   \- \*\*assert:\*\* button only visible if code.status \== EMPTY and role allowed (Admin/Director)    
   \- \*\*System:\*\* show PersonSelect (ERP lookup)    
   \- \*\*data-test-id:\*\* modal-assign-ext-code, input-erp-search-assign  
2\) \*\*Assign Modal / submit (btn-assign-confirm)\*\* — เลือก employee แล้วยืนยัน    
   \- \*\*Trigger:\*\* FN-API: POST /api/extension-codes/{ext\_code\_id}/assign    
   \- \*\*map\_in:\*\* { employee\_id }    
   \- \*\*assert:\*\* X-Idempotency-Key: ui:{user.id}:assign-ext-code:{ext\_code\_id}:{employee\_id}; client ensures selection non-empty; client does NOT send employee active flag or employee's current assignments (server calculates)    
   \- \*\*System:\*\* Server validates code EMPTY, employee active, employee has no active code → returns 200 { ext\_code\_id, display\_code, status: "OCCUPIED", assigned: { employee\_id, assigned\_at, assigned\_by } } and emits \`ext\_code.assigned\` event to downstream systems. Updates DB atomically.    
   \- \*\*map\_out:\*\* assigned object used to update Code Detail and list; toast "มอบหมายสำเร็จ"; close modal    
   \- \*\*UI Feedback:\*\* disable submit; spinner; on 409 show "employee already has an active code" with CTA to Reassign instead    
   \- \*\*Navigation/State:\*\* refresh GET /api/extension-codes/{id} and GET extension-codes list; emit telemetry \`ext\_code.assigned\`    
   \- \*\*data-test-id:\*\* btn-assign-confirm  
   \- \*\*Telemetry:\*\* ext\_code.assigned { actor\_id, ext\_code\_id, display\_code, area\_id, employee\_id, assigned\_at, correlation\_id, idempotency\_key }    
   \- \*\*Audit Fields:\*\* actor\_id, correlation\_id, idempotency\_key, before\_snapshot (code empty), after\_snapshot (code occupied with assigned)

\#\#\#\# Variants & Exceptions  
\- Server 409 "employee already has an active code": show inline and offer link "ย้ายพนักงานไปยังโค้ดนี้ (Reassign)" which opens Reassign modal prefilled with from\_id \= current assigned ext\_code\_id of employee (if server provides).    
\- Server 409 "code not EMPTY" (race): show "โค้ดถูกมอบหมายแล้ว" and refresh code detail; suggest retry with updated data. On CONFLICT instruct retry with same idempotency key; server may return existing resource for idempotency reuse.    
\- Server 422 employee inactive: show inline "พนักงานไม่ active"    
\- Dependency 424 ERP lookup failure: show message and retry option

\#\#\#\# Test Hooks  
\- data-test-id: modal-assign-ext-code, input-erp-search-assign, btn-assign-confirm

\#\#\#\# Assumptions & Confidence  
\- Server returns 200 on assign success with \`assigned\` object as in API doc (Confidence: High)

\---

\# Journey: ย้าย (Reassign) เจ้าหน้าที่จากโค้ดหนึ่งไปยังอีกโค้ด (Reassign Officer) (Actor: System Admin / Director)  
\*\*Entry:\*\* Extension Code Detail (from code status=OCCUPIED) → คลิก \`Reassign\` (open Reassign modal)    
\*\*Preconditions:\*\* from\_code currently OCCUPIED assigned to employee\_id; target to\_id must be EMPTY; X-Idempotency-Key required; server performs atomic transaction; possible 423 LOCKED if race    
\*\*Exit / Postconditions:\*\* POST /api/extension-codes/{from\_id}/reassign → 200 and atomic change (from → EMPTY, to → OCCUPIED); events \`ext\_code.reassigned\` emitted; both code details updated

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Extension Code Detail / btn-reassign\*\* — เปิด Reassign modal พร้อมข้อมูลผู้ถูกย้าย    
   \- \*\*Trigger:\*\* DIALOG open \`/agm/admin/extension-codes/{from\_id}/reassign\`    
   \- \*\*map\_in:\*\* display from\_id and assigned employee info via GET prior to opening    
   \- \*\*assert:\*\* client ensures from\_code status=OCCUPIED and shows readonly employee card    
   \- \*\*System:\*\* fetch list of EMPTY codes (optionally filtered by area) to choose target \`to\_id\`    
   \- \*\*data-test-id:\*\* modal-reassign-ext-code, select-to-ext-code  
2\) \*\*Reassign Modal / submit (btn-reassign-confirm)\*\* — ผู้ใช้เลือก target to\_id แล้ว confirm    
   \- \*\*Trigger:\*\* FN-API: POST /api/extension-codes/{from\_id}/reassign    
   \- \*\*map\_in:\*\* { to\_id, employee\_id }    
   \- \*\*assert:\*\* X-Idempotency-Key: ui:{user.id}:reassign-ext-code:{from\_id}:{to\_id}:{employee\_id}; client must not assume atomicity — server will enforce; client must not send current assignment details other than employee\_id & to\_id.    
   \- \*\*System:\*\* Server performs atomic transaction: verify from\_id assigned to employee\_id, to\_id is EMPTY → set from\_id to EMPTY and to\_id to OCCUPIED assigned to employee\_id; on success return 200 { from\_id, to\_id, employee\_id, at } and emit \`ext\_code.reassigned\`. If concurrent operation conflict → return 423 LOCKED.    
   \- \*\*map\_out:\*\* update both Extension Code details and lists; toast success "ย้ายสำเร็จ"    
   \- \*\*UI Feedback:\*\* disable submit; spinner; on 423 show modal "การย้ายล้มเหลวเนื่องจากการทำงานพร้อมกัน กรุณาลองใหม่" with Retry button (keep same idempotency key)    
   \- \*\*Navigation/State:\*\* refresh GET for both ext codes and area lists; emit telemetry \`ext\_code.reassigned\`    
   \- \*\*data-test-id:\*\* btn-reassign-confirm  
   \- \*\*Telemetry:\*\* ext\_code.reassigned { actor\_id, employee\_id, from\_id, to\_id, at, correlation\_id, idempotency\_key }    
   \- \*\*Audit Fields:\*\* actor\_id, correlation\_id, idempotency\_key, before\_snapshot (from occupied, to empty), after\_snapshot (from empty, to occupied)

\#\#\#\# Variants & Exceptions  
\- Server 423 LOCKED: show race dialog with Retry (exponential backoff recommended). Retry must reuse same X-Idempotency-Key. After 3 retries show user-friendly resolution steps (e.g., "มีการเปลี่ยนแปลงล่าสุด ให้รีเฟรชและลองอีกครั้ง").    
\- Server 409: target not EMPTY or employee mismatch → show inline error and refresh lists.    
\- Server 404: from\_id or to\_id missing → show error and navigate back to list    
\- Access Control 403 → show toast and log audit

\#\#\#\# Test Hooks  
\- data-test-id: modal-reassign-ext-code, select-to-ext-code, btn-reassign-confirm

\#\#\#\# Assumptions & Confidence  
\- Server returns 423 on concurrent races (Confidence: High)

\---

\# Journey: ดูรายการ/Export (List & Export CSV) (Actor: Any role with list permission; export gated to Admin/Director)  
\*\*Entry:\*\* Areas List (\`/agm/admin/area-permission?tab=areas\`) or Extension Codes List \`/agm/admin/extension-codes\` → click Export CSV    
\*\*Preconditions:\*\* User authorized; filters applied (q, province\_id, status, etc.); Export may be sync or async depending on implementation (API 8.18/8.19)    
\*\*Exit / Postconditions:\*\* If sync: returns 200 with CSV body download; If async: returns 202 with job\_id (not specified) — client must poll job endpoint (TODO if async job endpoint missing) ; telemetry \`export.requested\` emitted

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Areas List / btn-export-csv\*\* — ผู้ใช้คลิก Export CSV    
   \- \*\*Trigger:\*\* FN-API: GET /api/areas/export?q=... (or /api/extension-codes/export)    
   \- \*\*map\_in:\*\* query params same as list (q, area\_id, status, sort, page filters) — do not send client-derived totals    
   \- \*\*assert:\*\* client shows confirmation/tooltip "การดาวน์โหลดอาจใช้เวลานาน" when large result set; RBAC check for export permission (Admin/Director).    
   \- \*\*System (sync path):\*\* server returns 200 Content-Type: text/csv → browser triggers download; on success show toast "ดาวน์โหลด CSV เรียบร้อย"    
   \- \*\*System (async path):\*\* server returns 202 { job\_id } → client starts job polling (not specified endpoint) and when job ready obtains download URL; show toast "กำลังเตรียมไฟล์ ส่งอีเมลแจ้งเตือนเมื่อพร้อม" (implementation-dependent)    
   \- \*\*map\_out:\*\* CSV file or job\_id → handle accordingly    
   \- \*\*UI Feedback:\*\* show progress indicator; disable export button until response or show job queued message    
   \- \*\*Navigation/State:\*\* no navigation; telemetry \`export.requested\`    
   \- \*\*data-test-id:\*\* btn-export-areas, btn-export-ext-codes  
   \- \*\*Telemetry:\*\* export.requested { actor\_id, entity: "areas"| "extension\_codes", filters: {...}, correlation\_id }    
   \- \*\*Audit Fields:\*\* actor\_id, correlation\_id, export\_filters

\#\#\#\# Variants & Exceptions  
\- Server returns 429 rate-limited → show Retry-After countdown; implement backoff    
\- Server returns 500/424 → show error banner with Retry    
\- Async 202 but job polling endpoint missing → TODO: define job polling endpoint /api/jobs/{job\_id} (see TODOs)

\#\#\#\# Test Hooks  
\- data-test-id: btn-export-areas, btn-export-ext-codes

\#\#\#\# Assumptions & Confidence  
\- Prefer async for large exports (Confidence: High). Job polling endpoint not specified (TODO).

\---

\# Journey: เปิดจาก Notification / Deeplink ไปยัง Detail (Open from Notification) (Actor: Any)  
\*\*Entry:\*\* ผู้ใช้คลิกลิงก์แจ้งเตือน (notification) ที่ชี้ไปยัง Area หรือ Extension Code เช่น \`/agm/admin/areas/{id}\` หรือ \`/agm/admin/extension-codes/{id}\`    
\*\*Preconditions:\*\* Link contains resource id; user authenticated; RBAC enforced server-side (may redirect to list \+ toast 403\)    
\*\*Exit / Postconditions:\*\* โหลดหน้า Detail; telemetry \`area.viewed\` or \`ext\_code.viewed\` emitted; if resource missing → 404 handler shown

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Notification / deeplink click\*\* — ผู้ใช้คลิกลิงก์ deeplink to \`/agm/admin/areas/{id}\`    
   \- \*\*Trigger:\*\* NAV → browser navigates to the route    
   \- \*\*map\_in:\*\* route param id    
   \- \*\*assert:\*\* none client-side beyond auth token present    
   \- \*\*System:\*\* client GET /api/areas/{id}; if success render Area Detail; if 403 redirect to list and show toast "คุณไม่มีสิทธิ์ดูรายการนี้"    
   \- \*\*map\_out:\*\* area object → render    
   \- \*\*UI Feedback:\*\* skeleton until loaded; 404 → alert "ไม่พบพื้นที่" with action "กลับไปหน้ารายการ"    
   \- \*\*Navigation/State:\*\* deep-link preserved; history entry created    
   \- \*\*data-test-id:\*\* area-deeplink-entry, ext-code-deeplink-entry    
   \- \*\*Telemetry:\*\* area.viewed { actor\_id, area\_id, correlation\_id } or ext\_code.viewed analog

\#\#\#\# Variants & Exceptions  
\- 401/403 → redirect to list \+ toast 403 "คุณไม่มีสิทธิ์"    
\- 404 → show not-found page and CTA back to list

\#\#\#\# Telemetry & Audit  
\- event: area.viewed / ext\_code.viewed { actor\_id, resource\_id, correlation\_id }

\#\#\#\# Test Hooks  
\- data-test-id: area-deeplink-entry, ext-code-deeplink-entry

\#\#\#\# Assumptions & Confidence  
\- Server enforces RBAC scopes and returns 403 when unauthorized (Confidence: High)

\---

\#\# Cross-cutting Variants & Error Handling (applies across journeys)  
\- \*\*CONFLICT (409)\*\*: Show inline business message; for assignment conflicts offer CTA to Reassign; focus relevant field; do not retry automatically. Telemetry \`operation.conflict\`.  
\- \*\*PRECONDITION\_FAILED (412)\*\*: Show "ข้อมูลเปลี่ยนแปลงแล้ว" dialog with options Refresh / Merge / Retry. Client must fetch latest then let user reapply changes. Telemetry \`operation.precondition\_failed\`.  
\- \*\*LOCKED (423)\*\*: For reassign races show race modal and Retry with backoff (reuse same idempotency key). Telemetry \`operation.locked\`.  
\- \*\*DEPENDENCY (424)\*\*: Show degraded UI for affected feature and Retry button. Log event \`integration.dependency\_failed\` with dependency name.  
\- \*\*NETWORK/TIMEOUT\*\*: Show inline network error toast; allow user to retry. For POSTs, reuse same X-Idempotency-Key.  
\- \*\*Idempotency\*\*: All POST create/assign/reassign/add-director/add-head must include X-Idempotency-Key following pattern:  
  \- Create Area: ui:{user.id}:create-area:{hash(area\_name|province\_id|district\_id|subdistrict\_id|address\_line)}  
  \- Create Ext Code: ui:{user.id}:create-ext-code:{area\_id}:{display\_code}  
  \- Assign: ui:{user.id}:assign-ext-code:{ext\_code\_id}:{employee\_id}  
  \- Reassign: ui:{user.id}:reassign-ext-code:{from\_id}:{to\_id}:{employee\_id}  
  \- Add Director: ui:{user.id}:add-director:{employee\_id}  
  \- Add Area Head: ui:{user.id}:add-head:{area\_id}:{employee\_id}  
\- \*\*Retry on CONFLICT\*\*: instruct to retry with same idempotency key if operation is safe to retry (server may return existing resource).  
\- \*\*Row Action Guards\*\*: client must hide/disable row actions per Page Definition:  
  \- \`Toggle Status\` only visible to Admin/Director  
  \- \`Assign\` visible only when code.status \== EMPTY and role allowed  
  \- \`Reassign\` visible only when code.status \== OCCUPIED and role allowed  
  (Server enforces again)

\---

\#\# Telemetry & Audit (global)  
\- Events emitted (dot-case) with payload essentials:  
  \- area.created { actor\_id, area\_id, area\_name, province\_id, correlation\_id, idempotency\_key }  
  \- area.updated { actor\_id, area\_id, changed\_fields\[\], correlation\_id, if\_match\_version }  
  \- area.status\_toggled { actor\_id, area\_id, old\_status, new\_status, correlation\_id }  
  \- area.head.added { actor\_id, area\_id, employee\_id, correlation\_id, idempotency\_key }  
  \- area.head.removed { actor\_id, area\_id, employee\_id, correlation\_id }  
  \- role.director.added { actor\_id, employee\_id, correlation\_id, idempotency\_key }  
  \- role.director.removed { actor\_id, employee\_id, correlation\_id }  
  \- ext\_code.created { actor\_id, ext\_code\_id, display\_code, area\_id, correlation\_id, idempotency\_key }  
  \- ext\_code.renamed { actor\_id, ext\_code\_id, old\_display\_code, new\_display\_code, correlation\_id, if\_match\_version }  
  \- ext\_code.assigned { actor\_id, ext\_code\_id, display\_code, area\_id, employee\_id, assigned\_at, correlation\_id, idempotency\_key }  
  \- ext\_code.reassigned { actor\_id, employee\_id, from\_code\_id, to\_code\_id, at, correlation\_id, idempotency\_key }  
  \- export.requested { actor\_id, entity, filters, correlation\_id }  
\- Audit Fields to include on every mutating action: actor\_id, correlation\_id (X-Request-Id), idempotency\_key (for POSTs), if\_match\_version (for PUT/PATCH), resource ids, before\_snapshot, after\_snapshot.

\---

\#\# Test Hooks (per-page recommended data-test-id list)  
\- Areas List: areas-list-page, btn-create-area, search-areas-input, filter-province, btn-export-areas, area-row-{area\_id}-open, area-row-{area\_id}-edit, area-row-{area\_id}-toggle-status  
\- Area Detail: area-detail-page, area-detail-header, tab-overview, tab-heads, tab-extension-codes, btn-edit-area, btn-toggle-area-status, btn-add-head  
\- Area Create Drawer: areas-create-drawer, input-area\_name, select-province\_id, select-district\_id, select-subdistrict\_id, readonly-postal\_code, btn-create-area-confirm  
\- Area Edit Drawer: areas-edit-drawer, btn-save-area  
\- Directors: directors-list-page, btn-add-director, directors-row-{employee\_id}-remove  
\- Area Heads: area-heads-list-page, btn-add-head, area-heads-row-{employee\_id}-remove  
\- Extension Codes List: ext-codes-list-page, btn-create-code, btn-export-ext-codes, ext-code-row-{ext\_code\_id}-open, ext-code-row-{ext\_code\_id}-assign, ext-code-row-{ext\_code\_id}-reassign, ext-code-row-{ext\_code\_id}-rename  
\- Extension Code Detail: ext-code-detail-page, btn-assign-ext-code, btn-reassign-ext-code, btn-rename-ext-code  
\- Modals: modal-create-ext-code, modal-rename-ext-code, modal-assign-ext-code, modal-reassign-ext-code, modal-add-head  
Note: Page Definitions did not include explicit data-test-id values — see TODOs.

\---

\#\# Assumptions & Confidence (global)  
\- ETag/If-Match format: assumed integer \`version\` in body and used as header If-Match: "\<version\>" (Confidence: Medium — confirm).    
\- Export endpoints may be async for large datasets; job polling endpoint not specified (Confidence: Medium).    
\- ERP and Geo integrations may return transient errors (424) — UI must handle degraded mode (Confidence: High).    
\- Server will emit downstream events (\`ext\_code.assigned\`, \`ext\_code.reassigned\`, \`ext\_code.renamed\`, \`area.updated\`) per API notes (Confidence: High).

\---

\#\# TODOs (ข้อที่ต้องเติม/ยืนยัน)  
1\. เพิ่ม/ยืนยัน data-test-id ใน Page Definitions และ UI components ตามรายการใน "Test Hooks" ข้างต้น (จำเป็นสำหรับทุก actionable step). ระบุจุดที่จะต้องเพิ่มใน front-end repo: page/element id mapping. (จำเป็น)  
2\. ยืนยันรูปแบบของ ETag / If-Match (string ETag หรือ integer version). Prev code assumes integer \`version\` in body and header If-Match: "\<version\>". (จำเป็น — affects PUT/PATCH headers)    
3\. ระบุหรือสร้าง job polling endpoint สำหรับ Export async flows (e.g., GET /api/jobs/{job\_id}) — ขณะนี้ API 8.18/8.19 ระบุเป็น async/sync per impl แต่ไม่มี job endpoint ที่ชัดเจน. (สำคัญถ้า implement async export)    
4\. ไม่มี endpoint สำหรับ "unassign only" (ลบ assignment ของ extension-code โดยไม่ reassign). Page Definition แนะนำว่าการลบ assignment ยังไม่มี API (Warnings: missing\_unassign\_endpoint). ถ้าต้องการให้เพิ่ม API: DELETE /api/extension-codes/{ext\_code\_id}/assign หรือ similar. (แนะนำ/ต้องเพิ่มถ้าต้องการ)    
5\. ยืนยันการตอบกลับ 409/423/412 payloads — ควรมีรายละเอียด conflicts (เช่น list of occupied codes) เพื่อให้ UI แสดง modal ที่ช่วยแก้ไขได้. ถ้าไม่มี โปรดเพิ่ม details ใน error payloads. (เพื่อ UX)    
6\. ยืนยันว่ server จะคืน existing resource on idempotent POST with same X-Idempotency-Key (เพื่อ UI behavior on retry). หากไม่ คืน ให้ระบุ error code behavior. (ต้องยืนยัน)    
7\. ยืนยัน RBAC fine-grained scopes และ server-filtering strategy (e.g., Area Head scope limits list rows) — Page Definitions assume server-side scoping but UI must know which actions to hide; need RBAC matrix mapping role→allowed actions. (จำเป็น)    
8\. กำหนด Webhook / outbound event consumer config (endpoint URL, signing, retry/backoff policy) — API notes mention events but not webhook contract. (ถ้าต้องการ integration)    
9\. หากต้องการ Document Viewer / Download / Doc-Gen retry flows — ไม่มี API สำหรับสร้าง/แสดงเอกสารใน inputs → เพิ่ม API (TODO: doc generation endpoints)    
10\. ยืนยัน format ของ idempotency key hashing function (which fields and hashing algorithm) — current patterns suggested but hashing algorithm unspecified (use SHA256 hex). (แนะนำให้ระบุ)    
11\. ตรวจสอบ column visibility rules for Extension Officer on Areas list (Warnings: column\_visibility\_for\_officer) — confirm which columns to hide for extension officers.    
12\. Export PDF not supported in current API (export\_pdf\_missing) — if needed, add endpoint.    
13\. Confirm server returns helpful conflict details for PATCH /api/areas/{id}/status when blocked by OCCUPIED codes (e.g., list of codes) — otherwise UI cannot surface which codes block deactivation.

\---

โปรดตอบรับ (ACK) หากต้องการให้ฉันแปลง TODOs เป็น RFC API requests หรือออกแบบ UI mocks ที่จับคู่กับ data-test-id ที่แนะนำ (พร้อม JSON schema ของ request/response สำหรับ front-end integration).

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

\# 11\. Business Rules

\#\#\# 11.1 Rules Inventory (merged)  
| Rule ID | Type (validation/domain) | Context (entity/endpoint) | State/Trigger | Condition | Expected | Error Code | Ref(A5/A6/A3) | Notes |  
|---|---|---|---|---|---|---|---|---|  
| R1 | validation | POST \`/api/extension-codes\` | create Code | \`display\_code\` ไม่ตรง \`^\\d{4}$\` | reject | VALIDATION\_FAILED | A5 §8.14; A6 §10.0.2 | regex ตรวจสอบที่ API |  
| R2 | validation | PUT \`/api/extension-codes/{ext\_code\_id}/rename\` | rename | \`new\_display\_code\` ไม่ตรง \`^\\d{4}$\` | reject | VALIDATION\_FAILED | A5 §8.15; A6 §10.0.2 | If-Match แยกกรณี |  
| R3 | domain | POST \`/api/extension-codes\` | create Code | \`display\_code\` ซ้ำ (global unique) | reject | CONFLICT | A5 §8.14; A6 §10.0.2 | uniqueness บังคับ DB |  
| R4 | domain | PUT \`/api/extension-codes/{ext\_code\_id}/rename\` | rename | \`new\_display\_code\` ซ้ำ | reject | CONFLICT | A5 §8.15; A6 §10.0.2 | ต้องตรวจสอบ atomic |  
| R5 | validation | POST \`/api/areas\` | create Area | \`area\_name\` ซ้ำ (uq\_areas\_area\_name) | reject | CONFLICT | A5 §8.3; A6 §10.0.2 | unique ภายใน org |  
| R6 | validation | POST \`/api/extension-codes\` | create Code | \`area\_id\` ไม่อ้างอิง areas.row\_id | reject | NOT\_FOUND | A5 §8.14; A6 §10.0.2 | FK ตรวจสอบก่อน insert |  
| R7 | domain | PATCH \`/api/areas/{area\_id}/status\` | deactivate Area | Area มี ExtensionCodes ที่เป็น OCCUPIED | reject | CONFLICT | A5 §8.5; A3 §5.2 | guard ตาม Journey C |  
| R8 | domain | POST \`/api/extension-codes/{ext\_code\_id}/assign\` | assign | Code.status \!= EMPTY | reject | CONFLICT | A5 §8.16; A3 §5.2 | guard before assign |  
| R9 | domain | POST \`/api/extension-codes/{ext\_code\_id}/assign\` | assign | employee already has active code | reject | CONFLICT | A5 §8.16; A6 §10.0.2 | uq\_eca\_employee\_id enforced |  
| R10 | validation | POST \`/api/extension-codes/{ext\_code\_id}/assign\` | assign | ERP employee.status \!= active | reject | VALIDATION\_FAILED | A5 §8.16; A6 §10.6 | ERP check; example uses VALIDATION\_FAILED |  
| R11 | validation | POST \`/api/areas\` | create Area | Missing \`X-Idempotency-Key\` header | reject | VALIDATION\_FAILED | A5 §9.1; A3 §5.2.2 | POST idempotency required |  
| R12 | validation | POST \`/api/extension-codes/{ext\_code\_id}/assign\` | assign | Missing \`X-Idempotency-Key\` header | reject | VALIDATION\_FAILED | A5 §8.16; A3 §5.2.2 | idempotency required for assign |  
| R13 | validation | PUT/PATCH/rename/status endpoints | update | Missing or mismatched \`If-Match\` header | reject | PRECONDITION\_FAILED | A5 §9.4; A3 §5.2.2 | optimistic locking via version |  
| R14 | domain | POST \`/api/extension-codes/{from\_id}/reassign\` | reassign | target \`to\_id\` not EMPTY | reject | CONFLICT | A5 §8.17; A3 §5.2 | precondition for reassign |  
| R15 | domain | POST \`/api/extension-codes/{from\_id}/reassign\` | reassign | concurrent race detected | reject | LOCKED | A5 §8.17; A3 §5.2.2 | return 423 LOCKED per Journey L |  
| R16 | validation | GET \`/api/areas\` | list/query | page\_size \> allowed (e.g., \>200) | reject | VALIDATION\_FAILED | A5 §8.1; A5 §9.3 | query param validation |  
| R17 | domain | DB constraints / assignments | assign/reassign | ext\_code already has active assignment (uq\_eca\_ext\_code\_row\_id) | reject | CONFLICT | A6 §10.0.2; A3 §5.2 | DB unique enforces R1 |  
| R18 | domain | DB constraints / assignments | assign/reassign | employee already assigned elsewhere (uq\_eca\_employee\_id) | reject | CONFLICT | A6 §10.0.2; A3 §5.2 | DB unique enforces R2 |  
| R19 | validation | POST \`/api/areas\` or PUT \`/api/areas/{area\_id}\` | create/update | postal\_code not \`^\\d{5}$\` when present | reject | VALIDATION\_FAILED | A6 §10.0.2; A5 §8.2 | postal\_code derived but validated |  
| R20 | domain | GET \`/api/areas/export\` | export | export too large for sync (implementation) | reject | — | A5 §8.18; A6 §10.6 | export oversize code not specified |  
| R21 | validation | POST \`/api/roles/directors\` | add Director | ERP employee inactive | reject | VALIDATION\_FAILED | A5 §8.10; A6 §10.6 | ERP status check required |  
| R22 | domain | DELETE \`/api/roles/directors/{employee\_id}\` | remove Director | Director not exists | reject | NOT\_FOUND | A5 §8.11; A3 §5.2 | standard not found |  
| R23 | validation | POST \`/api/areas/{area\_id}/heads\` | add Area Head | ERP employee inactive | reject | VALIDATION\_FAILED | A5 §8.7; A6 §10.6 | ERP check before assign |  
| R24 | domain | PUT \`/api/extension-codes/{ext\_code\_id}/rename\` | rename | If-Match missing or stale | reject | PRECONDITION\_FAILED | A5 §8.15; A3 §5.2.2 | optimistic lock enforced |  
| R25 | validation | any write endpoint | write | Authorization fails per RBAC | reject | AUTHZ\_FAILED | A5 §9.1; A3 §4.1 | RBAC enforced server-side |

\#\#\# 11.2 State→Action Guard Matrix (compact)  
State | Allowed | Blocked | Preconditions | Error Code  
\---|---|---|---|---  
Active | create Area\<br\>toggle status(inactivate)\<br\>export | delete | If-Match for status change\<br\>No OCCUPIED codes to inactivate | PRECONDITION\_FAILED / CONFLICT  
Inactive | toggle status(activate)\<br\>view | assign codes | If-Match for status change | PRECONDITION\_FAILED  
EMPTY | create Code\<br\>assign → OCCUPIED | reassign to EMPTY | area\_id valid\<br\>display\_code format \`^\\d{4}$\`\<br\>X-Idempotency-Key for POST | VALIDATION\_FAILED / CONFLICT  
OCCUPIED | reassign (atomic)\<br\>view | assign (new) | from\_code OCCUPIED\<br\>to\_code EMPTY for reassign\<br\>X-Idempotency-Key required | LOCKED / CONFLICT

\#\#\# 11.3 Soft-Delete & Retention (concise)  
\- Default: exclude records marked \`status='Archived'\` or with \`deleted\_at\` from list/detail by default.    
\- Restore: allowed if not purged; require If-Match when restoring and X-Idempotency-Key for POST restore.    
\- \[Default\] ถ้าอินพุตเงียบ → exclude by default; restorable if not purged. (ไม่มีตัวเลข retention ระบุ)

\#\#\# 11.4 Compensation & Recovery (P0 only)  
Scenario | Preconditions | Action | Resulting State/Data | Idempotency/ETag | Observability  
\---|---|---|---|---|---  
If-Match mismatch on PUT/PATCH | client used stale version | reject update; client fetches latest | resource unchanged | client sees PRECONDITION\_FAILED (412) | X-Request-Id, trace\_id  
Duplicate POST create Area retry | client retries without server ack | server dedupe by X-Idempotency-Key | single Area created | X-Idempotency-Key used to dedupe | audit:new; request trace  
Atomic reassign race | concurrent reassign attempts | one succeeds, others fail | from-\>EMPTY, to-\>OCCUPIED only once | POST reassign uses X-Idempotency-Key | return LOCKED (423); audit:reassigned  
ERP unavailable during assign | ERP lookup fails | abort assign; report dependency failure | no assignment created | no idempotent side-effect | FAILED\_DEPENDENCY (424); retry alert  
Partial bulk export failure | async job partially processed | mark job failed/partial, resume/rollback per job | consistent export state or job record | job idempotent via job\_id | job logs, job\_id, notifications

\#\#\# 11.5 Findings & Follow-ups  
\- Gap: no explicit unassign endpoint; owner: API team; ref: A3 §5.2 (add endpoint).    
\- Gap: export oversize error code unspecified; owner: API team; ref: A5 §8.18 (define TOO\_LARGE\_EXPORT or async).    
\- Gap: webhook payloads and URLs not specified; owner: Integrations; ref: A5 §9.6 (define signing/retry).    
\- Conflict: A5 uses \`VALIDATION\_FAILED\` not \`VALIDATION\_ERROR\`; owner: API team; ref: A5 §9.2 (align code names).    
\- Gap: numeric retention policy absent; owner: Data team; ref: A6 §10 (specify retention days).    
\- Conflict: canonical base\_path vs actual \`/api/...\` endpoints; owner: Platform; ref: A3 §5.2 (map reverse-proxy).    
\- Gap: Area Head "request change" flow missing API; owner: Product; ref: A3 §4.3 (add request endpoint).