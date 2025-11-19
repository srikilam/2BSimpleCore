\# 1\. Feature Overview  
\- Feature Id : feat\_cane-receiving\_20251113120000  
\- Feature Name : การรับอ้อย (Cane Receiving)  
\- Module : AGM / โลจิสติกส์และการชำระเงินอ้อย  
\- Base Path : /agri/cane-receiving  
\- Menu Trail : AGM \> โลจิสติกส์ \> การรับอ้อย

\---

\# 2\. Objective & Background

\#\# 2.1 Objectives  
\- ออก Receiving Note (PDF A4) พร้อม QR ที่มี receiving\_id สำหรับรถที่ Check-in แล้ว โดยสร้างเอกสารและ PDF เมื่อผู้ใช้กดยืนยันออกเอกสาร  
\- ดึงผลการเทจากระบบโรงงานแบบอัตโนมัติ (auto fetch) และต้องมีอัตราความสำเร็จ ≥ 95%; หากอัตโนมัติล้มเหลวต้องสามารถสลับเป็นโหมด manual เพื่อกรอก ccs และ net\_weight\_kg (2 ตำแหน่งทศนิยม)  
\- เมื่อดึงผลการเทสำเร็จให้ล็อกค่า (read-only) และเมื่อยืนยันออกเอกสารให้ตั้งสถานะเอกสารเป็น Issued, อัพเดต CBM เป็น "awaiting\_payment" และเรียก POST /api/weigh-coin/free เพื่อลด/ปลดเลขเหรียญชั่ง  
\- รองรับการ Void เอกสารโดยรับเหตุผล, เรียก API Void พร้อม If-Match, และย้อนสถานะ CBM เป็น "awaiting\_dump\_result" พร้อมป้องกันการชำระเงินต่อ  
\- รองรับการสแกน QR เพื่อ resolve รายการ Check-in และเปิด Drawer เพื่อเริ่มกระบวนการออกใบรับอ้อยทันที

\#\# 2.2 Business Context  
\- ปัญหา (current pain): ต้องรวบรวมผลการเทจากระบบโรงงานด้วยตนเองและพิมพ์เอกสาร A4 พร้อม QR ให้เกษตรกร ในขณะเดียวกันต้องอัพเดตสถานะ CBM และจัดการเลขเหรียญชั่ง ทำให้กระบวนการช้าและมีความผิดพลาดจากการกรอกมือ  
\- ทำไมต้องทำตอนนี้ (why now): มีความต้องการผนวกรวมข้อมูลผลการเทจากระบบโรงงานแบบเรียลไทม์และลดงาน manual เพื่อรองรับปริมาณรับอ้อยที่เพิ่มขึ้นและลดความล่าช้าในการชำระเงิน  
\- สถานะที่ต้องการ (desired future state): ผู้ใช้งานสามารถดึงผลการเทอัตโนมัติหรือกรอกสำรองได้ทันที ออกเอกสาร PDF+QR ได้ภายในเวลาที่รับได้ และระบบอัพเดตสถานะ CBM/เหรียญชั่งโดยอัตโนมัติ  
\- Journey หลักที่ต้องรองรับ: Issue Receiving (Auto success) → Issue Receiving (Auto fail → Manual) → NBM/CENTRAL variants → Void Receiving → Scan QR (open Drawer แล้วดึงผล)

\#\# 2.3 Success Metrics (KPIs)  
\- KPI: อัตราการดึงผลการเทแบบ Auto สำเร็จ ≥ 95% (per day)  
\- KPI: เวลาเฉลี่ยตั้งแต่เปิด Drawer ถึง Issued ≤ 60 วินาที  
\- KPI: อัตรา Void \< 2% ต่อวัน (ยกเว้นช่วงทดสอบ)

\#\#\# Warnings (if any)  
\- รูปแบบเชิงรายละเอียดของ PDF A4 (layout/text fields/ตำแหน่ง QR) ไม่ได้กำหนดไว้ที่นี่ — อ้างอิง FRD Cane Check-In แต่รายละเอียดฉบับสมบูรณ์ยังขาด  
\- ขอบเขต retry/timeout และนโยบาย retry สำหรับการเรียก GET /ext/factory/dump ไม่ได้ระบุ (ต้องกำหนด SLA/timeouts)  
\- สิทธิ์ผู้ใช้ที่อนุญาต Void (roles/permissions) ไม่ได้กำหนดชัดเจน  
\- การเก็บ/แสดงผล dump\_fetch\_mode และการแม็ปค่าในฐานข้อมูลไม่ได้ระบุแบบชัดเจน (ต้องตกลงกับ BE/API team)

\# 3\. Scope & Constraints

\#\# 3.1 In Scope  
\- List/Filter/ค้นหา รายการ Receiving ตามทะเบียนรถ, เบอร์คนขับ, CBM|NBM, เลขเหรียญชั่ง, วันที่ และ QR; รวม Action Bar: \[ออกใบรับอ้อย\], \[สแกน QR\], \[Export\]  
\- ดึงผลการเท Auto จากโรงงาน (GET /ext/factory/dump) และ fallback เป็น Manual เมื่อ Auto ล้มเหลว  
\- ออกใบรับอ้อย (สร้าง receiving record) และสร้าง PDF A4 พร้อม QR ที่ฝัง receiving\_id โดยเรียก POST /api/cane-receivings (idempotent)  
\- อัพเดต CBM เมื่อ Issued → PATCH /api/cbm/{booking\_id}/status {status:"awaiting\_payment"} และเมื่อ Void → PATCH /api/cbm/{booking\_id}/status {status:"awaiting\_dump\_result"}  
\- ปลดเลขเหรียญชั่งเมื่อ Issued โดยเรียก POST /api/weigh-coin/free {weigh\_coin}  
\- Void Receiving: รับเหตุผล, เรียก POST /api/cane-receivings/:id/void (If-Match) และเปลี่ยนสถานะเอกสารเป็น Void  
\- หน้าที่ครอบคลุม: Receiving List — /agri/cane-receiving (List, Search, Table, Pagination, Actions)  
\- หน้าที่ครอบคลุม: Issue Receiving — /agri/cane-receiving/issue (Drawer/Modal สำหรับพรีวิว Check-in, ดึงผล Auto, toggle เป็น manual, validate และยืนยัน)  
\- หน้าที่ครอบคลุม: Receiving Detail — /agri/cane-receiving/:id (View, พิมพ์/ดาวน์โหลด PDF, Void) และ QR Scanner — /agri/cane-receiving/scan (overlay เปิดกล้องและ resolve QR)

\#\# 3.2 Out of Scope  
\- ขั้นตอนของโรงงาน (ชั่งเข้า/เท/ชั่งออก) ในระบบภายนอก ไม่รวมการพัฒนา/เปลี่ยนแปลงระบบโรงงาน  
\- กระบวนการชำระเงิน (payment flow) — ดำเนินการในฟีเจอร์ Payment แยกต่างหาก

\#\# 3.3 Assumptions  
\- API ภายนอกโรงงาน (GET /ext/factory/dump) จะส่งค่า {ccs, net\_weight\_kg} ในรูปแบบที่แปลงเป็น 2 ตำแหน่งทศนิยมได้  
\- สำหรับ CBM/NBM จะมี quota\_id ที่ใช้เป็นพารามิเตอร์; สำหรับ CENTRAL หากไม่มี quota\_id จะสามารถค้นด้วย date \+ weigh\_coin ได้  
\- POST /api/cane-receivings ถูกออกแบบเป็น idempotent เพื่อป้องกันการสร้างเอกสารซ้ำเมื่อกดซ้ำ  
\- มีสิทธิ์/role ที่อนุญาตให้เรียก Void และการเรียก Void ต้องส่ง If-Match ตามที่ BE กำหนด  
\- ระบบสามารถเรียก PATCH /api/cbm/{booking\_id}/status และ POST /api/weigh-coin/free ได้สำเร็จเมื่อสถานะเปลี่ยนแปลง  
\- เวลาที่แสดงใน UI จะใช้ BE แสดงเป็น พ.ศ. แต่เก็บในฐานข้อมูลเป็น ISO-8601 \+ Asia/Bangkok

\#\# 3.4 Dependencies & Integrations  
\- External factory (Inbound):  
  \- GET /ext/factory/dump?quota\_id=\&date=\&weigh\_coin= → ตอบกลับ {ccs, net\_weight\_kg}  
  \- ใช้ quota\_id ถ้ามี (CBM/NBM); หาก CENTRAL ให้ค้นด้วย date+weigh\_coin  
\- Scan resolver (Inbound):  
  \- POST /api/scan/resolve {qr\_payload} → ตอบ {checkin\_id or source\_ref} เพื่อเปิด Drawer ของรายการนั้น  
\- Outbound integrations (เมื่อ Issued / Void):  
  \- PATCH /api/cbm/{booking\_id}/status {status:"awaiting\_payment"} เมื่อ Issued  
  \- PATCH /api/cbm/{booking\_id}/status {status:"awaiting\_dump\_result"} เมื่อ Void  
  \- POST /api/weigh-coin/free {weigh\_coin} เพื่อปลดเลขเหรียญชั่งเมื่อ Issued  
\- Receiving APIs:  
  \- POST /api/cane-receivings (idempotent) → สร้างเอกสาร \+ PDF  
  \- GET /api/cane-receivings?query=... และ GET /api/cane-receivings/:id  
  \- POST /api/cane-receivings/:id/pdf และ POST /api/cane-receivings/:id/void (If-Match)  
\- CBM enhancement:  
  \- เมื่อ Check-in (CBM) ระบบ CBM ตั้งเป็น "awaiting\_dump\_result"  
  \- เมื่อ Issued ที่ Receiving → CBM เปลี่ยนเป็น "awaiting\_payment"  
\- Operational constraints:  
  \- ขึ้นกับการตอบสนองและ SLA ของระบบโรงงาน (ต้องกำหนด timeout/retry)  
  \- เวลาที่แสดงใน UI ต้องแปลงตาม BE เป็น พ.ศ.

\#\#\# Warnings (if any)  
\- นโยบาย retry/timeout สำหรับการเรียก GET /ext/factory/dump ไม่ได้กำหนด — ต้องกำหนดค่าตัวเลข (เช่น timeout, retry attempts, backoff)  
\- รายละเอียดรูปแบบ PDF A4 และรูปแบบข้อมูลที่ต้องแสดงบน QR (payload ของ QR) ไม่ได้ระบุที่นี่ — อ้างอิง FRD Cane Check-In แต่ต้องมีสเป็กฉบับสมบูรณ์  
\- เงื่อนไขสิทธิ์ (who can Void) ไม่ได้ระบุ — ต้องกำหนด role/permission ก่อนพัฒนา  
\- ข้อกำหนด If-Match header (รูปแบบ ETag/versioning policy) สำหรับ Void ไม่ได้ระบุรายละเอียดเชิงเทคนิค  
\- หากมีความขัดแย้งระหว่างข้อมูลใน Page Definitions กับ Objective/Scope ให้แจ้งเพื่อเคลียร์ (ณ ปัจจุบันพบว่า Journeys และ Pages สอดคล้องกัน)

\# 4\. Target Users & RBAC

\> Feature: การรับอ้อย (Cane Receiving) · Module: AGM / โลจิสติกส์และการชำระเงินอ้อย · Base Path: /agri/cane-receiving · Menu: AGM \> โลจิสติกส์ \> การรับอ้อย

\#\# 4.1 Personas / Roles  
\- \*\*Receiving Staff\*\* — ออกใบรับอ้อย, ดึงผลการเท (Auto) และกรอกผลแบบ manual เมื่อ Auto ล้มเหลว; ยกเลิก (void) เอกสารได้ก่อนชำระเงิน; สแกน QR เพื่อเปิดรายการ Check-in  
\- \*\*Supervisor\*\* — ตรวจสอบกรณีพิเศษที่ต้องอนุมัติ/override; สามารถ void เอกสารได้ (มีสิทธิ์สูงกว่า Receiving Staff ในกรณีพิเศษ)  
\- \*\*Viewer\*\* — ดูรายการใน Receiving List / Receiving Detail; พิมพ์หรือดาวน์โหลด PDF เอกสารเพื่อมอบให้เกษตรกร (ไม่มีสิทธิ์แก้ไข/void)  
\- \*\*Admin/Owner\*\* — (ตาม RBAC มาตรฐาน ERP) บทบาทระดับระบบสำหรับตั้งค่าสิทธิ์/มอบหมาย role; อาจรวมสิทธิ์ทั้งหมดรวมถึงการย้อนสถานะ/restore (ระบุรายละเอียดสิทธิ์จริงตามระบบหลัก)

\#\# 4.2 Action Taxonomy (entity \= cane\_receivings)  
Standard actions (mapped to this feature and roles below):  
\- view:list  
\- view:detail  
\- search/filter  
\- export:csv  
\- export:pdf (พิมพ์/ดาวน์โหลด PDF)  
\- create (issue receiving → POST /api/cane-receivings)  
\- update (edit dump result in manual mode prior to issue)  
\- delete:soft (void → POST /api/cane-receivings/:id/void)  
\- restore (not defined in inputs)  
\- status:activate / status:inactivate|suspend|reactivate (not applicable / not defined)  
\- approve / reject (approve workflow not explicitly defined in inputs)  
\- bulk:\<action\> (bulk export / bulk issue not defined; Export button exists on list)  
\- Journey-specific actions (from Journeys/Pages):  
  \- dump:fetch\_auto (GET ext/factory/dump...)  
  \- dump:toggle\_manual (switch to manual mode)  
  \- dump:clear (ล้างค่า)  
  \- weighcoin:free (POST /api/weigh-coin/free)  
  \- cbm:update\_status (PATCH /api/cbm/{booking\_id}/status)  
  \- scan:resolve (POST /api/scan/resolve {qr\_payload})  
  \- pdf:generate (POST /api/cane-receivings/:id/pdf)  
Notes on mapping: dump:fetch\_auto, dump:toggle\_manual และ weighcoin:free จะถูกเรียก/trigger โดย Receiving Staff ขณะ Issue Receiving; void ใช้ POST /api/cane-receivings/:id/void (ต้องส่ง If-Match ตาม Page Definitions)

\#\# 4.3 RBAC Matrix (roles × actions)  
Legend: ✓ \= อนุญาต, — \= ไม่อนุญาต, C \= อนุญาตแบบมีเงื่อนไข (ระบุเงื่อนไขใต้ตาราง)

Actions \\ Roles | Receiving Staff | Supervisor | Viewer | Admin/Owner  
\---|:---:|:---:|:---:|:---:  
view:list | ✓ | ✓ | ✓ | ✓  
view:detail | ✓ | ✓ | ✓ | ✓  
search/filter | ✓ | ✓ | ✓ | ✓  
export:csv | C | C | C | ✓  
export:pdf | ✓ | ✓ | ✓ | ✓  
create (POST /api/cane-receivings) | ✓ | C | — | ✓  
update (manual dump fields) | ✓ | C | — | ✓  
dump:fetch\_auto (ext/factory/dump) | ✓ | ✓ | — | ✓  
dump:toggle\_manual | ✓ | ✓ | — | ✓  
dump:clear | ✓ | ✓ | — | ✓  
scan:resolve (POST /api/scan/resolve) | ✓ | ✓ | — | ✓  
pdf:generate (POST /api/cane-receivings/:id/pdf) | ✓ | ✓ | ✓ | ✓  
delete:soft / void (POST /api/cane-receivings/:id/void) | C | ✓ | — | ✓  
weighcoin:free (POST /api/weigh-coin/free) | ✓ | ✓ | — | ✓  
cbm:update\_status (PATCH /api/cbm/{booking\_id}/status) | ✓ | ✓ | — | ✓

Conditions (C) — เงื่อนไข:  
\- export:csv / export:pdf (C): ขึ้นกับ scope ของ RBAC ในระบบหลัก (อาจจำกัดตามสาขา/zone/โควต้า) — ตรวจสอบนโยบาย ERP หลัก  
\- create: Receiving Staff สามารถสร้าง (issue) เฉพาะสำหรับรายการในสถานะที่ "รอผลการเท" หรือรายการที่ได้รับจาก scan:resolve; การ issue จะบล็อกต่อเมื่อระบบแสดงว่า CBM/booking ถูกอนุญาตให้เปลี่ยนสถานะ  
\- update (manual dump fields): อนุญาตเฉพาะก่อนการยืนยันออกใบรับอ้อย (ก่อนการ POST สร้างเอกสาร); หาก Auto success fields จะถูก lock (ตาม Page Definitions)  
\- delete:soft / void: Receiving Staff สามารถ void เฉพาะ "ก่อนชำระเงิน" (ตาม Journey \#5); Supervisor มีสิทธิ์ void ในกรณีพิเศษตามนโยบาย  
\- weighcoin:free / cbm:update\_status: เป็นส่วนของ flow เมื่อ Issue สำเร็จ — ต้องดำเนินการร่วมกับ API ภายนอกตาม Journey (\#1): PATCH /api/cbm/{booking\_id}/status {status:"awaiting\_payment"} และ POST /api/weigh-coin/free {weigh\_coin}

Page / Route → Primary actions (ผูก Page & Journey เข้ากับ RBAC)  
\- Receiving List — Route: /agri/cane-receiving  
  \- Actions on page: view:list, search/filter, export:csv (Action Bar), scan:resolve (Scan QR), navigation to Issue Receiving Drawer, navigation to Receiving Detail  
  \- Roles: Receiving Staff (full list interaction, trigger Issue/Scan), Supervisor (view \+ act where allowed), Viewer (view \+ export/pdf)  
\- Issue Receiving — Drawer/Modal — Route: /agri/cane-receiving/issue (modal)  
  \- Actions on page: view:detail (check-in snapshot readonly), dump:fetch\_auto, dump:toggle\_manual, update (manual ccs/net\_weight\_kg), dump:clear, create (ยืนยันออกใบรับอ้อย → POST /api/cane-receivings), cbm:update\_status, weighcoin:free  
  \- Roles: Receiving Staff (primary actor), Supervisor (can intervene/void in special cases), Admin/Owner (full)  
  \- Validation: ถ้า Auto success fields locked; ถ้า manual ccs & net\_weight\_kg ต้องมี 2 ตำแหน่งทศนิยม (ตาม Page Definitions)  
\- Receiving Detail — Route: /agri/cane-receiving/:id  
  \- Actions on page: view:detail, pdf:generate, delete:soft (void) (POST /api/cane-receivings/:id/void with If-Match)  
  \- Roles: Receiving Staff (ดู, void ก่อนชำระเงิน), Supervisor (ดู \+ void), Viewer (ดู \+ pdf)  
\- QR Scanner — Route: /agri/cane-receiving/scan (overlay)  
  \- Actions on page: scan:resolve → open Issue Receiving Drawer (direct)  
  \- Roles: Receiving Staff (primary), Supervisor (สามารถใช้), Viewer (ไม่แนะนำ)

Route & API patterns (รวมจาก Base Path \+ Page Definitions)  
\- Pages:  
  \- GET /agri/cane-receiving  (Receiving List)  
  \- GET /agri/cane-receiving/scan (QR Scanner overlay)  
  \- modal/drawer: /agri/cane-receiving/issue (Issue Receiving Drawer)  
  \- GET /agri/cane-receiving/:id (Receiving Detail)  
\- APIs:  
  \- GET /api/cane-receivings?query=\&date\_from=\&date\_to=\&page=  (list / search/filter)  
  \- POST /api/scan/resolve  {qr\_payload}  (scan:resolve)  
  \- GET /api/cane-receivings/{id}  (detail)  
  \- POST /api/cane-receivings  (create / idempotent)  — Issue Receiving  
  \- PATCH /api/cane-receivings/{id}  (update — not detailed in inputs; used for partial edits if supported)  
  \- DELETE /api/cane-receivings/{id}  (not used; void used instead)  
  \- POST /api/cane-receivings/{id}/void  (void/soft-delete)  — requires If-Match per Page Definitions  
  \- POST /api/cane-receivings/{id}/pdf  (generate/download PDF)  
  \- POST /api/cane-receivings:bulk  (not defined but pattern suggested if bulk actions added)  
  \- GET ext/factory/dump?...  (dump:fetch\_auto → bind ccs, net\_weight\_kg)  
  \- PATCH /api/cbm/{booking\_id}/status {status:"awaiting\_payment"}  (cbm:update\_status)  
  \- POST /api/weigh-coin/free {weigh\_coin}  (weighcoin:free)

Row / Field-level restrictions  
\- Row-level:  
  \- Only items with dump\_status\_mode / status indicating "รอผลการเท" (per Page purpose) should be actionable for Issue Receiving.  
  \- Void allowed only for documents in state Issued but "ก่อนชำระเงิน" — หลังชำระเงิน void ต้องถูกจำกัด (ตาม Journey \#5)  
\- Field-level:  
  \- dump\_fetch\_mode \= auto → ccs & net\_weight\_kg locked (read-only)  
  \- manual mode → ccs & net\_weight\_kg editable; validation: 2 decimal places, required when manual  
  \- check-in snapshot fields presented read-only in Issue Drawer  
  \- Payment preferences (NBM) and "โควต้ากลาง" (CENTRAL) shown read-only in preview

Warnings (ข้อควรระวัง / ข้อมูลที่ขาด)  
\- ไม่มีรายการ explicit ของ A0.entities; ผมใช้ "cane\_receivings / cane-receivings" เป็นเอนทิตีหลักตาม Feature Name และ Page Definitions  
\- ขอบเขตของ "Admin/Owner" ไม่ได้กำหนดไว้อย่างชัดเจนในอินพุต — ต้องอ้างอิง RBAC มาตรฐาน ERP เพื่อระบุสิทธิ์จริง  
\- การอนุมัติ (approve/reject) ไม่ได้อธิบายไว้เป็น workflow แยก — หากมีขั้นตอนอนุมัติควรระบุเงื่อนไขและ transition ชัดเจน  
\- restore / reactivate operation ไม่ได้ระบุ API/behavior — หากต้องการรองรับการคืนสถานะ เริ่มต้นจากการออกแบบ API เพิ่มเติม  
\- เงื่อนไข row-level (เช่น ขอบเขตสาขา/zone ของ Viewing/Export) ไม่ได้ระบุใน Use Cases — โปรดยืนยันกับนโยบาย RBAC หลักของ ERP  
\- Void API ระบุ If-Match ใน Page Definitions — นโยบาย concurrency / ETag handling ยังไม่ชัด ต้องกำหนดเพิ่มเติมใน API spec

\# 6\. Capabilities Overview & Layout Patterns

\> Feature: \*\*การรับอ้อย (Cane Receiving)\*\* · Module: \*\*AGM / โลจิสติกส์และการชำระเงินอ้อย\*\* · Base Path: \*\*/agri/cane-receiving\*\* · Menu: \*\*AGM \> โลจิสติกส์ \> การรับอ้อย\*\*

\#\# 6.1 เป้าหมายและกรอบความสามารถ (ยึดตาม use cases)  
\- รองรับการค้นหา/กรอง/จัดหน้า/Export CSV และ Export PDF (ตามสิทธิ์)  
\- รองรับการสร้างเอกสาร (Issue Receiving) แบบ idempotent พร้อมการจัดการ ETag / If-Match  
\- รองรับการดึงผลการเทจากโรงงาน (dump:fetch\_auto) และโหมด manual เมื่อ Auto ล้มเหลว  
\- รองรับการสลับ dump\_fetch\_mode (auto ⇄ manual) และการ validate ค่า ccs/net\_weight\_kg  
\- เมื่อ Issue สำเร็จ ต้องเรียก side-effects: สร้าง PDF, PATCH CBM status, POST weigh-coin/free  
\- รองรับการ Void (soft-delete) โดยใช้ If-Match และบล็อกการชำระเงินต่อ  
\- บันทึก audit (actor/timestamp/reason/ETag/dump\_fetch\_mode/values/pdf reference)  
\- ผูก RBAC และ status gating ตาม matrix (A2); viewer-only, receiving staff, supervisor, admin

\#\# 6.2 Layout Patterns (ตัวอย่างอ้างอิง — ให้ AI สร้างจริงตามอินพุต)  
\- List Page: Header (breadcrumbs \+ H1) → \[\*\*SearchBar\*\*\] → \[\*\*FilterBar\*\* / Advanced Drawer\] → Action Bar (right-aligned primary CTA) → Main \[\*\*MasterDataTable\*\*\] (checkbox left, compact rows, head fixed) → \[\*\*PaginationControls\*\*\]  
\- Drawer / Modal (Issue / Detail): Right slide-in Drawer (width=40% default) with Header \[\*\*DrawerHeader\*\*\] → optional Tabs \[\*\*Tabs\*\*\] → scrollable content cards (\[\*\*Card\*\*\] / Key–Value grid) → sticky footer action bar (primary right)  
\- Create/Edit (if present): 12-column grid, main 8 / sidebar 4 (summary/status); but Issue uses Drawer pattern (preview \+ actions)  
\- Confirm Modal: centered modal 480px, focus-trap, explicit Cancel/Confirm actions  
\- Scanner Overlay: camera fullscreen overlay (focus-trap), on success resolve → open Issue Drawer

\> หมายเหตุ: Section 6 แสดง pattern ระดับสูง — ห้ามลงรายละเอียด field เฉพาะ (ไปที่ §7)

\#\# 6.3 Navigation Rules  
\- เส้นทางมาตรฐาน:  
  \- List \= \`\<base\_path\>\` (/agri/cane-receiving)  
  \- Create/Issue Drawer \= \`\<base\_path\>/issue\` (modal/drawer)  
  \- Detail \= \`\<base\_path\>/:id\`  
  \- Edit \= \`\<base\_path\>/:id/edit\` (ห้ามเข้าถึงเมื่อ status \= Archived / Void ตามกฎ)  
\- ห้ามเข้าหน้า Edit เมื่อสถานะเป็น \*\*Archived/ Void\*\*; RBAC ไม่พอ → redirect ไป List \+ แสดง \*\*toast 403\*\*  
\- Create/Update สำเร็จ → navigate ไปหน้า \*\*Detail\*\* ของ resource ที่สร้าง พร้อม toast สำเร็จ  
\- 412 (ETag mismatch) → refresh resource และเปิด dialog สำหรับ merge/รีเฟรช

\#\# 6.4 Microcopy & States (i18n/A11y)  
\- ข้อความ System states: Success/Error/Empty/403/409/412 ต้องเป็นภาษาไทย พร้อม aria-label และ role  
\- Focus order ต้องสอดคล้อง (Breadcrumb → Header → Search → Table → Action Bar)  
\- Buttons มี accessible name/aria-describedby เมื่อ action มีผลข้างเคียง (เช่น “จะเรียก PATCH /api/cbm/... และ POST /api/weigh-coin/free”)  
\- Modal/Drawer ต้องตั้ง focus to first actionable control และ restore focus เมื่อปิด

\#\# 6.5 Page–Journey Cohesion (ใหม่)  
\- ทุกหน้า/โมดัล/ดรอว์เออร์ต้องกำหนด “Journey Bindings”: ปุ่ม/เมนู → journey\_id → API call(s) → preconditions → onSuccess navigation/events  
\- Visibility & Action Gating ต้องอ้างอิงทั้งบทบาท (A2) และสถานะ (A3) เช่น:  
  \- ปุ่ม \[ยืนยันออกใบรับอ้อย\] เปิดเฉพาะเมื่อ role มีสิทธิ์ create และ resource อยู่ใน Draft  
  \- ปุ่ม \[Void\] เปิดเฉพาะเมื่อ resource \= Issued และยังไม่ผูกกับ Payment  
\- ใช้ If-Match สำหรับคำสั่งเปลี่ยนสถานะ/void; ใช้ Idempotency-Key สำหรับ POST ที่ retriable

\#\#\# Warnings (ถ้ามี)  
\- template\_source: ใช้เทมเพลตจาก ASCII Template Library เป็นหลัก; หาก token ใดในเทมเพลตไม่มีค่าจากอินพุต จะถูกแทนด้วย “—” และบันทึกใน §7 Warnings  
\- ระบุ rule\_id: หากต้องการ Edit ในสถานะ Issued ต้อง Void แล้วสร้างใหม่ — ข้อจำกัดนี้มาจาก inputs  
\- ข้อจำกัดของการ rollback เมื่อ side-effect บางรายการล้มเหลว (เช่น PDF สร้างสำเร็จแต่ PATCH CBM ล้มเหลว) ไม่มีนโยบาย rollback ชัด — แนะนำกำหนด compensating action (Warnings: design\_assumption)

\# 7\. Page Inventory (URLs & Screens)

\> Feature: \*\*การรับอ้อย (Cane Receiving)\*\* · Base Path: \*\*/agri/cane-receiving\*\*

\#\# 7.1 URLs & Routing  
\- \*\*List\*\*: \`/agri/cane-receiving\` — เริ่ม \`?page=1\&page\_size=25\&sort=-updated\_at\`  
\- \*\*Create / Issue Drawer\*\*: \`/agri/cane-receiving/issue\` (drawer/modal overlay)  
\- \*\*Detail\*\*: \`/agri/cane-receiving/:id\`  
\- \*\*Edit\*\*: \`/agri/cane-receiving/:id/edit\` (guarded — ห้ามเมื่อ Archived/Void)  
\- \*\*Scanner Overlay\*\*: \`/agri/cane-receiving/scan\` (overlay route)  
\- \*\*Routing guards\*\*: ห้าม Edit เมื่อ \*\*Archived/Void\*\*; RBAC ไม่พอ → redirect \`\<base\_path\>\` \+ \*\*toast 403\*\*

\#\# 7.2 Page Definitions

\#\#\# 7.2.1 Receiving List — \`/agri/cane-receiving\`  
\*\*Purpose\*\*: ศูนย์รวมรายการที่พร้อมออกใบรับอ้อย (CBM / NBM / CENTRAL) สำหรับการค้นหา หมวดปฏิบัติการและการสแกน QR

\#\#\#\# Layout  
\- ใช้เทมเพลต: \`packingList.v1\` (Page Type \= List)  
\- Grid Spec (จากเทมเพลต): 12col; fixed-header; toolbar right-aligned; table density=compact; checkbox first column; numeric → right; badges → centered

\#\#\#\# ASCII Wireframe  
\`\`\`  
\+------------------------------------------------------------------------------+  
| Breadcrumbs: AGM / โลจิสติกส์และการชำระเงินอ้อย › การรับอ้อย                    |  
\+------------------------------------------------------------------------------+  
| H1 Title: รายการการรับอ้อย                                                       |  
| H2 Subtitle: รายการที่รอผลการเท (CBM / NBM / CENTRAL)                          |  
\+------------------------------------------------------------------------------+  
| 🔎 Search: \[ ค้นหา (plate/driver\_phone/CBM|NBM/weigh\_coin) \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ \]  |  
|                                                     Filter: วันที่/สถานะ ▾     |  
|                                                     \[ Advanced Filters \]      |  
\+------------------------------------------------------------------------------+  
|                                                     \[ Export CSV \]            |  
|                                                     \[ Export PDF \]            |  
|                                                     \[ ออกใบรับอ้อย \]         |  
\+------------------------------------------------------------------------------+  
| \[ \] receiving\_id | source\_ref | source\_type | weigh\_coin | driver (phone) | ... |  
| source\_type→C | source\_ref→C | checkin\_time | dump\_fetch\_mode | ccs | net\_weight |  
| … (rows rendered by data source; numeric → right, badges centered)            |  
\+------------------------------------------------------------------------------+  
| Showing 1–25 of N                       « Previous  \[1\]  Next »               |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- breadcrumb: \[\*\*Breadcrumbs\*\*\] (use menu\_trail)  
\- header\_title: \[\*\*PageHeaderTitle\*\*\] (text: \*\*รายการการรับอ้อย\*\*)  
\- header\_desc: \[\*\*PageDescription\*\*\] (text: supplement)  
\- toolbar\_left: \[\*\*SearchBar\*\*\] (fields: query, date\_range)  
\- controls\_top\_right: \[\*\*AdvancedFilterDrawerV2\*\*\] (date\_range, source\_type filter)  
\- toolbar\_right: \[\*\*Button(import)\*\*\]?, \[\*\*Button(export)\*\*\], \[\*\*Button(primary)\*\* → \*\*ออกใบรับอ้อย\*\*\]  
\- main: \[\*\*MasterDataTable\*\*\] with columns:  
  \- \*\*source\_type\*\* → \[\*\*StatusBadge\*\*\] (labels: โควต้าจองคิว / โควต้าไม่ได้จอง / โควต้ากลาง)  
  \- \*\*source\_ref\*\*  
  \- \*\*weigh\_coin\*\*  
  \- \*\*driver\_name\*\* / \*\*driver\_phone\*\*  
  \- \*\*license\_plate\*\*  
  \- \*\*checkin\_time\*\* (BE format)  
  \- \*\*dump\_fetch\_mode\*\*  
  \- \*\*ccs\*\*, \*\*net\_weight\_kg\*\*  
  \- \*\*receiving\_id\*\*  
  \- actions column → row actions \[\*\*Button(ออกใบรับอ้อย)\*\*\], \[\*\*Button(ดูเอกสาร)\*\*\], \[\*\*Button(พิมพ์)\*\*\], \[\*\*Button(Void)\*\* \*conditional\*\]  
\- footer\_info: \[\*\*ResultsInfo\*\*\]  
\- pagination: \[\*\*PaginationControls\*\*\]

\#\#\#\# Actions / Events & Binding  
\- SearchBar submit → GET /api/cane-receivings?query={q}\&date\_from={d1}\&date\_to={d2}\&page={p}  
\- Action Bar:  
  \- \[\*\*ออกใบรับอ้อย\*\*\] → open Drawer \`/agri/cane-receiving/issue\` (with selected checkin\_id) (method: client navigation)  
  \- \[\*\*สแกน QR\*\*\] → navigate \`/agri/cane-receiving/scan\` (overlay)  
  \- \[\*\*Export\*\*\] → GET /api/cane-receivings/export?{filters} (CSV) (RBAC-checked)  
\- Row actions:  
  \- \[\*\*ออกใบรับอ้อย\*\*\] → open Issue Drawer (prefill check-in snapshot)  
  \- \[\*\*ดูเอกสาร\*\*\] → navigate \`/agri/cane-receiving/:id\` (Detail)  
  \- \[\*\*พิมพ์\*\*\] → POST /api/cane-receivings/:id/pdf → download  
  \- \[\*\*Void\*\*\] → open Void Confirm Modal (only for Issued & role allowed)  
\- Enable/Disable rules:  
  \- \[\*\*ออกใบรับอ้อย\*\*\] enabled only for rows in Draft/rAwaitingDumpResult per page purpose  
  \- \[\*\*Void\*\*\] visible/enabled only when status \= Issued and role allows and not linked to payment

\#\#\#\# Validation  
\- Search inputs validated client-side (date range valid)  
\- Export respects RBAC and scope filters

\#\#\#\# RBAC & Status Gating  
\- view:list/search/filter: Viewer / Receiving Staff / Supervisor / Admin per matrix  
\- action \[ออกใบรับอ้อย\]: Receiving Staff / Supervisor / Admin  
\- \[Void\] row action: Supervisor or Receiving Staff conditionally (ดู A2 conditions)  
\- Redirect to List \+ toast 403 when action attempted without permission

\#\#\#\# Microcopy (i18n/A11y)  
\- Search placeholder: \*\*ค้นหา (ป้ายทะเบียน/เบอร์คนขับ/CBM/NBM/weigh\_coin)\*\*  
\- Buttons: primary aria-label e.g., \*\*ออกใบรับอ้อย\*\* aria-label="ออกใบรับอ้อย สำหรับรายการที่เลือก"  
\- Table: column headers have scope="col", numeric columns aria-labels include unit  
\- Empty state message: \*\*ไม่พบรายการที่ตรงกับเงื่อนไข\*\* focusable link to "Reset filters"

\#\#\#\# Journey Bindings  
\- Journey \#1 / \#2 / \#3 / \#4: List row → \`/agri/cane-receiving/issue\` (open drawer) → follow Issue Receiving journeys  
\- Journey \#6: List → \[สแกน QR\] → \`/agri/cane-receiving/scan\` → on resolve open Issue Drawer for that checkin

\#\#\#\# Notes  
\- Table head fixed; checkbox leftmost; primary CTA rightmost per global norms

\---

\#\#\# 7.2.2 Issue Receiving — \`/agri/cane-receiving/issue\` (Drawer)  
\*\*Purpose\*\*: พรีวิว Check-in \+ ดึงผลการเท (Auto) \+ สลับเป็น Manual \+ ยืนยันออกใบรับอ้อย

\#\#\#\# Layout  
\- ใช้เทมเพลต: \`viewDrawer.v1\` (View Drawer — Standard)  
\- Grid Spec (จากเทมเพลต): Drawer:right; width=40%; header H1 \+ actions; tabs optional; content: KeyValue 2-col \+ Cards; footer sticky primary action right

\#\#\#\# ASCII Wireframe  
\`\`\`  
\+------------------------------------------------------------------------------+  
| Drawer: slide-in from right (width=40%)                                      |  
\+------------------------------------------------------------------------------+  
| H1: ออกใบรับอ้อย — Check-in CRN-xxxx                 \[  พิมพ์ \] \[ ... \] \[✖\] |  
| Sub: ข้อมูลพรีวิว (farmer / vehicle / weigh\_coin / checkin\_time)            |  
\+------------------------------------------------------------------------------+  
| View Mode: \[ ● พรีวิว Check-in (read-only) \]   \[ ○ PDF Preview \]             |  
\+------------------------------------------------------------------------------+  
| Tabs: Overview | Dump Result | Audit                                               |  
\+------------------------------------------------------------------------------+  
| ┌──────── Section: Check-in Snapshot ───────────────────────────────────────┐ |  
| | • \*\*เกษตรกร\*\* : —                                                      | |  
| | • \*\*ป้ายทะเบียน\*\* : —                                                  | |  
| | • \*\*weigh\_coin\*\* : —                                                    | |  
| | • \*\*checkin\_time\*\* : —                                                  | |  
| └──────────────────────────────────────────────────────────────────────────┘ |  
| ┌──────── Section: Dump Result (binding) ─────────────────────────────────┐ |  
| | dump\_fetch\_mode: \[auto | manual\] (readonly=auto when success)           | |  
| | \[ ดึงผลการเท (Auto) \] \[ ล้างค่า \]                                     | |  
| | • \*\*ccs\*\* : — (decimal 2\)                                               | |  
| | • \*\*net\_weight\_kg\*\* : — (decimal 2\)                                     | |  
| └──────────────────────────────────────────────────────────────────────────┘ |  
\+------------------------------------------------------------------------------+  
|                                              \[ยกเลิก\]   \[ยืนยันออกใบรับอ้อย\] |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- drawer\_header: \[\*\*DrawerHeader(title,subtitle,meta,actions)\*\*\] (title uses \*\*Check-in snapshot\*\* info)  
\- view\_mode: \[\*\*SegmentedControl\*\*\] (พรีวิว / PDF Preview)  
\- tabs: \[\*\*Tabs\*\*\] — Overview / Dump Result / Audit  
\- content\_sections: \[\*\*Card(KeyValueGrid-2col)\*\* (Check-in Snapshot), \*\*Card(FreeArea)\*\* (Dump Result form), \*\*Card(FreeArea)\*\* (Audit/Notes)\]  
\- footer\_buttons: \[\*\*Button(cancel,variant=ghost)\*\*\], \[\*\*Button(confirm,variant=primary)\*\* ปุ่มหลัก\]

\#\#\#\# Actions / Events & Binding  
\- On open: GET /api/cane-receivings?checkin\_id={id} หรือ GET /api/checkins/{id} → prefill Check-in snapshot (client)  
\- \[\*\*ดึงผลการเท (Auto)\*\*\] \[\*\*Button\*\*\] → GET ext/factory/dump?quota\_id={quota\_id}\&checkin\_date={d}\&weigh\_coin={weigh\_coin}  
  \- On success (fetch\_status=success): bind response to \`ccs\` (decimal(5,2)) and \`net\_weight\_kg\` (decimal(10,2)); set \`dump\_fetch\_mode\`=auto; lock fields  
  \- On failure (not\_found|mismatch|error): show inline error message (ไทย) and enable manual mode toggle  
\- Toggle \`dump\_fetch\_mode\` → client state change; when manual: enable editable fields  
\- \[\*\*ล้างค่า\*\*\] → clear \`ccs\` & \`net\_weight\_kg\`, set \`dump\_fetch\_mode\`=—  
\- \[\*\*ยืนยันออกใบรับอ้อย\*\*\] \[\*\*Button (primary)\*\*\] → POST /api/cane-receivings  
  \- Payload: { checkin\_id, dump\_fetch\_mode, ccs, net\_weight\_kg, issuing\_by }  
  \- Headers: Idempotency-Key: {uuid}  
  \- On success (201): Response includes receiving\_id, pdf\_url → then:  
    \- POST /api/cane-receivings/:id/pdf (or used by server) (if not auto-generated)  
    \- PATCH /api/cbm/{booking\_id}/status {status:"awaiting\_payment"} (for CBM)  
    \- POST /api/weigh-coin/free {weigh\_coin}  
    \- emit event \`cane\_receiving.issued\`  
    \- navigate → \`/agri/cane-receiving/:receiving\_id\` \+ toast success  
  \- On validation error (422): show field-level errors  
  \- On 409/412: show conflict dialog / fetch latest / instruct user to retry

\#\#\#\# Validation  
\- If \`dump\_fetch\_mode\` \= manual → \*\*ccs\*\* & \*\*net\_weight\_kg\*\* required; format: 2 decimal places  
\- If Auto success → fields locked and read-only  
\- POST must include Idempotency-Key to avoid duplicates  
\- Client-side numeric range checks: \*\*ccs\*\* within decimal(5,2) bounds; \*\*net\_weight\_kg\*\* within decimal(10,2) bounds

\#\#\#\# RBAC & Status Gating  
\- Visible: Receiving Staff, Supervisor, Admin (Viewer can see only in read scenario if allowed)  
\- \[ยืนยันออกใบรับอ้อย\] enabled only when role allowed AND current row in Draft / awaiting dump result  
\- Void not available inside Issue Drawer (void from Detail)  
\- If role lacks create → hide/disable primary → attempt triggers redirect \+ toast 403

\#\#\#\# Microcopy (i18n/A11y)  
\- Header title: \*\*ออกใบรับอ้อย — พรีวิว Check-in\*\*  
\- Auto fetch button aria-label: "ดึงผลการเทจากโรงงาน (Auto)"  
\- Manual field labels:  
  \- \*\*ccs\*\* \[\*\*Input\*\*\] (field: \*\*ccs\*\*) — helper: "ค่า CCS (2 ตำแหน่งทศนิยม)"  
  \- \*\*net\_weight\_kg\*\* \[\*\*Input\*\*\] (field: \*\*net\_weight\_kg\*\*) — helper: "น้ำหนักสุทธิ (กก.) 2 ตำแหน่ง"  
\- Confirm button text: \*\*ยืนยันออกใบรับอ้อย\*\* aria-describedby explains side-effects (จะสร้าง PDF และอัพเดตสถานะ CBM)

\#\#\#\# Journey Bindings (ใหม่)  
\- Journey \#1 (Issue Receiving CBM, Auto success): List → Open Drawer → \`\<IssueDrawer\>/ดึงผลการเท (Auto)\` → ext/factory/dump success → fields bound → \`\<IssueDrawer\>/ยืนยันออกใบรับอ้อย\` → POST /api/cane-receivings (Idempotency-Key) → PATCH /api/cbm/{booking\_id} status=awaiting\_payment \+ POST /api/weigh-coin/free → navigate to Detail (status=Issued)  
  \- Preconditions: ext/factory/dump returns success; role has create  
\- Journey \#2 (Auto fail → Manual): same open flow → ext/factory/dump error → toggle manual → user edits \*\*ccs\*\*, \*\*net\_weight\_kg\*\* (validate) → confirm → POST /api/cane-receivings with dump\_fetch\_mode=manual → same side-effects \+ store dump\_fetch\_mode=manual  
\- Journey \#3 / \#4 (NBM / CENTRAL): same as \#1/\#2; additional read-only display of payment\_prefs / central quota in Check-in Snapshot (no extra selection in Drawer)

\#\#\#\# Notes  
\- Must send Idempotency-Key on POST /api/cane-receivings  
\- If some side-effects fail after create (e.g., PATCH CBM fails), system should surface error and mark event — rollback policy TBD (Warning)

\---

\#\#\# 7.2.3 Receiving Detail — \`/agri/cane-receiving/:id\`  
\*\*Purpose\*\*: แสดงเอกสารใบรับอ้อย (Issued / Void) และให้การพิมพ์/ดาวน์โหลด PDF หรือ Void (ตามสิทธิ์)

\#\#\#\# Layout  
\- ใช้เทมเพลต: \`viewDrawer.v1\` (ใช้เป็น Page view; header H1 \+ status badge)  
\- Grid Spec: Drawer-like detail view; header \+ tabs; content scrollable; footer actions sticky

\#\#\#\# ASCII Wireframe  
\`\`\`  
\+------------------------------------------------------------------------------+  
| H1: ใบรับอ้อย CRN-2025-00001               \[สถานะ: Issued\] \[ พิมพ์ \] \[✖\]  |  
\+------------------------------------------------------------------------------+  
| Tabs: Overview | Dump Result | Audit                                                  |  
\+------------------------------------------------------------------------------+  
| ┌──────── Card: Check-in Snapshot ────────────────────────────────────────┐ |  
| | • booking\_id / source\_ref : CBM-12345                                  | |  
| | • farmer / driver / license\_plate : —                                   | |  
| | • checkin\_time : —                                                      | |  
| └─────────────────────────────────────────────────────────────────────────┘ |  
| ┌──────── Card: Dump Result ─────────────────────────────────────────────┐ |  
| | • dump\_fetch\_mode : auto/manual                                         | |  
| | • ccs :  —                                                              | |  
| | • net\_weight\_kg : —                                                     | |  
| └─────────────────────────────────────────────────────────────────────────┘ |  
| ┌──────── Card: Audit ───────────────────────────────────────────────────┐ |  
| | • issued\_at / issued\_by / pdf\_url                                       | |  
| | • voided\_at / voided\_by / void\_reason (if Void)                         | |  
| └─────────────────────────────────────────────────────────────────────────┘ |  
\+------------------------------------------------------------------------------+  
|                                               \[ย้อนกลับ\]   \[Void\*\] \[พิมพ์\] |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- drawer\_header / page header: \[\*\*DrawerHeader\*\*\] (title \= \*\*receiving\_id\*\*, meta \= status badge \[\*\*StatusBadge\*\*\])  
\- tabs: \[\*\*Tabs\*\*\] — Overview / Dump Result / Audit  
\- content\_sections: \[\*\*Card(KeyValueGrid-2col)\*\* (Check-in Snapshot), \*\*Card(KeyValueGrid\*\* for Dump Result), \*\*Card(ActivityLog/Audit)\*\*\]  
\- footer\_buttons: \[\*\*Button(back)\*\*\], \[\*\*Button(void,variant=danger)\*\* \*conditional\*\], \[\*\*Button(print)\*\*\]

\#\#\#\# Actions / Events & Binding  
\- On load: GET /api/cane-receivings/:id → render fields  
\- \[\*\*พิมพ์/ดาวน์โหลด PDF\*\*\] → POST /api/cane-receivings/:id/pdf → returns pdf\_url / stream  
\- \[\*\*Void\*\*\] → open Void Confirm Modal → on confirm → POST /api/cane-receivings/:id/void  
  \- Headers: If-Match: \`\<etag\>\`  
  \- Body: { reason: string }  
  \- On success: update UI (status=Void), PATCH /api/cbm/{booking\_id}/status {status:"awaiting\_dump\_result"}, emit cane\_receiving.void  
\- Buttons visibility:  
  \- \[Void\] only visible/enabled when status \= Issued AND role permitted AND document not linked to Payment

\#\#\#\# Validation  
\- Void modal requires non-empty reason (min length 5\) — validate client-side before calling API  
\- POST /void must include If-Match; client must fetch current ETag before submit

\#\#\#\# RBAC & Status Gating  
\- view: Viewer / Receiving Staff / Supervisor / Admin  
\- void: Supervisor or Receiving Staff conditionally (see A2)  
\- print/pdf: allowed to Viewer and above

\#\#\#\# Microcopy (i18n/A11y)  
\- Status badge text (ไทย): \*\*ร่าง / ออกแล้ว / ยกเลิก\*\*  
\- Void confirmation tooltip: "ยืนยันการยกเลิกใบรับอ้อย จะย้อนสถานะ CBM เป็นรอผลการเท"  
\- PDF button aria-label: "ดาวน์โหลดใบรับอ้อย (PDF)"

\#\#\#\# Journey Bindings (ใหม่)  
\- Journey \#5 (Void Receiving): Receiving Detail \`/agri/cane-receiving/:id\` → user clicks \`\[Void\]\` → Void Confirm Modal → confirm with reason → POST /api/cane-receivings/:id/void (If-Match) → on success: status=Void; PATCH /api/cbm/{booking\_id}/status {awaiting\_dump\_result} → emit event; UI update

\#\#\#\# Notes  
\- Ensure ETag concurrency: if 412 returned, show message "ข้อมูลไม่ทันสมัย กรุณารีเฟรช" และปุ่มรีเฟรช

\---

\#\#\# 7.2.4 Void Confirm Modal — (modal)  
\*\*Purpose\*\*: ขอเหตุผลและยืนยันการ Void (Issed → Void)

\#\#\#\# Layout  
\- ใช้เทมเพลต: \`deleteConfirm.v1\` (Modal:center; width \~480px)

\#\#\#\# ASCII Wireframe  
\`\`\`  
\+------------------------------------------------------------------------------+  
|                           ⚠️  ยกเลิก ใบรับอ้อย CRN-2025-00001                    |  
\+------------------------------------------------------------------------------+  
| คุณแน่ใจว่าจะยกเลิก \*\*CRN-2025-00001\*\* หรือไม่?                             |  
| การยกเลิกจะย้อนสถานะ CBM เป็น "awaiting\_dump\_result" และไม่สามารถชำระเงินต่อ   |  
|                                                                              |  
| โปรดระบุเหตุผล:                                                            |  
| \[ \*\*เหตุผลการยกเลิก\*\* \[Textarea\] (field: \*\*void\_reason\*\*) \]                 |  
\+------------------------------------------------------------------------------+  
|                                               \[ ยกเลิก \]   \[ ยืนยันการยกเลิก \] |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- modal\_header: \[\*\*Icon(Warning)\*\*\] \+ \[\*\*ModalTitle\*\*\]  
\- modal\_body: \[\*\*Paragraph\*\*\], \[\*\*Textarea\*\* (field: \*\*void\_reason\*\*)\]  
\- modal\_footer: \[\*\*Button(cancel)\*\*\], \[\*\*Button(delete,variant=danger)\*\*\]

\#\#\#\# Actions / Events & Binding  
\- Confirm (delete) → POST /api/cane-receivings/:id/void  
  \- Headers: If-Match: \`\<etag\>\`  
  \- Body: { void\_reason: string }  
  \- On success: close modal, navigate/update Detail (status=Void), PATCH CBM booking status  
  \- On 412: show conflict message and option to refresh  
  \- On 403: show toast 403

\#\#\#\# Validation  
\- \*\*void\_reason\*\* required; min length 5 characters  
\- Must attach If-Match header; if missing → show client validation error

\#\#\#\# RBAC & Status Gating  
\- Only Supervisor or Receiving Staff allowed per A2 conditions and only for Issued documents not linked to Payment

\#\#\#\# Microcopy (i18n/A11y)  
\- Modal title: \*\*ยกเลิก ใบรับอ้อย\*\*  
\- Confirmation button text: \*\*ยืนยันการยกเลิก\*\*  
\- Textarea aria-label: "เหตุผลการยกเลิก (จำเป็น)"

\#\#\#\# Journey Bindings (ใหม่)  
\- Journey \#5: Detail → \[Void\] → Void Confirm Modal → Confirm → POST /api/cane-receivings/:id/void (If-Match) → PATCH /api/cbm/{booking\_id}/status {awaiting\_dump\_result} → emit \`cane\_receiving.void\`

\---

\#\#\# 7.2.5 QR Scanner Overlay — \`/agri/cane-receiving/scan\` (Overlay)  
\*\*Purpose\*\*: เปิดกล้องสแกน QR เพื่อ resolve รายการ Check-in และเปิด Issue Drawer ให้ตรงรายการ

\#\#\#\# Layout  
\- ไม่พบเทมเพลตตรงในไลบรารี → สร้าง \*\*Custom ASCII\*\* (template\_source=custom)  
\- Grid Spec: Fullscreen overlay; camera view centered; hint text bottom; actions top-right close; focus-trap; fallback manual input field

\#\#\#\# ASCII Wireframe (Custom)  
\`\`\`  
\+------------------------------------------------------------------------------+  
| QR Scanner (Overlay)                                     \[ ปิด ✖ \]          |  
\+------------------------------------------------------------------------------+  
| Camera Live View (centered)                                                 |  
|  ┌─────────────────────────────────────────────── 80% ────────────────────┐  |  
|  |                                                                       |  |  
|  |                  \[ Live Camera Preview / QR bounding \]               |  |  
|  |                                                                       |  |  
|  └───────────────────────────────────────────────────────────────────────┘  |  
|                                                                              |  
| Hint: นำ QR จากใบ Check-in มาชิดกลางกรอบเพื่อสแกน                           |  
| If camera unavailable: \[พิมพ์โค้ดด้วยตนเอง\] \[ Input: \*\*qr\_payload\*\* \]       |  
\+------------------------------------------------------------------------------+  
|                                                        \[ ยกเลิก \] \[ สแกนใหม่ \] |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots / custom)  
\- overlay\_header: \[\*\*Icon(Scanner)\*\*\] \+ \[\*\*Button(close)\*\*\]  
\- camera\_view: \[\*\*QRCodeScanner\*\*\] (new component created; event: onScanResult)  
\- fallback\_input: \[\*\*Input\*\*\] (field: \*\*qr\_payload\*\*) \+ \[\*\*Button(resolve)\*\*\]  
\- footer\_actions: \[\*\*Button(cancel)\*\*\], \[\*\*Button(rescan)\*\*\]

\#\#\#\# Actions / Events & Binding  
\- On open: request camera permission; start live preview  
\- On scan success: POST /api/scan/resolve { qr\_payload } → response returns checkin\_id or cane\_receiving id  
  \- If resolved to Draft check-in: open \`/agri/cane-receiving/issue\` with that checkin (client nav)  
  \- If resolved to existing receiving\_id: open \`/agri/cane-receiving/:id\` detail  
\- On manual resolve: POST /api/scan/resolve { qr\_payload } same semantics  
\- On error: show inline message (ไทย) with retry option

\#\#\#\# Validation  
\- qr\_payload must be non-empty for manual resolve  
\- Camera permission decline → show fallback manual input

\#\#\#\# RBAC & Status Gating  
\- Accessible to Receiving Staff / Supervisor (Viewer not recommended)  
\- Resulting navigation respects resource status: if resolved item not in Draft → show appropriate page (Detail) and disallow Issue

\#\#\#\# Microcopy (i18n/A11y)  
\- Hint text: \*\*สแกน QR จากใบ Check-in\*\* aria-live status updates for scan result  
\- Buttons: \*\*สแกนใหม่\*\*, \*\*ยกเลิก\*\* aria-labels provided  
\- Camera permission prompt text in Thai

\#\#\#\# Journey Bindings (ใหม่)  
\- Journey \#6 (Scan QR): Receiving List → \[สแกน QR\] → \`/agri/cane-receiving/scan\` → onScanResult → POST /api/scan/resolve → open Issue Drawer for resolved checkin (then follow Journey \#1/\#2)

\#\#\#\# Notes  
\- Custom template used because library lacked a camera/scan overlay template (\`template\_source=custom\`, reason="no camera/overlay template in ASCII library")  
\- New component created: \[\*\*QRCodeScanner\*\*\] (logged to New Component sheet)

\#\# 7.3 Screen Components (React-friendly names)  
\- Pages: \`ReceivingListPage\`, \`ReceivingIssueDrawer\`, \`ReceivingDetailPage\`, \`ReceivingVoidModal\`, \`QRCodeScannerOverlay\`  
\- Composables: \`ReceivingFilterBar\`, \`ReceivingMasterTable\`, \`ReceivingForm\`, \`ReceivingCheckinSnapshot\`, \`ReceivingDumpResultCard\`, \`PaginationBar\`, \`BulkActionsBar\`, \`ToastHost\`, \`ActivityLog\`, \`StatusActions\`, \`ApprovalActions\`, \`AttachmentPanel\`

\#\# 7.4 Client Flows (Create/Update/Delete/Restore/Bulk)  
\- Create (Issue):  
  \- client-validate → POST /api/cane-receivings (Idempotency-Key) → 201 → navigate \`/agri/cane-receiving/:id\` \+ toast  
  \- On success trigger: PATCH /api/cbm/{booking\_id}/status {status:"awaiting\_payment"} and POST /api/weigh-coin/free {weigh\_coin}  
\- Update (manual dump fields before issue):  
  \- local edit → client validate (2 decimals) → included in POST create payload  
\- Void:  
  \- POST /api/cane-receivings/:id/void (If-Match) \+ {void\_reason} → 200 → update UI status=Void → PATCH CBM {awaiting\_dump\_result}  
\- Scan:  
  \- POST /api/scan/resolve {qr\_payload} → returns checkin\_id or receiving\_id → navigate accordingly  
\- Bulk:  
  \- Export (CSV): GET /api/cane-receivings/export?filters (RBAC-checked)

\#\# 7.5 Microcopy / Empty / Error States (i18n & A11y)  
\- Empty List: \*\*ไม่พบรายการที่รอผลการเท\*\*; CTA: \*\*รีเฟรช / ล้างตัวกรอง\*\*  
\- Auto fetch error: \*\*ไม่พบข้อมูลผลการเทจากโรงงาน — กรุณาเปลี่ยนเป็นโหมด manual\*\* (aria-live polite)  
\- Validation error messages in Thai next to fields (e.g., "\*\*กรุณากรอก CCS ให้มี 2 ตำแหน่งทศนิยม\*\*")  
\- 403: \*\*คุณไม่มีสิทธิ์ดำเนินการนี้\*\*; focus to toast  
\- 412: \*\*ข้อมูลถูกแก้ไขโดยผู้อื่น กรุณารีเฟรชแล้วลองใหม่\*\* \+ option to fetch latest

\#\# 7.6 Journey ↔ Page Crosswalk (ใหม่ แนะนำ)  
\- Journey \#1 (Issue CBM Auto success): ReceivingListPage(row) → ReceivingIssueDrawer(dump:fetch\_auto → POST /api/cane-receivings) → DetailPage  
\- Journey \#2 (Auto fail → Manual): ReceivingListPage → IssueDrawer(fetch fail → manual edit → POST /api/cane-receivings dump\_fetch\_mode=manual) → DetailPage  
\- Journey \#3 / \#4 (NBM / CENTRAL): same as \#1/\#2 with read-only payment\_prefs / central quota rendering in Check-in Snapshot  
\- Journey \#5 (Void): ReceivingDetailPage → VoidModal → POST /api/cane-receivings/:id/void (If-Match)  
\- Journey \#6 (Scan QR): ReceivingListPage → QRCodeScannerOverlay → POST /api/scan/resolve → open IssueDrawer

\#\#\# Warnings (ถ้ามี)  
\- template\_source for QR Scanner: \`custom\` — reason: ไม่มีเทมเพลต camera/QR overlay ในไลบรารี → วาด ASCII ใหม่ (rule\_id: template\_source=custom)  
\- unknown tokens from templates replaced with "—": \`{{subtitle}}\` / \`{{meta\_right}}\` / \`{{col\_pk}}\` etc. (บาง tokenในเทมเพลตไม่ได้มีค่าในอินพุต) — รายการ token ที่ไม่พบ: subtitle, meta\_right, col\_pk, col\_loc, col\_qty, col\_wt, col\_lbl, col\_status, col\_updated, import\_label (แสดงใน ASCII เป็น —)  
\- missing\_components: components ที่ระบุในเทมเพลตแต่ชื่อไม่ตรง exact ใน component\_set (normalize mapping):  
  \- Normalizations available: Textbox→\[\*\*Input\*\*\], Dropdown→\[\*\*Select\*\*\], TagInput→\[\*\*TokenInput\*\*\], PageHeaderTitle→\[\*\*PageHeaderTitle\*\*\] (ตรวจพบหรือมีเทียบเท่า)  
  \- New component created: \[\*\*QRCodeScanner\*\*\] (สถานะ: Not in development) — หากต้องการพัฒนา โปรดยืนยัน spec  
\- design\_assumption: ไม่มีนโยบาย rollback ชัดเจนเมื่อ side-effects (PATCH CBM, POST weigh-coin/free) ล้มเหลว หลัง POST create → แนะนำกำหนด compensating transactions  
\- rule\_id violations (ถ้ามี):  
  \- หากต้องการ Edit resource หลังเป็น Issued ต้อง Void แล้วสร้างใหม่ — นำมาจาก inputs (rule\_id: edit\_after\_issued)  
\- ข้อมูลไม่ครบ:  
  \- ไม่มี schema payloads แบบละเอียดสำหรับ POST /api/cane-receivings, POST /api/cane-receivings/:id/void (body field types) — แนะนำกำหนด API contract  
  \- ไม่มีเงื่อนไขการตรวจสอบการผูก Payment (how to detect paid) — จำเป็นสำหรับการอนุญาต Void  
\- หากต้องการเพิ่ม components ใหม่อื่น ๆ ที่ไม่อยู่ในไลบรารี ให้แจ้งเพื่อ append ไปยังชีต “New Component” (เราได้เพิ่ม \`QRCodeScanner\` แล้ว)

Global rules applied: ใช้เทมเพลตจาก ASCII Template Library เป็นหลัก; หากไม่มีแบบใกล้เคียง วาด ASCII ใหม่ (บันทึกใน Warnings: template\_source=custom).

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

\# Journey  
\#\#\# Journey: สร้างและยืนยันออกใบรับอ้อย (Actor: Receiving Staff / Supervisor)    
\*\*Entry:\*\* Receiving List (/agri/cane-receiving) → เลือกแถว Check-in หรือ Scan QR → เปิด Drawer \`/agri/cane-receiving/issue\`    
\*\*Preconditions:\*\* ผู้ใช้มีสิทธิ์สร้าง (Receiving Staff / Supervisor / Admin); มี checkin\_id ที่สถานะพร้อม (มี checkin snapshot); มี Authorization token    
\*\*Exit / Postconditions:\*\* สร้าง resource \`receiving\_id\` (status \= "Issued") \+ PDF ถูกสร้างหรือมี \`pdf\_url\`; ส่งอีเวนต์ cane\_receiving.issued; server เรียก side-effects: POST /api/weigh-coin/free และ PATCH /api/cbm/{booking\_id}/status → status \= "awaiting\_payment" (server-side). UI นำทางไปหน้า /agri/cane-receiving/:receiving\_id

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*ReceivingListPage / row → ออกใบรับอ้อย (open issue drawer)\*\* — ผู้ใช้คลิกปุ่ม “ออกใบรับอ้อย” ที่แถว    
   \- Trigger: NAV → open \`/agri/cane-receiving/issue?checkin\_id={checkin\_id}\`    
   \- map\_in: { checkin\_id }    
   \- assert: row.checkin\_id present; user has create permission (client guard)    
   \- System: client navigates/open Drawer; focus ไปที่ Drawer header (focus-trap)    
   \- map\_out: client will call GET /api/checkins/{checkin\_id} to prefill    
   \- UI Feedback: Drawer เปิด, skeleton/loading ในส่วน snapshot (aria-live polite)    
   \- Navigation/State: open \`/agri/cane-receiving/issue\` (drawer)    
   \- Field & Copy Checklist (เมื่อเปิด Drawer ต้องแสดง):    
     \- Fields ที่ต้องแสดง:    
       \- checkin\_id | "รหัส Check-in" | visibility(read-only) | source(api/checkin snapshot)    
       \- booking\_type | "ประเภทการจอง" | visibility(read-only) | source(api/checkin snapshot)    
       \- booking\_id | "รหัส Booking" | visibility(read-only) | source(api/checkin snapshot)    
       \- weigh\_coin | "เลขเหรียญชั่ง" | visibility(read-only) | source(api/checkin snapshot)    
       \- checkin\_time | "เวลา Check-in" | visibility(read-only) | source(api/checkin snapshot)    
       \- farmer\_name | "ชื่อเกษตรกร" | visibility(read-only) | source(api/checkin snapshot)    
       \- driver\_name | "ชื่อคนขับ" | visibility(read-only) | source(api/checkin snapshot)    
       \- driver\_phone | "เบอร์คนขับ" | visibility(read-only, masked in list) | source(api/checkin snapshot)    
     \- UI Copy / Messages: header "ออกใบรับอ้อย — พรีวิว Check-in", helper\_text: "ดึงผลการเทจากโรงงานโดยอัตโนมัติ (แนะนำ) — หากไม่พบให้สลับเป็นโหมด Manual"    
     \- data-test-id ที่เกี่ยวข้อง: receiving-list-row-\<checkin\_id\> (TODO: เพิ่มใน page\_defs), btn-open-issue-drawer    
     \- a11y: focus order \= Drawer header → Dump Result section → Primary confirm; hotkeys: Alt+C เปิด issue (global); Esc ปิด Drawer  
2\) \*\*ReceivingIssueDrawer / onOpen → GET /api/checkins/{checkin\_id}\*\* — prefill snapshot    
   \- Trigger: \`\<GET /api/checkins/{checkin\_id}\>\`    
   \- map\_in: { checkin\_id }    
   \- assert: Authorization header present    
   \- System: server returns snapshot fields (see API 8.9)    
   \- map\_out: snapshot used to populate visible fields (booking\_id, weigh\_coin, etc.)    
   \- UI Feedback: skeleton → populate fields; if 404 → show inline error "ไม่พบ Check-in นี้" และปิด Drawer / allow manual create? (variant)    
   \- Navigation/State: Drawer stays open; client ready to call factory dump fetch    
   \- Field & Copy Checklist: (same as step 1); data-test-id: checkin-snapshot-card, checkin-snapshot-weigh-coin  
3\) \*\*ReceivingIssueDrawer / ดึงผลการเท (Auto)\*\* — ผู้ใช้กดปุ่ม “ดึงผลการเท (Auto)” หรือระบบแนะนำ auto เมื่อ dump\_fetch\_mode default \= auto (UI shows CTA)    
   \- Trigger: \`\<GET /ext/factory/dump\>\`    
   \- map\_in: { quota\_id? (from snapshot if present), date: checkin\_date (ISO), weigh\_coin }    
     \- Note: ห้ามส่ง server-owned values (ccs/net\_weight\_kg) — factory only needs keys per API    
   \- assert: weigh\_coin present; date present; Authorization (or integration token)    
   \- System: ext factory returns FactoryDumpResult (ccs, net\_weight\_kg, fetched\_at, fetch\_status) or error (not\_found/mismatch)    
   \- map\_out: if success → { quota\_id, checkin\_date, weigh\_coin, ccs, net\_weight\_kg, fetched\_at, fetch\_status="success" } bound to Drawer state    
   \- UI Feedback: spinner on Dump Result card; on success show success banner "ดึงผลการเทสำเร็จ" and lock ccs/net\_weight inputs (read-only); on error show inline error Thai "ไม่พบผลการเทจากโรงงาน — เปลี่ยนเป็นโหมด Manual" with action "สลับเป็น Manual"    
   \- Navigation/State: dump\_fetch\_mode set to "auto" (locked) on success; if success, mark autoFetchSucceeded=true in client state    
   \- Field & Copy Checklist:    
     \- Fields ที่ต้องแสดง: dump\_fetch\_mode | "โหมดการดึงผล" | read-only if success | source(api/factory)    
     \- ccs | "CCS" | type decimal(5,2) | required(when manual) | read-only (when auto success) | compute\_rule: from factory response when auto    
     \- net\_weight\_kg | "น้ำหนักสุทธิ (กก.)" | decimal(10,2) | required(when manual) | read-only (when auto success) | compute\_rule: from factory response when auto    
     \- UI Copy: auto success message; auto fail message: "ไม่พบข้อมูลผลการเทจากโรงงาน — กรุณากรอกข้อมูลด้วยตนเอง"    
     \- data-test-id: btn-dump-fetch-auto, dump-result-ccs, dump-result-net-weight, dump-fetch-error  
     \- a11y: after fetch success, focus moves to Primary Confirm; aria-live region for fetch status  
4\) \*\*(Auto success) ReceivingIssueDrawer / ยืนยันออกใบรับอ้อย\*\* — ผู้ใช้กด “ยืนยันออกใบรับอ้อย” (Ctrl+Enter hotkey supported)    
   \- Trigger: \`\<POST /api/cane-receivings\>\` (idempotent)    
   \- map\_in: { checkin\_id, source\_type (from snapshot), source\_ref (booking\_id), weigh\_coin, dump\_fetch\_mode:"auto", ccs (from factory), net\_weight\_kg (from factory), issuing\_by: user.id }    
     \- Note: ห้ามส่ง server-derived aggregates beyond these fields    
   \- assert: client ensures X-Idempotency-Key generated per pattern (see Idempotency below); role allowed; required fields present; if dump\_fetch\_mode=auto then ccs/net\_weight present (bound from factory)    
   \- System: server validates; creates resource (201) and returns receiving\_id, status="Issued", issued\_at, issued\_by, pdf\_url; server triggers side-effects: POST /api/weigh-coin/free { weigh\_coin } and PATCH /api/cbm/{booking\_id}/status { status:"awaiting\_payment" } and emits cane\_receiving.issued; server may also trigger PDF generation (may already return pdf\_url)    
   \- map\_out: response { receiving\_id, status, issued\_at, issued\_by, pdf\_url } — client uses receiving\_id to navigate and PDF url to preview    
   \- UI Feedback: disable confirm button while request in-flight; show progress toast "กำลังออกใบรับอ้อย..."; on success toast "ออกใบรับอ้อยเรียบร้อย" and navigate to Detail; on 422 show field errors inline; on 409/412 show conflict dialog (see variants)    
   \- Navigation/State: navigate to \`/agri/cane-receiving/{receiving\_id}\`; invalidate list cache; emit telemetry release.submitted    
   \- Field & Copy Checklist (on confirm):    
     \- Fields ที่ต้องกรอก (client): none new; issuing\_by auto from session (show read-only)    
     \- Fields ที่ต้องแสดง: receiving\_id | "รหัสใบรับอ้อย" | read-only | source(api/response) ; pdf\_url | "PDF" | read-only | source(api/response)    
     \- UI Copy / Messages: Confirm CTA label "ยืนยันออกใบรับอ้อย" helper\_text under CTA: "การยืนยันจะสร้าง PDF และปลดเลขเหรียญชั่ง (weigh coin) พร้อมอัพเดตสถานะ CBM"    
     \- data-test-id: btn-confirm-issue, issue-inflight-toast, issue-success-toast    
     \- a11y: primary action aria-label "ยืนยันออกใบรับอ้อย"; focus moves to success toast then to Detail page header

\#\#\#\#\# Idempotency (required)  
\- X-Idempotency-Key header: pattern recommended: ui:{user.id}:{checkin\_id}:{hash(ccs|net\_weight\_kg|weigh\_coin)}    
\- On CONFLICT (409) from create: retry with the \*same\* idempotency key only; on success server returns existing resource.

\#\#\#\# Variants & Exceptions  
\- Step 3 → FACTORY\_RESULT\_NOT\_FOUND / FACTORY\_RESULT\_MISMATCH: show inline error, set dump\_fetch\_mode=manual and enable ccs/net\_weight inputs. Telemetry: release.dump\_fetch\_failed.  
\- Step 4 → 422 CCS\_OR\_WEIGHT\_INVALID: show inline field error near ccs/net\_weight (text: "กรุณากรอก CCS ให้มี 2 ตำแหน่งทศนิยม" / "กรุณากรอกน้ำหนักสุทธิเป็นจำนวนไม่ลบและ 2 ตำแหน่ง") and focus that field.  
\- Step 4 → 409 COIN\_ALREADY\_FREED: show error banner "เลขเหรียญชั่งถูกปลดไปแล้ว" with details; offer View Receiving (if server returned receiving\_id) or contact ops.  
\- Step 4 → 409 CBM\_STATUS\_CONFLICT: show banner "ไม่สามารถอัพเดตสถานะ CBM ได้ (การตั้งค่าสำหรับ Booking ขัดกัน) — กรุณาตรวจสอบหรือแจ้งฝ่ายปฏิบัติการ" and present CTA "ลองใหม่" / "ข้ามการอัพเดต CBM" (server compensation TBD).  
\- Step 4 → 412 Precondition (ETag mismatch) is not expected on create but handle as generic conflict: fetch latest checkin then retry.  
\- Dependency/IO/Timeout when calling ext/factory/dump: client should retry ext call up to 3 times (exponential backoff) then present manual fallback.

\#\#\#\# Telemetry & Audit  
\- Events:    
  \- release.dump\_fetch\_attempt { user\_id, checkin\_id, weigh\_coin, outcome: success|failure, fetch\_status }    
  \- release.submitted { user\_id, checkin\_id, receiving\_id, dump\_fetch\_mode, ccs, net\_weight\_kg, idempotency\_key }    
\- Audit fields for server events: actor\_id, correlation\_id (X-Trace-Id), idempotency\_key, receiving\_id, booking\_id, ccs, net\_weight\_kg, dump\_fetch\_mode

\#\#\#\# Test Hooks  
\- data-test-id to assert on steps: receiving-list-row-\<checkin\_id\>, btn-open-issue-drawer, checkin-snapshot-card, btn-dump-fetch-auto, dump-result-ccs, dump-result-net-weight, btn-confirm-issue, issue-success-toast, pdf-preview-frame, btn-open-original (see Doc viewing)    
  \- TODO: page\_defs\_md ไม่มีรายการ data-test-id เหล่านี้ — ดู TODOs ด้านล่าง    
\- Acceptance (Gherkin ย่อ):    
  \- Given authenticated Receiving Staff and a Check-in with weigh\_coin and booking\_id    
  \- When user opens Issue Drawer and "ดึงผลการเท (Auto)" สำเร็จ and user confirms issue    
  \- Then a receiving is created (status Issued), PDF generated, weigh-coin freed, CBM patched to awaiting\_payment and user is navigated to receiving detail

\#\#\#\# Assumptions & Confidence  
\- สมมติฐาน: 외부 factory API returns authoritative ccs/net\_weight and server will perform side-effects reliably. Confidence: High for happy path; Medium for side-effect error handling (compensation missing).

\---

\#\#\# Journey: สร้างและยืนยันออกใบรับอ้อย (Auto fail → Manual) (Actor: Receiving Staff / Supervisor)    
\*\*Entry:\*\* Same as Journey 1 but factory \`ext/factory/dump\` fails or returns not\_found/mismatch    
\*\*Preconditions:\*\* user has create permission; checkin snapshot present    
\*\*Exit / Postconditions:\*\* receiving created with dump\_fetch\_mode="manual" and ccs/net\_weight provided by user; server side-effects same as Journey 1\.

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) Steps 1–2 identical to Journey 1 (open Drawer and GET /api/checkins/{id}) — data-test-ids: checkin-snapshot-card, btn-dump-fetch-auto  
2\) \*\*ReceivingIssueDrawer / ดึงผลการเท (Auto) → FAIL\*\*    
   \- Trigger: \`\<GET /ext/factory/dump\>\`    
   \- map\_in: { quota\_id?, date, weigh\_coin }    
   \- assert: weigh\_coin present    
   \- System: factory returns error code factory\_result\_not\_found or factory\_result\_mismatch or 5xx after retries    
   \- map\_out: client receives error; set dump\_fetch\_mode to "manual" (client state)    
   \- UI Feedback: inline error "ไม่พบผลการเทจากโรงงาน — กรุณากรอกข้อมูลด้วยตนเอง" \+ show Manual editable fields; focus set to ccs input    
   \- Field & Copy Checklist:    
     \- ccs | "CCS" | decimal(5,2) | required(yes) | helper\_text: "กรอก 2 ตำแหน่งทศนิยม" | validators: regex /^\\d+(\\.\\d{1,2})?$/ ; error\_copy: "กรุณากรอก CCS ให้มี 2 ตำแหน่งทศนิยม" | visibility(editable)    
     \- net\_weight\_kg | "น้ำหนักสุทธิ (กก.)" | decimal(10,2) | required(yes) | helper\_text: "น้ำหนักสุทธิเป็นกิโลกรัม" | validators: \>=0 and regex for 2 decimals | visibility(editable)    
     \- dump\_fetch\_mode | "โหมดการดึงผล" | visibility(read-only: manual) | source(client)    
     \- data-test-id: btn-dump-manual-toggle, input-manual-ccs, input-manual-net-weight  
3\) \*\*ReceivingIssueDrawer / ผู้ใช้กรอก Manual values → ยืนยันออกใบรับอ้อย\*\*    
   \- Trigger: \`\<POST /api/cane-receivings\>\` with X-Idempotency-Key    
   \- map\_in: { checkin\_id, source\_type, source\_ref, weigh\_coin, dump\_fetch\_mode:"manual", ccs(user input), net\_weight\_kg(user input), issuing\_by }    
   \- assert: client validates ccs/net\_weight format; X-Idempotency-Key set; role allowed    
   \- System: server creates receiving and triggers side-effects (weigh-coin free, PATCH CBM) and returns pdf\_url & receiving\_id    
   \- map\_out: response used to navigate to Detail; show pdf preview if present    
   \- UI Feedback: loading spinner on confirm; show field errors if 422; on success navigate to detail and show success toast    
   \- Navigation/State: navigate to /agri/cane-receiving/:receiving\_id    
   \- Field & Copy Checklist: same as Journey 1 confirm section    
   \- data-test-id: btn-confirm-issue, issue-manual-ccs-error

\#\#\#\# Variants & Exceptions  
\- Validation error (422): show inline errors for ccs / net\_weight\_kg; focus to first invalid field    
\- 409 coin\_already\_freed: show banner and provide link to existing receiving resource if server returned it    
\- 409 cbm\_status\_conflict: show instructions to contact ops and optionally retry

\#\#\#\# Telemetry & Audit  
\- Events: release.dump\_fetch\_failed, release.submitted.manual { user\_id, checkin\_id, ccs, net\_weight\_kg, idempotency\_key }

\#\#\#\# Test Hooks  
\- data-test-id: btn-dump-manual-toggle, input-manual-ccs, input-manual-net-weight, btn-confirm-issue    
\- Acceptance (Gherkin): Given factory dump not found → When user fills manual ccs/net\_weight and confirms → Then receiving created and CBM updated

\#\#\#\# Assumptions & Confidence  
\- สมมติฐาน: Manual input trusted by system; confidence Medium (manual input more error-prone).

\---

\#\#\# Journey: Approve Release (DOA) (Actor: Supervisor)    
\*\*Entry:\*\* Receiving Detail or Approval Inbox (notification)    
\*\*Preconditions:\*\* Page definitions & APIs for approval not provided; role Supervisor with approval permission required    
\*\*Exit / Postconditions:\*\* (Desired) status changes to approved/finalized; events emitted. CURRENTLY API MISSING — see TODOs.

\#\#\#\# Happy Path — ขั้นตอนละเอียด (Speculative / API MISSING)  
1\) \*\*ReceivingDetailPage / Approve button\*\* — ผู้ดูแลคลิก Approve    
   \- Trigger: DIALOG → show Approve Confirm modal (collect optional comment)    
   \- map\_in: { receiving\_id } (UI)    
   \- assert: user has approve permission; resource status appropriate (in\_process?)    
   \- System: EXPECTED: call \`\<POST /api/cane-receivings/{receiving\_id}/approve\>\` (API not present)    
   \- map\_out: expected: { receiving\_id, status:"approved", approved\_by, approved\_at }    
   \- UI Feedback: show success toast and update status badge    
   \- Field & Copy Checklist: modal with reason/comment (optional) — field\_id: approval\_comment | "หมายเหตุการอนุมัติ" | optional    
   \- data-test-id: btn-approve (TODO: API & data-test-id missing)    
   \- a11y: modal focus trap, confirm via Enter, Esc to cancel

\#\#\#\# Variants & Exceptions  
\- If approval API returns 409 (business conflict): show appropriate message    
\- If 412 ETag mismatch: prompt refresh

\#\#\#\# Telemetry & Audit  
\- Events (proposal): approval.actioned { user\_id, receiving\_id, action:approve, comment }    
\- Audit fields: actor\_id, correlation\_id, resource ids

\#\#\#\# Assumptions & Confidence  
\- สมมติฐาน: DOA flow required by business but not present in API list. Confidence Low — \*\*ต้องมี API เพิ่ม\*\*.

\---

\#\#\# Journey: Reject Release (DOA) (Actor: Supervisor)    
\*\*Entry:\*\* Receiving Detail / Approval Inbox    
\*\*Preconditions:\*\* Approval API missing    
\*\*Exit / Postconditions:\*\* (Desired) status set to rejected and possibly allow create new receiving; server emits event. API MISSING — see TODOs.

\#\#\#\# Happy Path — ขั้นตอนย่อ (Speculative)  
1\) Approve modal variant → Reject input reason required → CALL expected \`\<POST /api/cane-receivings/{id}/reject\>\` (API not present)    
   \- map\_in: { receiving\_id, reject\_reason }    
   \- assert: reason present (min length 5\)    
   \- System: expected server sets status \= "rejected" or other domain state; emit event    
   \- UI Feedback: toast "การปฏิเสธเสร็จสมบูรณ์" and navigate to Detail    
   \- data-test-id: btn-reject (TODO: missing)

\#\#\#\# Variants & Exceptions  
\- 409 if cannot reject due to payment linkage

\#\#\#\# Telemetry & Audit  
\- Event: approval.actioned { user\_id, receiving\_id, action:reject, reason }

\#\#\#\# Assumptions & Confidence  
\- Confidence Low; API missing — see TODOs.

\---

\#\#\# Journey: Finalize Release (Actor: Admin / Ops)    
\*\*Entry:\*\* Receiving Detail after approval OR internal process trigger    
\*\*Preconditions:\*\* Finalize API not in spec; server may have orchestration to finalize payment/settlement    
\*\*Exit / Postconditions:\*\* (Desired) status "released" or finalized; event emitted. API MISSING — see TODOs.

\#\#\#\# Happy Path — ขั้นตอนย่อ (Speculative)  
\- Expect a server-side endpoint \`\<POST /api/cane-receivings/{id}/finalize\>\` or orchestrator listening to approval.actioned. No client API currently specified. Mark TODO.

\#\#\#\# Assumptions & Confidence  
\- Low confidence; must add APIs or specify orchestrator triggers.

\---

\#\#\# Journey: ดูรายละเอียดใบรับอ้อย (View Release Detail) (Actor: Viewer / Receiving Staff / Supervisor)    
\*\*Entry:\*\* Receiving List → คลิกแถว “ดูเอกสาร” หรือ deeplink \`/agri/cane-receiving/:id\` (notification)    
\*\*Preconditions:\*\* Authorization token; resource exists (GET /api/cane-receivings/{id})    
\*\*Exit / Postconditions:\*\* Page shows full receiving detail; buttons for Print/PDF and (conditional) Void visible

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*ReceivingListPage / ดูเอกสาร → NAV to Detail\*\*    
   \- Trigger: NAV → \`/agri/cane-receiving/{receiving\_id}\`    
   \- map\_in: { receiving\_id }    
   \- assert: user has view permission    
   \- System: router navigates and client calls GET /api/cane-receivings/{receiving\_id}    
   \- map\_out: receiving detail payload (per API 8.2)    
   \- UI Feedback: skeleton → render detail; show status badge (use API \`status\` values exactly; map to Thai labels)    
   \- Navigation/State: URL \`/agri/cane-receiving/{receiving\_id}\`; set ETag from response into client store for If-Match when voiding    
   \- Field & Copy Checklist:    
     \- Fields to show (read-only): receiving\_id, source\_type, source\_ref, checkin\_id, checkin\_time, weigh\_coin, dump\_fetch\_mode, ccs, net\_weight\_kg, status (enum: draft|issued|void), issued\_at, issued\_by, voided\_at, voided\_by, void\_reason, pdf\_url, audit.created\_at, audit.created\_by, audit.etag    
     \- UI Copy: status mapping: draft→"ร่าง", issued→"ออกแล้ว", void→"ยกเลิก" (but keep enum usage internally)    
     \- data-test-id: receiving-detail-header, receiving-detail-ccs, receiving-detail-net-weight, btn-print-pdf, btn-void (conditional)    
     \- a11y: tab order header → action bar → content; status badge readable  
2\) \*\*ReceivingDetailPage / พิมพ์ (PDF)\*\* — ผู้ใช้คลิก “พิมพ์”    
   \- Trigger: \`\<POST /api/cane-receivings/{receiving\_id}/pdf\>\`    
   \- map\_in: {} (no body) \+ Authorization    
   \- assert: user authorized to print; receiving exists    
   \- System: server returns { pdf\_url } (may generate on the fly)    
   \- map\_out: { receiving\_id, pdf\_url } → client opens PDF viewer modal or initiates download    
   \- UI Feedback: show spinner on button; on success open PDF viewer with iframe; on error show inline error "ไม่สามารถสร้าง PDF ได้" and retry CTA    
   \- Navigation/State: open modal \`PDF Viewer\` (focus-trap)    
   \- Field & Copy Checklist: PDF Viewer must contain: iframe preview, button \`btn-open-original\` (open original link) with data-test-id btn-open-original, button download, close (Esc)    
   \- data-test-id: btn-print-pdf, pdf-viewer-iframe, btn-open-original, pdf-download  
   \- a11y: modal focus to Close; Esc closes; aria-label for \`Open original link\` \= "เปิดไฟล์ต้นฉบับในแท็บใหม่"

\#\#\#\# Variants & Exceptions  
\- GET detail → 404: show "ไม่พบใบรับอ้อยนี้" and button "กลับไปที่รายการ"    
\- POST pdf → server\_error (500): show "ไม่สามารถสร้าง PDF ได้ โปรดลองอีกครั้ง" with Retry; telemetry \`br.document\_failed\`    
\- PDF viewer must include fallback button "Open original link" (data-test-id: btn-open-original). If iframe blocked, instruct user to click Open original.

\#\#\#\# Telemetry & Audit  
\- Events: release.viewed { user\_id, receiving\_id } ; br.document\_requested { user\_id, receiving\_id, request\_type: "print" } ; br.document\_created { receiving\_id, pdf\_url, actor\_id }

\#\#\#\# Test Hooks  
\- data-test-id: receiving-detail-header, btn-print-pdf, pdf-viewer-iframe, btn-open-original, btn-void    
\- Acceptance (Gherkin): Given an issued receiving → When user opens detail and clicks print → Then POST /pdf is called and PDF viewer opens with btn-open-original visible

\#\#\#\# Assumptions & Confidence  
\- Assumption: GET detail returns ETag in header for If-Match usage; Confidence High.

\---

\#\#\# Journey: เอกสาร PDF — ดูและดาวน์โหลด (with fallback open-original) (Actor: Viewer / Receiving Staff)    
\*\*Entry:\*\* Receiving Detail → คลิก “พิมพ์/ดาวน์โหลด” หรือ Issue Drawer Preview “PDF Preview” tab    
\*\*Preconditions:\*\* pdf\_url available or server can generate via POST /pdf; Authorization    
\*\*Exit / Postconditions:\*\* PDF viewer opens; user can download; click “Open original link” opens object storage link in new tab.

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Detail / Print → POST /api/cane-receivings/{id}/pdf\*\* (same as previous)    
   \- Trigger: \`\<POST /api/cane-receivings/{id}/pdf\>\`    
   \- map\_in: {}    
   \- assert: auth; receiving exists    
   \- System: server returns pdf\_url    
   \- map\_out: { pdf\_url }    
   \- UI Feedback: show loader; open PDF viewer modal (iframe) with src \= pdf\_url; show download button    
   \- Navigation/State: modal open; focus to Close    
   \- Field & Copy Checklist: viewer must show: iframe (pdf-viewer-iframe), button download (pdf-download), button open original (btn-open-original) — label Thai: "เปิดไฟล์ต้นฉบับ"    
   \- data-test-id: btn-print-pdf, pdf-viewer-iframe, pdf-download, btn-open-original    
   \- a11y: aria-describedby for download, Esc closes modal

\#\#\#\# Variants & Exceptions  
\- iframe blocked or CORS error → show error banner and visible \`btn-open-original\` with link to pdf\_url; data-test-id btn-open-original must exist and be visible always as fallback per Hard Constraints    
\- POST /pdf → server\_error → show retry CTA; retry uses same request (no idempotency key required) with exponential backoff 2 retries

\#\#\#\# Telemetry & Audit  
\- Events: br.document\_requested, br.document\_created (with pdf\_url)

\#\#\#\# Test Hooks  
\- data-test-id list as above

\#\#\#\# Assumptions & Confidence  
\- Server stores pdf\_url durable; Confidence High for viewer; ensure fallback button present.

\---

\#\#\# Journey: Export List (CSV) (Actor: Viewer with export permission / Admin)    
\*\*Entry:\*\* Receiving List → click Export CSV    
\*\*Preconditions:\*\* User has export permission (RBAC); filters applied; Authorization    
\*\*Exit / Postconditions:\*\* Browser downloads CSV synchronously (200 text/csv) for the filtered page results; Telemetry emitted export.csv\_requested

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*ReceivingListPage / Export CSV\*\* — ผู้ใช้คลิกปุ่ม Export CSV    
   \- Trigger: \`\<GET /api/cane-receivings/export\>\` (EXPORT)    
   \- map\_in: Query filters: q, date\_from, date\_to, source\_type, status, checkin\_id, weigh\_coin, page, page\_size, sort    
   \- assert: user has export permission (client hide/disable if not allowed)    
   \- System: server validates RBAC and returns CSV stream (text/csv) or 403 if forbidden    
   \- map\_out: CSV download initiated (filename e.g., cane\_receivings\_page1.csv)    
   \- UI Feedback: show spinner on export button; on success auto download; on 403 show toast "คุณไม่มีสิทธิ์ส่งออกข้อมูล"    
   \- Navigation/State: no navigation; client logs telemetry export.csv\_requested    
   \- Field & Copy Checklist: export respects visible columns and mask rules (e.g., mask driver\_phone in list responses)    
   \- data-test-id: btn-export-csv, export-download-link

\#\#\#\# Variants & Exceptions  
\- 403 forbidden: show modal "คุณไม่มีสิทธิ์ส่งออก" with contact ops CTA    
\- Large resultset: spec currently synchronous — if server responds 202 for async change UI to show job id and polling (TODO if change)

\#\#\#\# Telemetry & Audit  
\- Events: export.csv\_requested { user\_id, filters, page, page\_size }

\#\#\#\# Test Hooks  
\- data-test-id: btn-export-csv

\#\#\#\# Assumptions & Confidence  
\- Confidence High for synchronous small datasets; note server may need async changes for large exports.

\---

\#\#\# Journey: ยกเลิกใบรับอ้อย (Void Receiving) (Actor: Supervisor / Receiving Staff conditional)    
\*\*Entry:\*\* Receiving Detail (status \= Issued) → คลิก Void → Void Confirm Modal    
\*\*Preconditions:\*\* User has void permission; resource status \= Issued; client holds ETag from GET detail (If-Match required)    
\*\*Exit / Postconditions:\*\* POST /api/cane-receivings/{id}/void successful → server returns status="Void"; side-effect PATCH /api/cbm/{booking\_id}/status {status:"awaiting\_dump\_result"}; emit cane\_receiving.void; UI updates to status=Void

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*ReceivingDetailPage / Void → open Void Confirm Modal\*\*    
   \- Trigger: DIALOG → open Void modal    
   \- map\_in: receiving\_id, ETag (client stored)    
   \- assert: status \== "Issued"; role allowed; client has ETag; textarea void\_reason blank initially    
   \- System: modal opens; focus on textarea    
   \- map\_out: user enters void\_reason    
   \- UI Feedback: modal opened; hotkeys: Esc cancel; focus-trap active    
   \- Field & Copy Checklist:    
     \- void\_reason | "เหตุผลการยกเลิก" | textarea | required(yes) | validators: minLength=5 | data-test-id: input-void-reason    
     \- data-test-id: btn-open-void-modal  
2\) \*\*Void Confirm Modal / Confirm → POST /api/cane-receivings/{id}/void\*\*    
   \- Trigger: \`\<POST /api/cane-receivings/{receiving\_id}/void\>\`    
   \- map\_in: { void\_reason } \+ Headers: If-Match: "\<etag\>"    
   \- assert: void\_reason present; If-Match header present; user has permission    
   \- System: server validates, marks resource status="Void" and returns voided\_at/voided\_by; server calls PATCH /api/cbm/{booking\_id}/status {status:"awaiting\_dump\_result"}; emits cane\_receiving.void    
   \- map\_out: response contains receiving\_id, status:"Void", voided\_at, voided\_by, void\_reason    
   \- UI Feedback: disable Confirm while in-flight; on success close modal, update Detail page status badge to "ยกเลิก", show toast "ยกเลิกสำเร็จ"    
   \- Navigation/State: remain on Detail; invalidate caches; telemetry void.actioned    
   \- Field & Copy Checklist: show updated audit card with voided\_by/voided\_at/void\_reason; data-test-id: btn-void-confirm, void-success-toast    
   \- a11y: after success focus to status badge

\#\#\#\# Variants & Exceptions  
\- 412 Precondition Failed (ETag mismatch): show dialog "ข้อมูลไม่ทันสมัย กรุณารีเฟรช" with CTA "รีเฟรชข้อมูล" that triggers GET /api/cane-receivings/{id}; telemetry: void.precondition\_failed    
\- 409 VOID\_NOT\_ALLOWED: show banner "ไม่สามารถยกเลิกได้เนื่องจากใบนี้ถูกผูกกับการชำระเงิน" with contact ops CTA    
\- 403 unauthorized: show toast 403 and close modal

\#\#\#\# Telemetry & Audit  
\- Events: cane\_receiving.void { receiving\_id, actor\_id, void\_reason, correlation\_id }    
\- Audit fields: actor\_id, correlation\_id (X-Trace-Id), resource ids

\#\#\#\# Test Hooks  
\- data-test-id: btn-open-void-modal, input-void-reason, btn-void-confirm, void-success-toast    
\- Acceptance (Gherkin): Given an Issued receiving and valid ETag → When supervisor confirms void with reason → Then receiving becomes Void and CBM updated

\#\#\#\# Assumptions & Confidence  
\- Assumption: server will revert CBM status and not allow payment thereafter; Confidence High for API behavior; note compensation when PATCH CBM fails must be surfaced (server expected to handle).

\---

\#\#\# Journey: Bulk Cancel / Cancel Transaction (Actor: Supervisor / Admin)    
\*\*Entry:\*\* Receiving List with multi-select → click Bulk Cancel    
\*\*Preconditions:\*\* API for bulk void not present in spec; per-item void exists. User has bulk action permission.    
\*\*Exit / Postconditions:\*\* If bulk API implemented, multiple resources become Void and side-effects applied; otherwise UI should perform per-item void sequences with progress and report. See TODOs.

\#\#\#\# Happy Path — Proposed UI Behavior (no bulk API)  
1\) \*\*ReceivingListPage / select multiple rows → Bulk Actions → Cancel selected\*\*    
   \- Trigger: client-side bulk flow (client will iterate selected ids)    
   \- map\_in: list of receiving\_ids \+ for each: fetch ETag via GET /api/cane-receivings/{id}? (If-Match required)    
   \- assert: user has permission for each; selected rows are Eligible (status=Issued) — client must hide/disable rows that are not eligible per Row Action Guards    
   \- System: client opens Bulk Confirm Modal asking for common void\_reason (applies to all)    
   \- map\_out: on confirm, client sequentially calls POST /api/cane-receivings/{id}/void with respective If-Match headers for each id (one-by-one or batched)    
   \- UI Feedback: show progress UI (count succeeded/failed), per-item toasts, retry failed ones individually    
   \- Navigation/State: update table rows as responses come in; invalidate list cache    
   \- Field & Copy Checklist: bulk void\_reason textarea; data-test-id: bulk-void-modal, bulk-void-start, bulk-void-progress, bulk-void-result    
   \- a11y: progress region aria-live updating

\#\#\#\# Variants & Exceptions  
\- If many items, performing sequential void may be slow — recommend server-side bulk API \`\<POST /api/cane-receivings/bulk\_void\>\` (TODO) returning job id; current implementation fallback is per-item calls. If client-per-item fails due to ETag mismatch, mark as failed and present option to refresh that row and retry.

\#\#\#\# Telemetry & Audit  
\- Events: bulk.void\_initiated { user\_id, receiving\_ids } ; per-item cane\_receiving.void emitted by server

\#\#\#\# Test Hooks  
\- data-test-id: bulk-select-checkbox, btn-bulk-cancel, bulk-void-progress

\#\#\#\# Assumptions & Confidence  
\- Assumption: no bulk API; client must implement safe per-item calls with If-Match. Confidence Medium.

\---

\#\#\# Journey: Retry Document Generation (Actor: Receiving Staff / Viewer)    
\*\*Entry:\*\* Receiving Detail → previous PDF generation failed or PDF missing → user clicks Retry Generate PDF    
\*\*Preconditions:\*\* Authorization; receiving exists    
\*\*Exit / Postconditions:\*\* POST /api/cane-receivings/{id}/pdf called again; if success pdf\_url returned and viewer opens.

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*ReceivingDetailPage / คลิก Retry PDF\*\*    
   \- Trigger: \`\<POST /api/cane-receivings/{id}/pdf\>\` (re-issue)    
   \- map\_in: {}    
   \- assert: user has permission; request idempotent for doc generation? (use idempotency pattern for doc-gen)    
   \- System: server attempts to (re)generate PDF and returns pdf\_url    
   \- map\_out: pdf\_url used to open viewer; telemetry br.document\_created    
   \- UI Feedback: disable button while in-flight; on success open viewer and show success toast; on server\_error show retry option with backoff    
   \- Navigation/State: open PDF modal    
   \- Field & Copy Checklist: data-test-id: btn-pdf-retry, pdf-viewer-iframe, btn-open-original    
   \- Idempotency: use doc pattern key: X-Idempotency-Key \= ui:{user.id}:{receiving\_id}:doc

\#\#\#\# Variants & Exceptions  
\- 500 server\_error: show "การสร้าง PDF ล้มเหลว" and suggest retry; exponential backoff client side up to 2 retries

\#\#\#\# Telemetry & Audit  
\- Events: br.document\_retry { user\_id, receiving\_id, idempotency\_key }

\#\#\#\# Test Hooks  
\- data-test-id: btn-pdf-retry, pdf-download

\#\#\#\# Assumptions & Confidence  
\- Server-side handles idempotency for doc generation when key present. Confidence Medium.

\---

\#\#\# Journey: เปิดจาก Notification / Deeplink ไปที่ Detail (Actor: Viewer / Receiving Staff / Supervisor)    
\*\*Entry:\*\* Notification center / push notification contains link to \`/agri/cane-receiving/{receiving\_id}\` or QR scan resolves to receiving\_id and client navigates    
\*\*Preconditions:\*\* Notification link valid; user authenticated (or prompt to login); receiving exists    
\*\*Exit / Postconditions:\*\* Client navigates to Detail and fetches resource (GET /api/cane-receivings/{id})

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Notification Click → NAV to /agri/cane-receiving/{id}\*\*    
   \- Trigger: NAV (deeplink)    
   \- map\_in: { receiving\_id } via route param    
   \- assert: user has view permission; token valid or redirect to login preserving deeplink    
   \- System: client routers to Detail and calls GET /api/cane-receivings/{id}    
   \- map\_out: detail data (see API 8.2)    
   \- UI Feedback: loader then render; if unauthorized show login flow then redirect back    
   \- Navigation/State: route set; ETag stored for subsequent If-Match operations    
   \- Field & Copy Checklist: same as View Detail    
   \- data-test-id: notification-link-\<receiving\_id\>, receiving-detail-header

\#\#\#\# Variants & Exceptions  
\- Link references non-existent receiving → show 404 message and CTA back to list    
\- Token expired → redirect to login and after login navigate to deeplink

\#\#\#\# Telemetry & Audit  
\- Event: notification.opened { user\_id, receiving\_id, notification\_id }

\#\#\#\# Test Hooks  
\- data-test-id: notification-link-\<receiving\_id\>, receiving-detail-header

\#\#\#\# Assumptions & Confidence  
\- Confidence High.

\---

\#\# Variants & Exceptions — สรุปมาตรฐานการจัดการข้อผิดพลาด  
\- VALIDATION (422): inline field errors with focus to first invalid field; copy Thai: e.g., "กรุณากรอก CCS ให้มี 2 ตำแหน่งทศนิยม"    
\- BUSINESS (409): แสดง banner with human-friendly message and CTA; e.g., COIN\_ALREADY\_FREED → "เลขเหรียญถูกปลดแล้ว" \+ link to resource if available    
\- CONFLICT (412/ETag mismatch): show modal "ข้อมูลไม่ทันสมัย กรุณารีเฟรช" and provide refresh button; do not auto-retry without user consent    
\- DEPENDENCY/IO/TIMEOUT: for ext/factory/dump retry 3 attempts then present manual fallback; for POST /pdf retry 2 times with exponential backoff; for exports if 429 follow Retry-After header

\#\# Telemetry & Audit (cross-journey)  
\- Standard event names (dot-case):    
  \- release.dump\_fetch\_attempt (payload: user\_id, checkin\_id, weigh\_coin, outcome)    
  \- release.dump\_fetch\_failed (payload: user\_id, checkin\_id, error\_code)    
  \- release.submitted (payload: user\_id, checkin\_id, receiving\_id, dump\_fetch\_mode, ccs, net\_weight\_kg, idempotency\_key)    
  \- cane\_receiving.issued (server event)    
  \- cane\_receiving.void (server event)    
  \- br.document\_requested / br.document\_created / br.document\_failed    
  \- export.csv\_requested    
  \- notification.opened    
\- Audit Fields (must be captured): actor\_id, correlation\_id (X-Trace-Id), idempotency\_key, resource ids (receiving\_id, checkin\_id, booking\_id), ccs, net\_weight\_kg, dump\_fetch\_mode, pdf\_url, timestamps

\#\# Test Hooks (global)  
\- Every actionable step above lists at least one data-test-id. Where page\_defs\_md did not include explicit data-test-id values, items are marked TODO — see final TODOs.

\#\# Assumptions & Confidence (global)  
\- Assumptions: server emits events and carries out side-effects atomically or with compensations; GET detail includes ETag header; factory API accessible using given query params; weigh-coin unique and free operation idempotent. Confidence: Medium overall (some orchestration/compensation gaps exist).

\---

\#\# TODOs (สิ่งที่จำเป็นต้องเพิ่ม/ยืนยัน เนื่องจากข้อมูลไม่ครบและห้ามสร้างข้อมูลฝั่งเซิร์ฟเวอร์เอง)  
1\. เพิ่มรายการ data-test-id ใน Page Definitions (จำเป็นตาม Hard Constraint §12) — รายการตัวอย่างที่ต้องเพิ่ม:    
   \- receiving-list-row-\<checkin\_id\>    
   \- btn-open-issue-drawer    
   \- checkin-snapshot-card, checkin-snapshot-weigh-coin    
   \- btn-dump-fetch-auto, dump-result-ccs, dump-result-net-weight, dump-fetch-error, btn-dump-manual-toggle, input-manual-ccs, input-manual-net-weight    
   \- btn-confirm-issue, issue-inflight-toast, issue-success-toast    
   \- receiving-detail-header, receiving-detail-ccs, receiving-detail-net-weight, btn-print-pdf, pdf-viewer-iframe, btn-open-original, btn-void, btn-void-confirm, void-success-toast    
   \- btn-export-csv, export-download-link    
   \- bulk-select-checkbox, btn-bulk-cancel, bulk-void-modal, bulk-void-progress, bulk-void-result    
   \- btn-pdf-retry, pdf-download    
   (โปรดอัปเดต page\_defs\_md ให้มี mapping เหล่านี้ และยืนยันคอนเวนชันการตั้งชื่อ test-id)

2\. API MISSING — DOA / Approval / Finalize: ไม่มี endpoints สำหรับ Approve / Reject / Finalize ในรายการ API (required by Minimum Journeys \#2–\#4). ต้องออกแบบ/เพิ่ม API ต่อไปนี้ (backend required):    
   \- POST /api/cane-receivings/{receiving\_id}/approve { comment? } → returns status="approved" (or appropriate)    
   \- POST /api/cane-receivings/{receiving\_id}/reject { reason } → returns status="rejected"    
   \- POST /api/cane-receivings/{receiving\_id}/finalize → returns status="released" or similar    
   (ถ้าไม่ต้องการ approval flow ให้ยืนยันด้วยทีมผลิตภัณฑ์และเอาออกจากรายการ Journey)

3\. Bulk Void API missing (optional performance improvement): consider adding POST /api/cane-receivings/bulk\_void { receiving\_ids\[\], void\_reason } returning job\_id for async processing. ปัจจุบัน UI ต้องทำ per-item POST /{id}/void with If-Match.

4\. Payment linkage detection: ไม่มี API/ฟิลด์ที่ชัดเจนในสเปคเพื่อเช็คว่าใบรับอ้อยถูกผูกกับ Payment (เพื่อบล็อก Void). ต้องเพิ่มการระบุใน GET detail response เช่น \`linked\_payment: boolean\` หรือ endpoint ที่ตรวจสอบการผูกชำระ หากไม่มี server จะส่ง 409 VOID\_NOT\_ALLOWED เมื่อตรวจพบ — ขอระบุเงื่อนไขการตรวจจับนี้

5\. Compensation/rollback policy for side-effects: เมื่อ POST /api/cane-receivings สำเร็จ แต่ PATCH /api/cbm/... หรือ POST /api/weigh-coin/free ล้มเหลว — ไม่มีนโยบาย rollback ในสเปค (Warnings noted). ต้องออกแบบแนวทางการชดเชย (retry, compensation, alerting) และแสดง UX ที่ชัดเจนเมื่อ side-effect บางรายการล้มเหลว.

6\. QRCodeScanner component: Page Definitions ระบุ template\_source=custom และสร้าง component \`QRCodeScanner\` แต่ไม่มี implementation details (camera permission, constraints). ต้องกำหนด component spec (capabilities, platforms, fallback) และเพิ่มใน component library.

7\. ETag header guarantee: สเปค GET detail ตัวอย่างตอบมี audit.etag, แต่ต้องยืนยันว่า ETag ถูกส่งเป็น HTTP header \`ETag\` และใช้แบบ W/.. ตามตัวอย่าง เพื่อให้ If-Match ทำงานได้ถูกต้อง.

8\. pdf download behavior: ต้องยืนยันว่ POST /api/cane-receivings/{id}/pdf คืน \`pdf\_url\` accessible via browser (CORS) หรือ stream; ถ้าใช้ออบเจ็กต์สตอเรจที่มี Signed URL ต้องให้ client ใช้ \`btn-open-original\` as fallback.

9\. Idempotency key patterns — ให้ทีม backend confirm support for recommended keys:    
   \- Create/Submit: ui:{user.id}:{checkin\_id}:{hash(ccs|net\_weight\_kg|weigh\_coin)}    
   \- Doc-Gen: ui:{user.id}:{receiving\_id}:doc    
   \- If backend imposes different collision semantics โปรดระบุ

10\. Add server error messages localization mapping (error.code → Thai user-facing copy) for 409/412/422/500 so frontend can show correct Thai messages (some guidance provided but mapping file needed).

11\. Test data / CSV export header spec: export CSV needs header names & field formats (masking rules for phone/account). Add CSV schema in API docs.

12\. Void permission matrix detail: Page Definitions mention RBAC matrix (A2) but actual mapping which roles can Void/Approve/Create needs to be confirmed and codified in API RBAC docs.

13\. Events/webhook payload schemas: define canonical payloads for cane\_receiving.issued and cane\_receiving.void (fields to include) for downstream consumers.

14\. Add data-test-id btn-open-original into PDF viewer per Hard Constraint §7.

15\. Ensure server emits X-Trace-Id echo in responses for tracing (recommended) — confirm header behavior.

If any TODO above cannot be resolved by frontend team, coordinate with backend/Product/Ops to close gaps before implementation.

\--- End of Journey Definitions.

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

\# 11\. Business Rules

\#\#\# 11.1 Rules Inventory (merged)  
| Rule ID | Type (validation/domain) | Context (entity/endpoint) | State/Trigger | Condition | Expected | Error Code | Ref(A5/A6/A3) | Notes |  
|---|---|---|---|---|---|---|---|---|  
| R1 | validation | POST \`/api/cane-receivings\` | Draft→Issued | dump\_fetch\_mode=manual AND ccs missing | reject | CCS\_OR\_WEIGHT\_INVALID | A5 §8.3; A6 §10.0.2 | manual ccs ต้องส่ง |  
| R2 | validation | POST \`/api/cane-receivings\` | Draft→Issued | dump\_fetch\_mode=manual AND net\_weight\_kg missing | reject | CCS\_OR\_WEIGHT\_INVALID | A5 §8.3; A6 §10.0.2 | manual weight ต้องส่ง |  
| R3 | validation | POST \`/api/cane-receivings\` | Draft→Issued | ccs NOT numeric(5,2) OR \< 0 | reject | CCS\_OR\_WEIGHT\_INVALID | A6 §10.0.2; A5 §8.3 | 2 ตำแหน่งทศนิยม |  
| R4 | validation | POST \`/api/cane-receivings\` | Draft→Issued | net\_weight\_kg NOT numeric(10,2) OR \< 0 | reject | CCS\_OR\_WEIGHT\_INVALID | A6 §10.0.2; A5 §8.3 | 2 ตำแหน่งทศนิยม |  
| R5 | domain | POST \`/api/cane-receivings\` | Draft→Issued | dump\_fetch\_mode=auto AND ext/factory/dump fetch\_status=\`not\_found\` | reject | FACTORY\_RESULT\_NOT\_FOUND | A5 §8.8; A3 §5.2 | auto fail → switch to manual |  
| R6 | domain | POST \`/api/cane-receivings\` | Draft→Issued | dump\_fetch\_mode=auto AND ext/factory/dump fetch\_status=\`mismatch\` | reject | FACTORY\_RESULT\_MISMATCH | A5 §8.8; A3 §5.2 | lookup key mismatch |  
| R7 | validation | POST \`/api/cane-receivings\` | create request | missing \`X-Idempotency-Key\` header | reject | — | A5 §9.1; A3 §5.2.2 | header required by API; gap in error code |  
| R8 | validation | POST \`/api/cane-receivings\` | idempotent retry | same X-Idempotency-Key \+ equivalent payload | accept | — | A5 §8.3; A5 §9.4 | server must return same resource |  
| R9 | validation | POST \`/api/cane-receivings\` | path param | receiving\_id NOT match \`^CRN-\\d{4}-\\d{5}$\` | reject | VALIDATION\_ERROR | A6 §10.4; A5 §8.3 | public id pattern enforced |  
| R10 | domain | POST \`/api/cane-receivings/{id}/void\` | Issued→Void | missing OR mismatched \`If-Match\` ETag | reject | PRECONDITION\_FAILED | A3 §5.2.2; A5 §9.4 | ETag required for concurrency |  
| R11 | domain | POST \`/api/cane-receivings/{id}/void\` | Issued→Void | document linked to Payment detected | reject | VOID\_NOT\_ALLOWED | A5 §8.4; A3 §5.2 | payment linkage precondition |  
| R12 | domain | POST \`/api/cane-receivings\` | Draft→Issued | POST side-effect PATCH /api/cbm returns 409 | reject | CBM\_STATUS\_CONFLICT | A5 §8.10; A3 §5.2 | downstream CBM conflict |  
| R13 | domain | POST \`/api/cane-receivings\` | Draft→Issued | POST side-effect POST /api/weigh-coin/free returns 409 | reject | COIN\_ALREADY\_FREED | A5 §8.11; A3 §5.2 | coin already freed |  
| R14 | domain | GET \`/api/cane-receivings\` | list/filter | query param date\_from/ISO malformed | reject | INVALID\_QUERY | A5 §8.1; A5 §9.2 | query shape validation |  
| R15 | domain | GET \`/api/cane-receivings\` | list rendering | deleted\_at IS NOT NULL OR status='Void' (list view) | reject | — | A6 §10.0.2; A3 §5.2.3 | list excludes soft-deleted/void |  
| R16 | validation | POST \`/api/cane-receivings\` | Draft→Issued | checkin\_id not resolvable via \`GET /api/checkins/{checkin\_id}\` | reject | not\_found | A5 §8.9; A3 §5.2 | checkin must exist |  
| R17 | domain | POST \`/api/cane-receivings\` | Draft→Issued | server-side receiving \`id\` collision on create | reject | CONFLICT | A6 §10.2; A5 §9.2 | public id unique constraint |  
| R18 | validation | POST \`/api/scan/resolve\` | scan resolve | QR payload cannot be resolved | reject | not\_found | A5 §8.7 | scanner resolution failure |  
| R19 | validation | POST \`/api/cane-receivings/{id}/pdf\` | pdf generate | PDF generation failed | reject | server\_error | A5 §8.5 | server PDF error surfaced |  
| R20 | validation | GET \`/api/cane-receivings/{id}\` | detail read | If-None-Match matches current ETag → no body | accept | — | A5 §8.2; A5 §9.4 | supports conditional GET |

\#\#\# 11.2 State→Action Guard Matrix (compact)  
State | Allowed | Blocked | Preconditions | Error Code  
\---|---|---|---|---  
Draft | create (POST /api/cane-receivings)\<br\>dump:fetch\_auto\<br\>dump:toggle\_manual | update after Issue\<br\>void (not applicable) | checkin exists\<br\>if manual ccs/net\_weight\_kg valid | CCS\_OR\_WEIGHT\_INVALID / INVALID\_QUERY  
Issued | view:detail\<br\>pdf:generate\<br\>void (POST /api/cane-receivings/{id}/void) | create (new in-place)\<br\>edit fields directly | \`If-Match\` supplied AND ETag matches\<br\>NOT linked to Payment | PRECONDITION\_FAILED / VOID\_NOT\_ALLOWED  
Void | view:detail\<br\>pdf:generate | void again\<br\>issue from Void | none (read-only) | CONFLICT  
(implicit) deleted\_at NOT NULL | none | list/detail visibility | soft-delete applied | —  
Any | export:csv | export when RBAC denied | user has export permission | forbidden / CONFLICT

\#\#\# 11.3 Soft-Delete & Retention (concise)  
\- List behavior: exclude rows where deleted\_at IS NOT NULL and exclude status='Void' from default Receiving List.    
\- Detail behavior: Receiving Detail may show status='Void' (per Page Definitions) unless deleted\_at IS NOT NULL.    
\- Restore: not defined in inputs; if implemented require \`If-Match\` and audit fields; use \`X-Idempotency-Key\` for retriable restore.    
\- \[Default\] exclude by default; restorable if not purged.

\#\#\# 11.4 Compensation & Recovery (P0 only)  
Scenario | Preconditions | Action | Resulting State/Data | Idempotency/ETag | Observability  
\---|---|---|---|---|---  
Issue partial failure (PDF OK, CBM PATCH fail) | receiving row created; PDF stored; CBM PATCH 5xx/409 | retry CBM PATCH; if permanent fail emit alert \+ mark orchestration failure | receiving.status may remain Issued OR marked \`issue\_failed\` flag | X-Idempotency-Key used to avoid duplicate create | event log \+ alert; trace via X-Trace-Id  
Side-effect coin free 409 COIN\_ALREADY\_FREED | POST weigh-coin/free returned 409 | surface error; reconcile coin state; avoid retry unless idempotent | receiving may rollback or require manual reconciliation | X-Idempotency-Key for original Issue | audit \+ operator ticket  
ETag mismatch on void (If-Match stale) | client supplied If-Match not equal server ETag | reject with 412; client must GET latest and retry | no state change | require fresh If-Match on retry | trace\_id in error response  
Duplicate POST create (retries) | same X-Idempotency-Key | server returns existing resource instead of duplicate | single receiving resource persisted | X-Idempotency-Key ensures idempotent behavior | audit log shows idempotency key mapping  
Event webhook fail / consumer DLQ | cane\_receiving.issued emitted but webhook delivery fails | retry with backoff; if permanent move to DLQ | event persisted; downstream may be eventually consistent | events identified by receiving\_id, idempotent handlers | monitoring \+ DLQ metrics

\#\#\# 11.5 Findings & Follow-ups  
\- Gap: no explicit named code for missing \`X-Idempotency-Key\` — Owner: API team (A5 §9.1).    
\- Gap: \`VALIDATION\_ERROR\`/\`CONFLICT\` token mapping not consistently listed in A5 — Owner: API team (A5 §9.2).    
\- Gap: export oversize handling / \`TOO\_LARGE\_EXPORT\` not defined — Owner: Backend/Reporting (A5 §8.6).    
\- Gap: explicit API/flag to verify Payment linkage for Void missing — Owner: Payments team (A3 §5.2 warning).    
\- Gap: event/webhook contract (schema, retries) not specified — Owner: Integrations team (A3 §5.2; A5 notes).    
\- Conflict: DB timestamp storage vs presentation TZ — follow A6 (store timestamptz UTC); note mapping to Asia/Bangkok in UI — Owner: Data team (A6 §10.5).    
\- Conflict: canonical \`status\` casing enforced in DB; ensure API normalizes inputs — Owner: API team (A6 §10.4; A3 §5.1).    
\- Follow-up: clarify Supervisor vs Receiving Staff granularity for Void rights — Owner: Security/RBAC (A3 Warnings).