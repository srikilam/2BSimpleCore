\# 1\. Feature Overview  
\- Feature Id : feat\_cane\_checkin\_20251112000000  
\- Feature Name : เช็คอินรถส่งอ้อย  
\- Module : โลจิสติกส์อ้อย / ประตูโรงงาน  
\- Base Path : /cane/check-in  
\- Menu Trail : การจัดการอ้อย → เช็คอิน

\---

\# 2\. Objective & Background

\#\# 2.1 Objectives  
\- เปิดใช้งานการเช็คอินรถส่งอ้อยที่หน้าประตูโรงงานใน 3 โหมด: CBM, member\_no\_booking, guest\_pool โดยผู้ปฏิบัติงานสามารถทำรายการผ่านหน้า List/Modal/Drawer ได้  
\- บันทึก coin\_number และบล็อกการใช้ coin\_number ซ้ำในรายการที่ยังไม่จบ (partial-unique) เพื่อป้องกันเลขเหรียญซ้ำ  
\- รองรับการกำหนด payment\_type\_1st/payment\_type\_2nd และ debt\_payment\_percent (สำหรับ member\_no\_booking) ให้ครบถ้วนก่อนบันทึก  
\- เมื่อเช็คอินแบบ CBM ให้ส่ง PATCH ไปยัง /api/cbm/bookings/{cbm\_id}/status เพื่อเปลี่ยน phase\_cut\_transport เป็น "awaiting\_payment" และอัพเดต checkin.status เป็น awaiting\_payment/checked\_in ตามกรณี  
\- ส่งอีเวนต์บน EventBus: cane.checkin.created เมื่อสร้างเช็คอินสำเร็จ และ cane.checkin.voided เมื่อ void สำเร็จ พร้อมรักษา RBAC และ audit trail

\#\# 2.2 Business Context  
\- Current pain: ประตูโรงงานต้องรองรับทั้งกรณีมีคิวจากระบบ CBM และกรณีไม่มีคิว แต่ปัจจุบันการเช็คอินยังไม่รองรับทุกโหมดอย่างครบถ้วน/ปลอดภัย (เช่น coin\_number ซ้ำ, ข้อมูล payment ไม่ครบ)  
\- Why now: ต้องการลดความล่าช้าและข้อผิดพลาดที่เกิดจากการจัดการคิว/เช็คอินด้วยมือ และผสานการเปลี่ยนสถานะจาก CBM ไปยังกระบวนการชำระเงินโดยอัตโนมัติ  
\- Desired future state: หน้าปฏิบัติงานสามารถเช็คอินได้รวดเร็วและปลอดภัยในทุกโหมด, ป้องกัน coin\_number ซ้ำ, ข้อมูล payment ครบถ้วนสำหรับระบบ Payment, และระบบ CBM ได้รับการอัปเดตสถานะอัตโนมัติเมื่อเป็นกรณี CBM  
\- Journey หลัก (สรุป):   
  \- Journey A: List \[ต้องส่ง\] → เลือก CBM → Check-In (prefill readonly) → ยืนยัน → PATCH CBM เป็น awaiting\_payment → แสดงใน \[เช็คอินแล้ว\]  
  \- Journey B: List → Check-In → เลือก ไม่มีคิว (สมาชิก) → เลือก quota \+ กำหนด payment/debt\_pct → ยืนยัน → สร้าง checkin source\_type=member\_no\_booking → แสดงใน \[เช็คอินแล้ว\]  
  \- Journey C: List → Check-In → เลือก โควต้ากลาง → กรอกข้อมูล \+ payment → ยืนยัน → สร้าง checkin source\_type=guest\_pool (guest\_flag=true)

\#\# 2.3 Success Metrics (KPIs)  
\- KPI: เวลาตอบสนองเช็คอิน ≤ 30 วินาที สำหรับ ≥ 95% ของการทำรายการ (จากการเริ่มทำรายการถึงสถานะ awaiting\_payment)  
\- KPI: อัตราการเกิด coin\_number ซ้ำ \= 0 (zero duplicates for active/non-completed records)  
\- KPI: ความครบถ้วนของ payment\_type\_1st/2nd ใน no-booking \= 100%  
\- KPI: ความครบถ้วนของ debt\_payment\_percent ใน member\_no\_booking \= 100%  
\- KPI: อัตราการใช้ QR สำหรับเคส CBM ≥ 70%

\#\#\# Warnings (if any)  
\- ระบุบทบาท/ชุดสิทธิ์ RBAC ที่สามารถทำ Check-In / Void ไม่ได้กำหนดไว้ในข้อมูลต้นทาง — ต้องระบุ mapping บทบาทก่อนพัฒนาจริง  
\- ขอบเขตข้อมูล audit (fields ที่ต้องเก็บสำหรับ audit trail) ไม่มีรายละเอียดเชิงเทคนิค — ต้องสรุปฟิลด์ audit ที่ต้องบันทึก  
\- ความหมายทางเทคนิคของ "partial unique" ของ coin\_number (วิธีตรวจสอบ/lock แบบ optimistic/DB constraint) ยังไม่ชัดเจน ต้องกำหนดวิธีทางเทคนิค

\# 3\. Scope & Constraints

\#\# 3.1 In Scope  
\- หน้ารายการ (List) แยกแท็บ \[ต้องส่ง\] และ \[เช็คอินแล้ว\] พร้อม Search/Filter/Sort ตาม Page 1 (/cane/check-in)  
\- ฟังก์ชัน Check-In 3 โหมด: CBM, member\_no\_booking, guest\_pool พร้อม validation ของฟิลด์ตามแต่ละโหมด  
\- QR Scan เพื่อเติม cbm\_id และ fallback กรอกด้วยมือ (Page 6 /cane/check-in/scan)  
\- Void ก่อนสถานะ completed และคืนสิทธิ์ coin\_number ตาม Journey D และ Page 7 (/cane/check-in/{id}/void)  
\- Validation และบังคับให้กรอก payment\_type\_1st/payment\_type\_2nd และ debt\_payment\_percent ในกรณี member\_no\_booking  
\- หน้าหลักและคอมโพเนนต์สำคัญจาก Page Definitions:  
  \- หน้าที่ครอบคลุม: List view (/cane/check-in) แสดงแท็บ \[ต้องส่ง\]/\[เช็คอินแล้ว\] พร้อม ActionBar \[Check-In, Scan QR, Export CSV\]  
  \- หน้าที่ครอบคลุม: Modal เลือกโหมดเช็คอิน (/cane/check-in/new) และ Drawers สำหรับเช็คอินแต่ละโหมด (/cane/check-in/new/cbm, /member, /guest)  
  \- หน้าที่ครอบคลุม: Modal Scan QR (/cane/check-in/scan) และ Modal Confirm Void (/cane/check-in/{id}/void)  
\- รองรับการทำงานบนมือถือ (mobile friendly) และแสดงเวลาเป็น พ.ศ., TZ=Asia/Bangkok  
\- ส่ง EventBus: cane.checkin.created เมื่อสร้าง และ cane.checkin.voided เมื่อ void สำเร็จ  
\- PATCH ไปยัง /api/cbm/bookings/{cbm\_id}/status เมื่อเช็คอินแบบ CBM เพื่อ set phase\_cut\_transport='awaiting\_payment'

\#\# 3.2 Out of Scope  
\- กระบวนการชั่งเข้า/เทา/ชั่งออก ของระบบโรงงาน (weighing process)  
\- ฟีเจอร์ Payment ที่ทำให้สถานะเป็น completed หรือกระบวนการชำระเงินเชิงลึก (Payment engine)  
\- การเปลี่ยนสถานะ awaiting\_payment/completed ด้วยมือ (ต้องห้ามตามข้อกำหนด)  
\- การออกแบบหรือเปลี่ยนแปลง RBAC กลาง (เฉพาะการใช้สิทธิ์ที่มีอยู่)

\#\# 3.3 Assumptions  
\- มี endpoint POST /api/cane-checkins เพื่อสร้างเช็คอิน และรองรับ payload ตาม Page Definitions  
\- มี endpoint PATCH /api/cbm/bookings/{cbm\_id}/status ที่ทีม CBM ยอมรับการเรียกและ schema body { "phase\_cut\_transport": "awaiting\_payment" }  
\- มี EventBus ที่ระบบสามารถส่งอีเวนต์ cane.checkin.created และ cane.checkin.voided ได้  
\- GET /api/cbm/bookings?status=dispatch ให้ข้อมูลรายการ "ต้องส่ง" ที่จำเป็น (cbm\_id, plate, driver, scheduled\_date\_time ฯลฯ)  
\- ระบบ Payment จะอ่านฟิลด์: source\_type, payment\_type\_1st, payment\_type\_2nd, debt\_payment\_percent (เฉพาะ member\_no\_booking), coin\_number, checkin\_time  
\- มีกลไกตรวจสอบ/ป้องกัน coin\_number ซ้ำ (partial-unique) ที่สามารถตอบกลับแบบ synchronous ในขั้นตอน validate ก่อนยืนยันเช็คอิน  
\- การแสดงเวลาตาม พ.ศ. และโซนเวลา Asia/Bangkok ถูกตั้งค่าที่ระดับแอป/หน้า UI

\#\# 3.4 Dependencies & Integrations  
\- Inbound:  
  \- QR Scanner (client) → เติม cbm\_id ในฟอร์ม (Page 6\)  
  \- Frontend ต้องสามารถอ่าน/parse QR และเติมค่าใน Drawer/Modal  
\- Upstream read-only:  
  \- GET /api/cbm/bookings?status=dispatch เพื่อดึงรายการ "ต้องส่ง" สำหรับแท็บและ prefill ข้อมูล CBM  
\- Outbound HTTP:  
  \- PATCH /api/cbm/bookings/{cbm\_id}/status body { "phase\_cut\_transport": "awaiting\_payment" } เมื่อตรวจพบการเช็คอินแบบ CBM  
\- EventBus:  
  \- ส่ง cane.checkin.created เมื่อสร้างเช็คอินสำเร็จ  
  \- ส่ง cane.checkin.voided เมื่อ void สำเร็จ  
\- Downstream:  
  \- ระบบ Payment จะอ่านข้อมูลเช็คอิน (source\_type, payment\_type\_1st/2nd, debt\_payment\_percent, coin\_number, checkin\_time) เพื่อคำนวณ/ตัดหนี้  
\- Infra/Policy:  
  \- ระบบต้องปฏิบัติตามแนวปฏิบัติ P0-lite headers/errors และใช้ RBAC กลาง สำหรับการอนุญาต  
\- UI constraints:  
  \- ต้องรองรับการใช้งานบนมือถือและแสดงเวลาตาม พ.ศ.

\#\#\# Warnings (if any)  
\- Specification ของ payload สำหรับ POST /api/cane-checkins และรูปแบบอีเวนต์ EventBus ยังไม่ระบุเป็น schema เชิงลึก — ต้องมีตัวอย่าง payload ก่อนพัฒนา API integration เชิงเต็ม  
\- การกำหนดผู้มีสิทธิ์ (RBAC roles) สำหรับการทำ Check-In และ Void ยังไม่ถูกกำหนด — ต้องชี้ชัดก่อนเปิดใช้งานในระบบจริง  
\- วิธีการทางเทคนิคในการบังคับ "partial unique" ของ coin\_number (DB constraint vs service-level lock vs optimistic check) ยังต้องสรุปเพื่อหลีกเลี่ยง race condition

\# 4\. Target Users & RBAC

\> Feature: เช็คอินรถส่งอ้อย · Module: โลจิสติกส์อ้อย / ประตูโรงงาน · Base Path: /cane/check-in · Menu: การจัดการอ้อย → เช็คอิน

\#\# 4.1 Personas / Roles  
\- \*\*Gate Staff\*\* — ผู้ปฏิบัติงานที่ประตูโรงงาน รับรถ/สแกน QR และทำรายการ Check-In (CBM / member\_no\_booking / guest\_pool) รวมถึงขอ Void ก่อนรายการจะ completed    
\- \*\*Dispatcher\*\* — ผู้เฝ้าดูสถานะคิวและรายงาน ดูรายการในมุมมองแบบ read-only เพื่อติดตามคิวและสถานะการเช็คอิน    
\- \*\*Logistics Supervisor\*\* — ผู้ควบคุมนโยบายปฏิบัติการ โลจิสติกส์ ควบคุม/อนุมัติกรณี Void ตามนโยบายองค์กร และติดตามสถานะรวมของการเช็คอิน    
\- \*\*External Systems\*\* — ระบบภายนอกเช่น QR Scanner, CBM, EventBus, Payment — ใช้อ่าน/รับข้อมูลหลังการเช็คอิน หรือส่ง callback/status (system actors, not human users)    
\- \*\*Admin / Owner\*\* — ผู้ดูแลระบบสูงสุด (system admin) — จัดการสิทธิ์การใช้งานและเข้าถึงทุกหน้า/ข้อมูลเพื่อดูหรือแก้ไขเมื่อจำเป็น

\#\# 4.2 Action Taxonomy (entity: checkin / cane\_checkins)

Notes: แถว action เป็น taxonomy มาตรฐานที่ดึงจาก Use Cases & Journeys; บทบาทที่อนุญาตใช้สัญลักษณ์: ✓ \= อนุญาต, — \= ไม่อนุญาต, C \= อนุญาตแบบมีเงื่อนไข (รายละเอียดเงื่อนไขอยู่ใต้ตาราง)

| Action (entity: checkin) | Gate Staff | Dispatcher | Logistics Supervisor | External Systems | Admin |  
|---|:---:|:---:|:---:|:---:|:---:|  
| view:list | ✓ | ✓ | ✓ | — | ✓ |  
| view:detail | ✓ | ✓ | ✓ | — | ✓ |  
| search/filter | ✓ | ✓ | ✓ | — | ✓ |  
| export:csv | ✓ | ✓ | ✓ | — | ✓ |  
| create (checkin) | ✓ | — | — | — | ✓ |  
| create:member\_no\_booking (checkin) | ✓ | — | — | — | ✓ |  
| create:cbm\_booking (checkin) | ✓ | — | — | C | ✓ |  
| create:guest\_pool (checkin) | ✓ | — | — | — | ✓ |  
| scan\_qr (ui action → prefill cbm\_id) | ✓ | — | — | ✓ (QR Scanner) | ✓ |  
| update (edit checkin pre-completion) | C\* | — | C\* | — | ✓ |  
| delete:soft (void) — 사용자ทำ Void | ✓ (initiate) | — | C (may be required to approve) | — | ✓ |  
| approve (void / policy approval) | — | — | C | — | ✓ |  
| reject (void) | — | — | C | — | ✓ |  
| status:change (set awaiting\_payment / checked\_in / voided / completed) | ✓ (triggered by create/void) | — | C (monitor/override?) | ✓ (Payment/CBM callbacks) | ✓ |  
| export:pdf / download:doc | — | — | — | — | — |  
| bulk:\<action\> | — | — | — | — | — |

เงื่อนไข (C) ที่สำคัญ:  
\- update (C\*): Gate Staff สามารถแก้ไขข้อมูลขณะกรอก/ก่อนยืนยันใน Drawer; การแก้ไขหลัง checkin.status=awaiting\_payment/completed อาจจำกัด — ขึ้นกับนโยบาย (ไม่ระบุใน A0)    
\- create:cbm\_booking (C): บางการสร้างที่มาจาก CBM อาจถูกเรียกโดยระบบภายนอก (QR Scanner/CBM) เพื่อ prefill — การอนุญาตสร้างสุดท้ายยังคงต้องเป็น Gate Staff กดยืนยัน    
\- delete:soft (void) / approve/reject: Gate Staff สามารถสั่ง Void (initiate) แต่ตามนโยบายองค์กร Logistics Supervisor อาจต้องเป็นผู้อนุมัติ Void ก่อนที่จะเปลี่ยนสถานะจริง (ระบุเป็น C เพราะกฎไม่ชัด)    
\- status:change: การเปลี่ยนไปสู่ completed หรือการคืนสิทธิ์ coin\_number อาจเกิดจากระบบ Payment/CBM callbacks หรือ flow ที่ต้องมีการอนุมัติ — ไม่ได้กำหนดชัดเจนใน A0

หมายเหตุ:  
\- Actions เช่น export:pdf, download:doc, bulk:\<action\> ไม่มีใน Use Cases/Page Definitions จึงกำหนดเป็น —    
\- External Systems ถูกมองเป็น system actors ที่ส่ง/รับข้อมูลผ่าน API (เช่น POST /api/cane-checkins callbacks, PATCH /api/cbm/bookings/{cbm\_id}/status)

\#\# 4.3 Route & API patterns, Page → Action mapping, Row/Field-level constraints

A. Routes (Pages)  
\- Pages (standard list/detail/create)  
  \- GET /cane/check-in  — Page: Check-In List (Landing) — Tabs: \[ต้องส่ง\] \[เช็คอินแล้ว\]  
  \- GET /cane/check-in/new — Modal: Choose Check-In Mode  
  \- GET /cane/check-in/new/cbm — Drawer: Check-In (CBM)  
  \- GET /cane/check-in/new/member — Drawer: Check-In (Member no-booking)  
  \- GET /cane/check-in/new/guest — Drawer: Check-In (Guest / โควต้ากลาง)  
  \- GET /cane/check-in/scan — Modal: Scan QR  
  \- GET /cane/check-in/{id}/void — Modal: Confirm Void

B. API patterns (examples)  
\- GET /api/cane-checkins  — list / search / filter  
\- POST /api/cane-checkins  — create new checkin (body differs by source\_type: cbm\_booking | member\_no\_booking | guest\_pool)  
\- GET /api/cane-checkins/{id}  — get detail  
\- PATCH /api/cane-checkins/{id}  — update (partial)  
\- DELETE /api/cane-checkins/{id}  — (not used; use void)  
\- POST /api/cane-checkins/void  — void action {checkin\_id, reason}  
\- POST /api/cane-checkins/{id}:restore  — (not defined in A0; PUT/POST restore omitted unless specified)  
\- POST /api/cane-checkins:bulk  — (bulk endpoints not defined in A0)  
\- PATCH /api/cbm/bookings/{cbm\_id}/status  — patch CBM booking status (e.g., {phase\_cut\_transport:'awaiting\_payment'})  
\- Integration callbacks:  
  \- Event/Payment → update checkin status (awaiting\_payment → completed) via dedicated callbacks (paths unspecified in A0)

C. Page / Tab → Action mapping (who can do what on which UI)  
\- Page: Check-In — List View (/cane/check-in)  
  \- Tabs:  
    \- \[ต้องส่ง\]  
      \- Actions visible: Check-In (per-row), Scan QR (ActionBar), Export CSV (ActionBar)  
      \- Roles:  
        \- Gate Staff: view list, view detail (drawer prefill), initiate Check-In (open Drawer CBM), use Scan QR, Export CSV  
        \- Dispatcher: view list, Export CSV (read-only)  
        \- Logistics Supervisor: view list (monitor), Export CSV  
        \- Admin: full access  
    \- \[เช็คอินแล้ว\]  
      \- Actions visible: Void (if status \!= completed), Export CSV  
      \- Roles:  
        \- Gate Staff: view list, initiate Void (open Confirm Void modal) for items not completed  
        \- Dispatcher: view-only  
        \- Logistics Supervisor: view, approve/reject Void (if policy requires)  
        \- Admin: full access  
  \- Search / Filters: cbm\_id / quota / plate / coin (text), Filters: source\_type, status, date range, guest\_only — all viewing roles with search rights (see matrix)

\- Modal: Choose Check-In Mode (/cane/check-in/new)  
  \- Roles:  
    \- Gate Staff: open modal, choose mode and proceed  
    \- Dispatcher: view-only (if allowed to open, but primarily read)  
    \- Admin: allowed

\- Drawer: Check-In (CBM) (/cane/check-in/new/cbm)  
  \- Actions/fields:  
    \- cbm\_id (readonly if from QR/row) — prefilled  
    \- plate\_no, driver\_name, driver\_phone (readonly)  
    \- coin\_number (required, unique partial) — validation on submit  
    \- notes  
    \- Buttons: \[ยืนยันเช็คอิน\] → POST /api/cane-checkins ; also PATCH /api/cbm/bookings/{cbm\_id}/status {phase\_cut\_transport:'awaiting\_payment'}  
  \- Roles:  
    \- Gate Staff: allowed to confirm (create)  
    \- External Systems (QR Scanner/CBM): can prefill cbm\_id via Scan QR flow  
    \- Admin: allowed

\- Drawer: Check-In (Member no-booking) (/cane/check-in/new/member)  
  \- Actions/fields per Page Definitions  
  \- Roles:  
    \- Gate Staff: allowed to create (must provide quota\_id, debt\_payment\_percent, etc.)  
    \- Admin: allowed

\- Drawer: Check-In (Guest) (/cane/check-in/new/guest)  
  \- Actions/fields per Page Definitions  
  \- Roles:  
    \- Gate Staff: allowed to create  
    \- Admin: allowed

\- Modal: Scan QR (/cane/check-in/scan)  
  \- Function: camera preview → parse cbm\_id → fill Drawer fields  
  \- Roles:  
    \- Gate Staff: use scanner in UI  
    \- External Systems: provide QR data (integration)  
    \- Admin: allowed

\- Modal: Confirm Void (/cane/check-in/{id}/void)  
  \- Actions:  
    \- Fields: reason (required)  
    \- Buttons: \[Void\] → POST /api/cane-checkins/void {checkin\_id, reason} → change status=voided & release coin\_number  
  \- Roles:  
    \- Gate Staff: initiate Void (submit)  
    \- Logistics Supervisor: may need to approve Void (policy) — see conditional approval below  
    \- Admin: can Void and override approvals

D. Row / Field-level restrictions  
\- From Use Cases: ไม่มีการระบุ branch/organization-level row restrictions ใน A0 → ไม่สามารถระบุได้แน่ชัด (ดู Warnings)    
\- Field-level notes (จาก Page Definitions):  
  \- cbm\_id, plate\_no, driver\_name/phone: readonly when prefilled from CBM/QR  
  \- quota\_id (member\_no\_booking): search/select, required  
  \- coin\_number: required, must be unique (partial uniqueness validation enforced)  
  \- guest\_flag: readonly=true (default true) for guest\_pool  
  \- debt\_payment\_percent: เก็บและแสดงเฉพาะ source\_type=member\_no\_booking

E. Approval / Status model (as mapped)  
\- Canonical statuses (จาก Canonical Map): checked\_in → awaiting\_payment → completed → voided    
\- Transitions observed in Journeys:  
  \- Create from CBM → checked\_in → set awaiting\_payment (PATCH CBM booking)  
  \- Create (member/guest) → awaiting\_payment  
  \- Void → voided (and coin\_number returned)  
\- Approval: Void may require approval by Logistics Supervisor (policy dependent). ใครสามารถเปลี่ยนเป็น completed หรือ restore ไม่ได้ระบุชัด — ดู Warnings

Warnings (ข้อควรทราบ / ข้อมูลขาด):  
\- ไม่มีการระบุ explicit entity list ใน A0 (เช่น A0.entities) — ผมใช้ entity หลักเป็น "checkin" / "cane\_checkins" ตามชื่อ Feature และ Page Definitions    
\- นโยบายการอนุมัติ Void ยังไม่ชัดเจน: Journey บอกว่า Logistics Supervisor "อาจต้องยืนยัน" — ยังไม่ทราบเงื่อนไข (เมื่อใดต้องอนุมัติ, workflow approve API/endpoint) — ต้องระบุในนโยบายองค์กรเพื่อกำหนด logic approve/reject และ UI state transitions    
\- การเปลี่ยนสถานะเป็น completed (หลังชำระ) และการ restore (undo void) ไม่มีรายละเอียด API/actor ที่ชัดเจน (e.g., Payment callbacks, who marks completed) — ต้องเพิ่มข้อกำหนดสำหรับ integration กับ Payment/CBM เพื่อกำหนด actor และ endpoints ที่แน่นอน    
\- Row/field-level access (เช่น Gate Staff ควรเห็นเฉพาะคิวของประตูหรือสาขาใด) ไม่ได้ระบุ — ถ้าต้องการควบคุมตามสาขา/gate ต้องให้ข้อมูลเพิ่มเติมเกี่ยวกับ tenant/branch scoping และ filters per user    
\- ไม่มีการระบุ explicit Admin role capabilities (user management, data restore) นอกเหนือจากการให้สิทธิ์สูงสุด — ถ้าต้องการสิทธิ์เฉพาะต้องกำหนดเพิ่มเติม    
\- ไม่มีการระบุ bulk actions (bulk void / bulk export) ใน Use Cases — ถาต้องการให้รองรับ ให้เพิ่มข้อกำหนด

(จบ Section 4\)

\# 6\. Capabilities Overview & Layout Patterns

\> Feature: \*\*เช็คอินรถส่งอ้อย\*\* · Module: \*\*โลจิสติกส์อ้อย / ประตูโรงงาน\*\* · Base Path: \*\*/cane/check-in\*\* · Menu: \*\*การจัดการอ้อย → เช็คอิน\*\*

\#\# 6.1 เป้าหมายและกรอบความสามารถ (ยึดตาม use cases)  
\- รองรับการแสดงรายชื่อคิว (ต้องส่ง) และรายการที่เช็คอินแล้ว (เช็คอินแล้ว) พร้อม Search/Filter/Sort/Export CSV  
\- รองรับการสร้าง Check-In สามแบบ: จาก CBM (มีคิว), สมาชิกไม่มีคิว (member\_no\_booking) และ โควต้ากลาง/Guest (guest\_pool)  
\- บันทึก Audit (actor, timestamp, reason for void) และบังคับ ETag/Idempotency ในคำสั่งสำคัญ  
\- รองรับการ Void (soft) เพื่อคืนสิทธิ์ \*\*coin\_number\*\*  
\- กำหนด workflow สถานะตาม Status Model: checked\_in → awaiting\_payment → completed | voided

\#\# 6.2 Layout Patterns (ตัวอย่างอ้างอิง)  
\- List Page: Header → Search/Filter Bar → ActionBar (ขวา) → Table (compact; checkbox ซ้าย) → Pagination  
\- Create Drawer (Check-In Drawers): Drawer:right width=40% → H1 \+ subtitle \+ actions → Form (vertical, sections) → Footer action bar (Cancel | Primary)  
\- Detail / View Drawer: Drawer:right width=40% → H1/meta → Tabs → Content sections (KeyValue / Table / Free area)  
\- Modals: Centered modal (confirmation/scan) focus-trap; small-form modal ใช้สำหรับ Confirm Void / Choose Mode / Scan QR  
\- Interaction pattern: Primary action ปุ่มขวาสุดเสมอ; numeric fields ชิดขวา; badges/labels กึ่งกลาง

\#\# 6.3 Navigation Rules  
\- URL ชุดมาตรฐาน: List=\`/cane/check-in\`, Create=\`/cane/check-in/new\`, Detail=\`/cane/check-in/:id\`, Edit=\`/cane/check-in/:id/edit\`  
\- ห้ามเข้าหน้า \*\*Edit\*\* เมื่อสถานะเป็น \*\*Archived\*\* (ไม่มี Archived ใน model นี้ — ถ้ามีให้ปิดการเข้าถึง)  
\- หาก RBAC ไม่พอ → redirect ไป \`\<base\_path\>\` \+ แสดง toast 403 (ข้อความไทย)  
\- Create/Update สำเร็จ → navigate → Detail (หรือ Tab “เช็คอินแล้ว”) พร้อม toast success  
\- 412 (ETag mismatch) → ดึงข้อมูลล่าสุด \+ แสดง dialog ช่วย merge

\#\# 6.4 Microcopy & States (i18n/A11y)  
\- ข้อความระบบเป็นภาษาไทย (Success/Error/Empty/403/409/412)  
\- ทุกปุ่มมี aria-label, ทุก modal มี role="dialog" \+ aria-modal="true"  
\- Focus order: modal/drawer เปิด → focus ไปที่ field แรก → ปุ่มปิดเป็น Tab stop สุดท้าย  
\- Empty states มีคำอธิบายสั้นและ CTA (e.g., \*\*ยังไม่มีรายการที่ต้องส่ง\*\* \+ ปุ่ม \*\*Check-In\*\*)

\#\# 6.5 Page–Journey Cohesion (ใหม่)  
\- ทุกหน้าและโมดัลผูกกับ Journey (A..E) ชัดเจน: ปุ่มใด → journey ใด → เรียก API ใด → เงื่อนไขก่อนกด → ผลลัพธ์/การนำทาง/เหตุการณ์  
\- Visibility & Action Gating ถูกกำหนดตามบทบาท (A2) และสถานะ (A3)

Warnings (ข้อควรทราบ)  
\- template\_source: ใช้เทมเพลตจากไลบรารี (packingList.v1, createDrawer.v2, viewDrawer.v1, deleteConfirm.v1) — รายการเทมเพลตที่ใช้บันทึกด้านล่างใน §7.2 แต่เทมเพลตมี tokens บางตัวที่ไม่พบข้อมูลเฉพาะ → บันทึกใน Warnings ของ §7  
\- ยังไม่ระบุ API/contract สำหรับ Payment → completed transition (ต้องกำหนด webhook/payload เพิ่ม)  
\- นโยบายการอนุมัติ Void ไม่ชัดเจน (Logistics Supervisor อาจต้องอนุมัติ) — ต้องระบุกติกา approve/reject/auto-apply  
\- รายละเอียด scoping ของ Gate Staff (branch/gate-limited views) ไม่ระบุ → หากต้องการต้องกำหนดเพิ่มเติม

\---

\# 7\. Page Inventory (URLs & Screens)

\> Feature: \*\*เช็คอินรถส่งอ้อย\*\* · Base Path: \*\*/cane/check-in\*\*

\#\# 7.1 URLs & Routing  
\- \*\*List\*\*: \`/cane/check-in\` — เริ่ม \`?page=1\&page\_size=25\&sort=-checkin\_time\`  
\- \*\*Create (Choose Mode modal)\*\*: \`/cane/check-in/new\`  
\- \*\*Drawer CBM\*\*: \`/cane/check-in/new/cbm\`  
\- \*\*Drawer Member (no-booking)\*\*: \`/cane/check-in/new/member\`  
\- \*\*Drawer Guest\*\*: \`/cane/check-in/new/guest\`  
\- \*\*Scan QR (modal)\*\*: \`/cane/check-in/scan\`  
\- \*\*Confirm Void (modal)\*\*: \`/cane/check-in/{id}/void\`  
\- \*\*Routing guards\*\*: ห้าม Edit เมื่อสถานะ \= \*\*completed\*\*/\*\*awaiting\_payment\*\* (per status model); RBAC ไม่พอ → redirect \`/cane/check-in\` \+ toast 403

\#\# 7.2 Page Definitions

\#\#\# 7.2.1 Check-In — List View (Landing) — \`/cane/check-in\`  
\*\*Purpose\*\*: แสดงรายการ "ต้องส่ง" และ "เช็คอินแล้ว" เพื่อให้ Gate Staff/Dispatcher ดูและทำ Check-In / Void / Export

\#\#\#\# Layout  
\- เลือกเทมเพลต: \`packingList.v1\` (Page Type \= List) · Grid Spec: 12col; fixed-header; toolbar right-aligned; table density=compact; checkbox ซ้ายสุด

\#\#\#\# ASCII Wireframe  
\`\`\`text  
\+------------------------------------------------------------------------------+  
| Breadcrumbs: การจัดการอ้อย › เช็คอิน                                         |  
\+------------------------------------------------------------------------------+  
| H1 Title: เช็คอินรถส่งอ้อย                                                    |  
| H2 Subtitle: ตรวจสอบคิวและทำการเช็คอิน                                        |  
\+------------------------------------------------------------------------------+  
| 🔍 ค้นหา: \[ ค้นหา cbm\_id/quota/plate/coin \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ \]  |  
|                                                     Filter: (status,source) ▼  |  
|                                                     \[ Advanced Filters \]      |  
\+------------------------------------------------------------------------------+  
|                                                     \[ Scan QR \] \[ Export CSV \] |  
|                                                     \[ Check-In (primary) \]    |  
\+------------------------------------------------------------------------------+  
| \[ \] CBM\_ID    | Farmer Name | Quota\_ID  | Plate\_No | Driver | Phone | Actions |  
|--------------+-------------+-----------+----------+--------+-------+---------|  
| … rows (compact; numeric → right; status badge center)                         |  
\+------------------------------------------------------------------------------+  
| Showing 1-25 of 300                       « Previous  \[1\]  Next »             |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \[\*\*Breadcrumbs\*\*\]  
\- \[\*\*PageHeaderTitle\*\*\] (H1)  
\- \[\*\*PageDescription\*\*\] (H2)  
\- \[\*\*SearchBar\*\*\] (slot: toolbar\_left) — placeholder: \*\*ค้นหา cbm\_id/quota/plate/coin\*\*  
\- \[\*\*FilterDropdown\*\*\], \[\*\*AdvancedFilterDrawerV2\*\*\] (controls\_top\_right)  
\- \[\*\*Button\*\*\] \[\*\*Button\*\*\] \[\*\*Button\*\*\] (toolbar\_right) → actions: \[Scan QR\], \[Export CSV\], \[Check-In (primary)\]  
\- \[\*\*MasterDataTable\*\*\] (main) — dual-tab rendering: Tab1="ต้องส่ง" Tab2="เช็คอินแล้ว"  
\- \[\*\*PaginationControls\*\*\]

\#\#\#\# Actions / Events & Binding  
\- Search input → debounce 300ms → GET \`/api/cane-checkins?query={q}\&tab={tab}\&page=...\`  
\- Filter apply → GET \`/api/cane-checkins?{filters}\`  
\- Sort → GET \`/api/cane-checkins?sort={col}\`  
\- \[\*\*Button\*\* Scan QR\] → open modal GET \`/cane/check-in/scan\`  
\- \[\*\*Button\*\* Check-In\] (primary) → open modal GET \`/cane/check-in/new\`  
\- Row action \[\*\*Button\*\* Check-In\] (per-row CBM) → open drawer GET \`/cane/check-in/new/cbm?cbm\_id={cbm\_id}\`  
\- Row action \[\*\*Button\*\* Void\] (in tab "เช็คอินแล้ว", if status \!= completed) → open modal GET \`/cane/check-in/{id}/void\`  
\- \[\*\*Button\*\* Export CSV\] → GET \`/api/cane-checkins?{current\_filters}\&export=csv\` → download

\#\#\#\# Validation  
\- Search: min 1 char  
\- Date range filter: from \<= to  
\- Table: checkbox selection only for allowed roles (no bulk in current spec)

\#\#\#\# RBAC & Status Gating  
\- Gate Staff: view both tabs, open drawers/modals, create checkins, initiate Void (if status \!= completed)  
\- Dispatcher: read-only (view List, Export CSV)  
\- Logistics Supervisor: view & may approve Void (policy-dependent)  
\- Admin: full access  
\- Actions disabled/hidden if role lacks permission; attempting action → redirect \`/cane/check-in\` \+ toast 403

\#\#\#\# Microcopy (i18n/A11y)  
\- Empty tab text: \*\*ยังไม่มีรายการที่ต้องส่ง\*\* / \*\*ยังไม่มีรายการเช็คอินแล้ว\*\*  
\- Search aria-label="ค้นหารายการเช็คอิน"  
\- Buttons: \*\*Scan QR\*\*, \*\*Export CSV\*\*, \*\*Check-In\*\* (aria-haspopup for modals)

\#\#\#\# Journey Bindings  
\- \`Journey A\`: \`/cane/check-in\` (Tab "ต้องส่ง") / row Check-In → opens \`/cane/check-in/new/cbm\` → prefill from CBM  
  \- Preconditions: row.source\_type \== CBM  
  \- On success: POST \`/api/cane-checkins\` \-\> status checked\_in \-\> auto awaiting\_payment \-\> PATCH \`/api/cbm/bookings/{cbm\_id}/status {phase\_cut\_transport:'awaiting\_payment'}\`  
\- \`Journey B\`/\`C\`: \`/cane/check-in\` / ActionBar Check-In → open \`/cane/check-in/new\` modal → choose mode  
\- \`Journey D\`: Tab "เช็คอินแล้ว" / row Void → open \`/cane/check-in/{id}/void\` modal

\#\#\#\# Notes  
\- Table "เช็คอินแล้ว" columns: \*\*checkin\_id\*\*, \*\*source\_type\*\* (label ไทย), \*\*cbm\_id\*\*, \*\*quota\_id\*\*, \*\*plate\_no\*\*, \*\*coin\_number\*\*, \*\*payment\_1st\*\*, \*\*payment\_2nd\*\*, \*\*debt\_payment\_percent\*\* (แสดงเฉพาะ member\_no\_booking), \*\*checkin\_time\*\*, \*\*status\*\*, \*\*actions\*\*

\---

\#\#\# 7.2.2 Choose Check-In Mode — Modal — \`/cane/check-in/new\`  
\*\*Purpose\*\*: ให้ Gate Staff เลือกโหมดเช็คอิน (มีคิวจาก CBM / ไม่มีคิว (สมาชิก) / โควต้ากลาง)

\#\#\#\# Layout  
\- ใช้เทมเพลต: \`deleteConfirm.v1\` ปรับเป็น Modal ที่มี options (Modal:center; width≈480px)

\#\#\#\# ASCII Wireframe  
\`\`\`text  
\+------------------------------------------------------------------------------+  
|                           เลือกโหมดการเช็คอิน                                |  
\+------------------------------------------------------------------------------+  
| เลือกวิธีเช็คอินเพื่อดำเนินการ                                                |  
|                                                                              |  
|  ( ) มีคิวจาก CBM        \[Card style option\]                                 |  
|  ( ) ไม่มีคิว (สมาชิก)   \[Card style option\]                                 |  
|  ( ) โควต้ากลาง (Guest)  \[Card style option\]                                 |  
\+------------------------------------------------------------------------------+  
|                                               \[ ยกเลิก \]   \[ ถัดไป (Next) \]  |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \[\*\*ModalDialog\*\*\] / \[\*\*RadioGroup\*\*\] (card-style options)  
\- \[\*\*Button\*\*\] Cancel, \[\*\*Button\*\*\] Next (primary)

\#\#\#\# Actions / Events & Binding  
\- Selection → Next:  
  \- If 선택 \== "CBM" → navigate to \`/cane/check-in/new/cbm\`  
  \- If 선택 \== "member\_no\_booking" → navigate to \`/cane/check-in/new/member\`  
  \- If 선택 \== "guest\_pool" → navigate to \`/cane/check-in/new/guest\`

\#\#\#\# Validation  
\- ต้องเลือกรายการหนึ่งก่อน Next

\#\#\#\# RBAC & Status Gating  
\- Gate Staff & Admin: เปิด modal และ proceed  
\- Dispatcher: ถ้ามีสิทธิ์ view-only ให้ปุ่ม Next disabled

\#\#\#\# Microcopy (i18n/A11y)  
\- Option labels:  
  \- \*\*มีคิวจาก CBM\*\*  
  \- \*\*ไม่มีคิว (สมาชิก)\*\*  
  \- \*\*โควต้ากลาง\*\*  
\- RadioGroup aria-label="เลือกโหมดการเช็คอิน"

\#\#\#\# Journey Bindings  
\- \`Journey B\` (Member no-booking): \`/cane/check-in/new\` → choose "ไม่มีคิว (สมาชิก)" → open \`/cane/check-in/new/member\`  
\- \`Journey C\` (Guest): choose "โควต้ากลาง" → open \`/cane/check-in/new/guest\`  
\- \`Journey A\` (CBM): choose "มีคิวจาก CBM" → (or row Check-In / Scan QR) → open \`/cane/check-in/new/cbm\`

\---

\#\#\# 7.2.3 Check-In (CBM) — Drawer (Create) — \`/cane/check-in/new/cbm\`  
\*\*Purpose\*\*: สร้าง checkin สำหรับรายการที่มีคิวจาก CBM (prefill จาก CBM row หรือ QR)

\#\#\#\# Layout  
\- เทมเพลต: \`createDrawer.v2\` · Grid Spec: Drawer:right; width=40%; vertical form; footer sticky

\#\#\#\# ASCII Wireframe  
\`\`\`text  
\+------------------------------------------------------------------------------+  
| H1: เช็คอิน (จาก CBM)                                         \[ ☐ Expand \]\[✕\] |  
| Sub: prefill จาก CBM · cbm\_id: CBM-xxxxxxx                                  |  
\+------------------------------------------------------------------------------+  
| Section: ข้อมูลคันรถ                                                         |  
| | \*\*CBM ID\*\* \[Input readonly\] (field: \*\*cbm\_id\*\*)                            |  
| | \*\*ทะเบียนรถ\*\* \[Input readonly\] (field: \*\*plate\_no\*\*)                      |  
| | \*\*ชื่อคนขับ\*\* \[Input readonly\] (field: \*\*driver\_name\*\*)                   |  
| | \*\*โทรคนขับ\*\* \[Input readonly\] (field: \*\*driver\_phone\*\*)                  |  
\+------------------------------------------------------------------------------+  
| Section: การจองเหรียญ                                                       |  
| | \*\*หมายเลขเหรียญ\*\* \[Input\] (field: \*\*coin\_number\*\*)                       |  
| | \*\*หมายเหตุ\*\* \[Textarea\] (field: \*\*notes\*\*)                                |  
| | Hint: ตรวจสอบความถูกต้องของหมายเลขเหรียญ (max 12\)                        |  
\+------------------------------------------------------------------------------+  
| Left: \[ยกเลิก\]                                    Right: \[ยืนยันเช็คอิน\]       |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \[\*\*DrawerHeader\*\*\] (title, subtitle)  
\- \[\*\*FormLayout\*\*\]  
\- Fields:  
  \- \*\*CBM ID\*\* \[\*\*Input\*\*\] (field: \*\*cbm\_id\*\*, readonly)  
  \- \*\*ทะเบียนรถ\*\* \[\*\*Input\*\*\] (field: \*\*plate\_no\*\*, readonly)  
  \- \*\*ชื่อคนขับ\*\* \[\*\*Input\*\*\] (field: \*\*driver\_name\*\*, readonly)  
  \- \*\*โทรคนขับ\*\* \[\*\*Input\*\*\] (field: \*\*driver\_phone\*\*, readonly) — pattern: \`^0\\d{8,9}$\`  
  \- \*\*หมายเลขเหรียญ\*\* \[\*\*Input\*\*\] (field: \*\*coin\_number\*\*) — required, maxLength=12  
  \- \*\*หมายเหตุ\*\* \[\*\*Textarea\*\*\] (field: \*\*notes\*\*) — optional  
\- Footer buttons: \[\*\*Button\*\*\] ยกเลิก, \[\*\*Button\*\* primary\] ยืนยันเช็คอิน

\#\#\#\# Actions / Events & Binding  
\- \[\*\*Button\*\* ยืนยันเช็คอิน\] → client-validate → POST \`/api/cane-checkins\`  
  \- Body: { source\_type: 'cbm\_booking', cbm\_id, plate\_no, driver\_name, driver\_phone, coin\_number, notes }  
  \- Headers: \`Idempotency-Key: {uuid}\`  
  \- On success (201): server sets status=checked\_in → immediately sets awaiting\_payment (auto)  
  \- Side-effect: PATCH \`/api/cbm/bookings/{cbm\_id}/status\` with \`{phase\_cut\_transport:'awaiting\_payment'}\` (same transaction or sequenced call)  
  \- On success: navigate to List Tab "เช็คอินแล้ว" or requery list \+ toast success  
\- Error cases:  
  \- 409 → coin\_number reserved by concurrent request → show conflict UI  
  \- 412 → ETag mismatch on PATCH CBM → prompt refresh/merge

\#\#\#\# Validation  
\- \*\*coin\_number\*\* required, non-empty, max 12, unique (partial) — check via \`POST\` validation or pre-validate endpoint \`GET /api/cane-checkins/validate?coin\_number=...\`  
\- \*\*driver\_phone\*\* pattern \`^0\\d{8,9}$\`  
\- If cbm\_id missing → block submit (prefill required)

\#\#\#\# RBAC & Status Gating  
\- Allowed: Gate Staff, Admin  
\- Dispatcher: read-only (cannot submit)  
\- If checkin.status already \`awaiting\_payment\`/\`completed\` → Create blocked (toast \+ do not POST)  
\- If role lacks create permission → show disabled primary \+ tooltip "ไม่มีสิทธิ์" (403)

\#\#\#\# Microcopy (i18n/A11y)  
\- Primary button: \*\*ยืนยันเช็คอิน\*\*  
\- Success toast: \*\*เช็คอินสำเร็จ — รถถูกส่งเข้า awaiting\_payment\*\*  
\- Error toast: \*\*หมายเลขเหรียญซ้ำ กรุณาตรวจสอบ\*\*  
\- Inputs have aria-label and helper text for required patterns

\#\#\#\# Journey Bindings  
\- \`Journey A\`: List row CBM → open \`/cane/check-in/new/cbm\` (prefill) → action ยืนยันเช็คอิน → POST \`/api/cane-checkins\` → PATCH CBM booking → Result: item appears in Tab "เช็คอินแล้ว" (type: โควต้าจองคิว)  
  \- Preconditions: cbm\_id present, coin\_number unique  
  \- On success: emit checkin.created event, update UI

\#\#\#\# Notes  
\- ต้องใช้ Idempotency-Key เพื่อป้องกันการสร้างซ้ำเมื่อ Retry  
\- PATCH CBM booking อาจต้องใช้ If-Match เมื่อ upstream มี ETag

\---

\#\#\# 7.2.4 Check-In (Member — no booking) — Drawer (Create) — \`/cane/check-in/new/member\`  
\*\*Purpose\*\*: สร้าง checkin สำหรับสมาชิกที่ไม่มีการจองคิว

\#\#\#\# Layout  
\- เทมเพลต: \`createDrawer.v2\` · Drawer:right; width=40%

\#\#\#\# ASCII Wireframe  
\`\`\`text  
\+------------------------------------------------------------------------------+  
| H1: เช็คอิน (สมาชิก ไม่มีคิว)                                  \[ ☐ \]\[✕\]     |  
| Sub: กรอกข้อมูลสมาชิกและเงื่อนไขการชำระ                                  |  
\+------------------------------------------------------------------------------+  
| Section: ข้อมูลโควต้า                                                       |  
| | \*\*ค้นหาโควต้า\*\* \[TokenInput search/select\] (field: \*\*quota\_id\*\*)         |  
| | \*\*ทะเบียนรถ\*\* \[Input\] (field: \*\*plate\_no\*\*)                              |  
| | \*\*ชื่อคนขับ\*\* \[Input\] (field: \*\*driver\_name\*\*)                            |  
| | \*\*โทรคนขับ\*\* \[Input\] (field: \*\*driver\_phone\*\*)                            |  
\+------------------------------------------------------------------------------+  
| Section: ข้อมูลการชำระ                                                      |  
| | \*\*งวดที่ 1\*\* \[RadioGroup green\_bill|white\_bill\] (field: \*\*payment\_type\_1st\*\*) |  
| | \*\*งวดที่ 2\*\* \[RadioGroup green\_bill|white\_bill\] (field: \*\*payment\_type\_2nd\*\*) |  
| | \*\*สัดส่วนหนี้ชำระ (%)\*\* \[Slider \+ Input\] (field: \*\*debt\_payment\_percent\*\*) |  
| | \*\*หมายเลขเหรียญ\*\* \[Input\] (field: \*\*coin\_number\*\*)                       |  
| | \*\*หมายเหตุ\*\* \[Textarea\] (field: \*\*notes\*\*)                                |  
\+------------------------------------------------------------------------------+  
| Left: \[ยกเลิก\]                                    Right: \[ยืนยันเช็คอิน\]       |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \[\*\*DrawerHeader\*\*\]  
\- \[\*\*FormLayout\*\*\]  
\- \[\*\*TokenInput\*\*\] (field: \*\*quota\_id\*\*) — searchable quota lookup  
\- \[\*\*Input\*\*\] (plate\_no, driver\_name, driver\_phone)  
\- \[\*\*RadioGroup\*\*\] (payment\_type\_1st, payment\_type\_2nd)  
\- \[\*\*Slider\*\*\] \+ \[\*\*Input\*\*\] (debt\_payment\_percent 0..100)  
\- \[\*\*Input\*\*\] (coin\_number)  
\- \[\*\*Textarea\*\*\] (notes)  
\- Footer buttons: \[\*\*Button\*\* ยกเลิก\], \[\*\*Button\*\* primary ยืนยันเช็คอิน\]

\#\#\#\# Actions / Events & Binding  
\- \[\*\*Button\*\* ยืนยันเช็คอิน\] → validate client → POST \`/api/cane-checkins\`  
  \- Body: { source\_type:'member\_no\_booking', quota\_id, plate\_no, driver\_name, driver\_phone, payment\_type\_1st, payment\_type\_2nd, debt\_payment\_percent, coin\_number, notes }  
  \- Headers: \`Idempotency-Key\`  
  \- On success: status set to checked\_in → auto awaiting\_payment (no PATCH CBM)  
  \- Navigate to List Tab "เช็คอินแล้ว" (type: โควต้าไม่ได้จองคิว) \+ toast success

\#\#\#\# Validation  
\- \*\*quota\_id\*\* required and must resolve to existing quota via search API  
\- \*\*payment\_type\_1st/2nd\*\* required  
\- \*\*debt\_payment\_percent\*\* required, numeric 0..100  
\- \*\*coin\_number\*\* required, unique (partial), max 12  
\- phone pattern \`^0\\d{8,9}$\`

\#\#\#\# RBAC & Status Gating  
\- Gate Staff, Admin: allowed create  
\- Dispatcher: read-only  
\- After created and status → awaiting\_payment: record locked (no manual edit)

\#\#\#\# Microcopy (i18n/A11y)  
\- Hint for debt slider: \*\*ระบุสัดส่วนที่ต้องชำระ (0–100%)\*\*  
\- TokenInput aria-label="ค้นหาโควต้า"

\#\#\#\# Journey Bindings  
\- \`Journey B\`: List → ActionBar Check-In → Choose "ไม่มีคิว (สมาชิก)" → \`/cane/check-in/new/member\` → ยืนยัน → POST \`/api/cane-checkins\` source\_type:'member\_no\_booking' → Result: appears in Tab "เช็คอินแล้ว" (ชนิด โควต้าไม่ได้จองคิว)

\---

\#\#\# 7.2.5 Check-In (Guest / โควต้ากลาง) — Drawer (Create) — \`/cane/check-in/new/guest\`  
\*\*Purpose\*\*: สร้าง checkin สำหรับโควต้ากลาง/Guest (guest\_pool)

\#\#\#\# Layout  
\- เทมเพลต: \`createDrawer.v2\` · Drawer:right; width=40%

\#\#\#\# ASCII Wireframe  
\`\`\`text  
\+------------------------------------------------------------------------------+  
| H1: เช็คอิน (โควต้ากลาง)                                      \[ ☐ \]\[✕\]     |  
| Sub: guest\_flag \= true (readonly)                                            |  
\+------------------------------------------------------------------------------+  
| Section: ข้อมูลคันรถ                                                         |  
| | \*\*ทะเบียนรถ\*\* \[Input\] (field: \*\*plate\_no\*\*)                              |  
| | \*\*ชื่อคนขับ\*\* \[Input\] (field: \*\*driver\_name\*\*)                            |  
| | \*\*โทรคนขับ\*\* \[Input\] (field: \*\*driver\_phone\*\*)                            |  
\+------------------------------------------------------------------------------+  
| Section: การชำระ                                                            |  
| | \*\*งวดที่ 1\*\* \[RadioGroup\] (field: \*\*payment\_type\_1st\*\*)                    |  
| | \*\*งวดที่ 2\*\* \[RadioGroup\] (field: \*\*payment\_type\_2nd\*\*)                    |  
| | \*\*หมายเลขเหรียญ\*\* \[Input\] (field: \*\*coin\_number\*\*)                       |  
| | \*\*หมายเหตุ\*\* \[Textarea\]                                                   |  
| | \*\*guest\_flag\*\* \[Input readonly=true\] (field: \*\*guest\_flag\*\*)              |  
\+------------------------------------------------------------------------------+  
| Left: \[ยกเลิก\]                                    Right: \[ยืนยันเช็คอิน\]       |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \[\*\*DrawerHeader\*\*\]  
\- \[\*\*FormLayout\*\*\]  
\- \[\*\*Input\*\*\] (plate\_no, driver\_name, driver\_phone)  
\- \[\*\*RadioGroup\*\*\] (payment\_type\_1st/2nd)  
\- \[\*\*Input\*\*\] (coin\_number)  
\- \[\*\*Input\*\* readonly\] (guest\_flag=true)  
\- \[\*\*Textarea\*\*\] notes  
\- Footer: \[\*\*Button\*\* ยกเลิก\], \[\*\*Button\*\* primary ยืนยันเช็คอิน\]

\#\#\#\# Actions / Events & Binding  
\- \[\*\*Button\*\* ยืนยันเช็คอิน\] → POST \`/api/cane-checkins\`  
  \- Body: { source\_type:'guest\_pool', plate\_no, driver\_name, driver\_phone, payment\_type\_1st, payment\_type\_2nd, coin\_number, guest\_flag:true, notes }  
  \- Headers: \`Idempotency-Key\`  
  \- On success: status checked\_in → auto awaiting\_payment; show toast \+ appear in Tab "เช็คอินแล้ว" (ชนิด โควต้ากลาง)

\#\#\#\# Validation  
\- plate\_no, driver\_name, driver\_phone required  
\- payment\_type\_1st/2nd required  
\- coin\_number required unique  
\- phone pattern validation

\#\#\#\# RBAC & Status Gating  
\- Gate Staff & Admin allowed  
\- No CBM patch in this flow

\#\#\#\# Microcopy (i18n/A11y)  
\- guest\_flag tooltip: \*\*โควต้ากลาง (Guest) — ไม่ผูกกับ CBM หรือ quota\_id\*\*  
\- Error message for coin conflict: \*\*หมายเลขเหรียญไม่ว่าง โปรดเลือกหมายเลขอื่น\*\*

\#\#\#\# Journey Bindings  
\- \`Journey C\`: List → Check-In → เปิด \`/cane/check-in/new/guest\` → ยืนยัน → POST → awaiting\_payment with guest\_flag=true

\---

\#\#\# 7.2.6 Scan QR — Modal — \`/cane/check-in/scan\`  
\*\*Purpose\*\*: สแกน QR เพื่อเติม \`cbm\_id\` อัตโนมัติ (manual fallback ให้กรอกเอง)

\#\#\#\# Layout  
\- เทมเพลต: \`deleteConfirm.v1\` (modal) ปรับใช้เป็น Camera modal; center modal width≈480px

\#\#\#\# ASCII Wireframe  
\`\`\`text  
\+------------------------------------------------------------------------------+  
|                           สแกน QR เพื่อเช็คอิน                                |  
\+------------------------------------------------------------------------------+  
| \[ Camera Preview Area \]                                                       |  
|  (กล้อง/preview \+ overlay)                                                    |  
|                                                                              |  
| Parsed result: \*\*CBM-xxxxxxx\*\*                                                |  
| หรือใส่รหัสด้วยตนเอง: \[ Input cbm\_id \]                                       |  
\+------------------------------------------------------------------------------+  
|                                               \[ ปิด \]   \[ ใช้ค่านี้ \]         |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \[\*\*ModalDialog\*\*\]  
\- \[\*\*CameraPreview\*\*\] (component created)  
\- \[\*\*QRScanner\*\*\] utility event → emits parsed cbm\_id  
\- \[\*\*Input\*\*\] manual cbm\_id fallback  
\- Buttons: \[\*\*Button\*\* ปิด\], \[\*\*Button\*\* ใช้ค่านี้ (primary)\]

\#\#\#\# Actions / Events & Binding  
\- On scan success: parsed cbm\_id → prefill and:  
  \- Option A: auto-close modal and open Drawer \`/cane/check-in/new/cbm?cbm\_id={cbm\_id}\` (preferred)  
  \- Option B: emit event fill field in open Drawer (if drawer already open)  
\- Manual fallback: user enters cbm\_id → press ใช้ค่านี้ → open \`/cane/check-in/new/cbm?cbm\_id={cbm\_id}\`

\#\#\#\# Validation  
\- Validate parsed cbm\_id format \`^CBM-\\d{4}-\\d{7}$\` before proceed  
\- Camera permission denied → show fallback input \+ help copy

\#\#\#\# RBAC & Status Gating  
\- Gate Staff allowed to use scanner  
\- External QR Scanner integration permitted as system actor

\#\#\#\# Microcopy (i18n/A11y)  
\- CameraPreview aria-label="กล้องสแกน QR"  
\- Errors: \*\*ไม่พบ QR ที่อ่านได้ กรุณาลองใหม่หรือกรอกด้วยตนเอง\*\*

\#\#\#\# Journey Bindings  
\- \`Journey A\`: Scan QR → prefill cbm\_id → open CBM Drawer → continue Journey A

\---

\#\#\# 7.2.7 Confirm Void — Modal — \`/cane/check-in/{id}/void\`  
\*\*Purpose\*\*: ให้ผู้ใช้งานระบุเหตุผลแล้ว Void เช็คอิน (status → voided และคืน coin\_number)

\#\#\#\# Layout  
\- เทมเพลต: \`deleteConfirm.v1\` (Modal:center; width≈480px)

\#\#\#\# ASCII Wireframe  
\`\`\`text  
\+------------------------------------------------------------------------------+  
|                           ⚠️  ยืนยันยกเลิกเช็คอิน                             |  
\+------------------------------------------------------------------------------+  
| กรุณาระบุเหตุผลการยกเลิกสำหรับ \*\*CHK-xxxx-xxxxxx\*\*                          |  
|                                                                              |  
| \*\*เหตุผล\*\* \[Textarea\] (field: \*\*reason\*\*)                                    |  
|                                                                              |  
\+------------------------------------------------------------------------------+  
|                                               \[ ยกเลิก \]   \[ Void (ยืนยัน) \] |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- \[\*\*ModalDialog\*\*\]  
\- \[\*\*Textarea\*\*\] (field: \*\*reason\*\*, required)  
\- Buttons: \[\*\*Button\*\* ยกเลิก\], \[\*\*Button\*\* primary Void\]

\#\#\#\# Actions / Events & Binding  
\- \[\*\*Button\*\* Void\] → client-validate reason → POST \`/api/cane-checkins/void\`  
  \- Body: { checkin\_id: {id}, reason }  
  \- Headers: \`If-Match: {etag}\` (recommended to detect concurrent state)  
  \- On success: status → voided; side-effect: release coin\_number  
  \- Update UI: remove from Tab "เช็คอินแล้ว" or mark as voided (depending display policy) \+ toast success  
\- Error 409/412 → show appropriate error dialog (cannot void completed / ETag mismatch)

\#\#\#\# Validation  
\- \*\*reason\*\* required, min length 5 (suggested)  
\- Precondition: current status \!= completed

\#\#\#\# RBAC & Status Gating  
\- Gate Staff: can initiate Void  
\- Logistics Supervisor: may be required to approve (policy unclear — treat as conditional). If approval required, POST returns 202 pending\_approval (not defined in inputs) — record in Warnings  
\- Admin: can Void and override approvals

\#\#\#\# Microcopy (i18n/A11y)  
\- Modal title: \*\*ยืนยันยกเลิกเช็คอิน\*\*  
\- Void button label: \*\*Void\*\*  
\- Success toast: \*\*ยกเลิกเช็คอินเรียบร้อย — หมายเลขเหรียญคืนสิทธิ์แล้ว\*\*

\#\#\#\# Journey Bindings  
\- \`Journey D\`: Tab "เช็คอินแล้ว" → select row → Modal Confirm Void → Void → POST \`/api/cane-checkins/void\` → status voided; Preconditions: status \!= completed

\#\#\#\# Notes  
\- ต้องบันทึก actor/timestamp/reason ใน audit trail  
\- coin\_number คืนสิทธิ์ต้องทำเป็น atomic operation (ล็อก DB) เพื่อป้องกัน race

\---

\#\# 7.3 Screen Components (React-friendly names)  
\- Pages: CheckinListPage, CheckinCreateModeModal, CheckinCBMDrawer, CheckinMemberDrawer, CheckinGuestDrawer, CheckinScanModal, CheckinVoidModal  
\- Composables: CheckinFilterBar, CheckinTable, PaginationBar, BulkActionsBar, CheckinForm, FormActionBar, FormGuard, ToastHost, ActivityLog, StatusActions, ApprovalActions, AttachmentPanel  
\- New components created (sheet): \[\*\*RadioGroup\*\*\], \[\*\*CameraPreview\*\*\], \[\*\*QRScanner\*\*\], \[\*\*Slider\*\*\], \[\*\*TokenInput\*\*\]

\#\# 7.4 Client Flows (Create/Update/Delete/Restore/Bulk)  
\- Create (CBM):  
  \- client-validate → POST \`/api/cane-checkins\` (+Idempotency-Key)  
  \- On 201: server sets checked\_in → auto awaiting\_payment; PATCH \`/api/cbm/bookings/{cbm\_id}/status\` {phase\_cut\_transport:'awaiting\_payment'}  
\- Create (Member/Guest):  
  \- POST \`/api/cane-checkins\` (+Idempotency-Key) → awaiting\_payment  
\- Void:  
  \- POST \`/api/cane-checkins/void\` {checkin\_id, reason} (+If-Match) → 200 → status voided; release coin\_number  
\- Update:  
  \- GET \`/api/cane-checkins/{id}\` (read ETag) → PATCH \`/api/cane-checkins/{id}\` (+If-Match) → 200 | 412  
\- Bulk:  
  \- Not defined in Page Definitions (Warnings if required)

\#\# 7.5 Microcopy / Empty / Error States (i18n & A11y)  
\- Empty list: \*\*ยังไม่มีรายการที่ต้องส่ง\*\*  
\- Empty checkin list: \*\*ยังไม่มีรายการเช็คอินแล้ว\*\*  
\- 403: \*\*คุณไม่มีสิทธิ์ดำเนินการนี้\*\*  
\- 409: \*\*เกิดความขัดแย้ง — หมายเลขเหรียญถูกใช้งานแล้ว\*\*  
\- 412: \*\*ข้อมูลเปลี่ยนแปลง กรุณาดึงข้อมูลล่าสุดก่อนดำเนินการ\*\*

\#\# 7.6 Journey ↔ Page Crosswalk (แนะนำ)  
\- Journey A → CheckinListPage(Tab "ต้องส่ง") → CheckinCBMDrawer (ยืนยัน) → POST /api/cane-checkins \+ PATCH /api/cbm/bookings/{cbm\_id}/status  
\- Journey B → CheckinListPage → CheckinCreateModeModal → CheckinMemberDrawer → POST /api/cane-checkins {member\_no\_booking}  
\- Journey C → CheckinCreateModeModal → CheckinGuestDrawer → POST /api/cane-checkins {guest\_pool}  
\- Journey D → CheckinListPage(Tab "เช็คอินแล้ว") → CheckinVoidModal → POST /api/cane-checkins/void  
\- Journey E → CheckinListPage search/filters → GET /api/cane-checkins?{q,filters,sort}

\#\#\# Warnings (ข้อควรทราบ)  
\- template\_source per page:  
  \- List page uses \`packingList.v1\` (template\_source=packingList.v1)  
  \- Drawers use \`createDrawer.v2\` (template\_source=createDrawer.v2)  
  \- View/Small modal uses \`deleteConfirm.v1\` (template\_source=deleteConfirm.v1)  
  \- หากต้องการ layout 2-pane / KPI row เพิ่มเติม → ต้องใช้เทมเพลตใหม่ (template\_source=custom)  
\- unknown tokens from templates (ไม่ได้มีค่าในอินพุต): \`{{subtitle}}\`, \`{{filter\_sum}}\`, \`{{import\_label}}\`, \`{{col\_ref}}\`, \`{{col\_loc}}\`, \`{{col\_qty}}\`, \`{{col\_wt}}\`, \`{{col\_updated}}\`, \`{{range\_text}}\`, \`{{page}}\` — แทนด้วยข้อความสืบเนื่อง/placeholder ใน ASCII ข้างต้น  
\- missing / newly created components (ถูกเพิ่มไปยังชีต): \*\*RadioGroup\*\*, \*\*CameraPreview\*\*, \*\*QRScanner\*\*, \*\*Slider\*\*, \*\*TokenInput\*\* (status=\`Not in development\`) — โปรดตรวจสอบทีม UI/Frontend เพื่อ implement  
\- Approval flow for Void: A2 ระบุ Logistics Supervisor อาจต้องอนุมัติ — แต่ endpoints/flow ไม่ชัด (ต้องกำหนด approve API หรือ workflow) (Warnings: approval\_flow\_unset)  
\- Payment → completed transition API/contract ไม่ได้ระบุ (Warnings: payment\_webhook\_missing)  
\- Row-level scoping (branch/gate) ไม่ได้ระบุ → ถ้าต้องการจำกัดมุมมองให้ระบุ tenant/gate filters (Warnings: scope\_not\_specified)  
\- Rule conformance:  
  \- All ASCII ไลน์ประมาณ 76–84 คอลัมน์ (ตามเทมเพลต)  
  \- Component names normalized; หากต้องเพิ่ม component ใหม่ ให้ทีม UI ลงรายการใน component library และแจ้งสถานะการพัฒนา (รายการสร้างไว้แล้ว)  
\- หากต้องการ bulk actions / approve/reject flows หรือ PDF export ให้เพิ่มข้อกำหนด API และ UI templates เพิ่มเติม (Warnings: feature\_extension\_requested)

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

\# Journey  
\#\#\# Journey: สร้างและยืนยันเช็คอิน (CBM) (Actor: Gate Staff)  
\*\*Entry:\*\* จากหน้า List \`/cane/check-in\` → แถว CBM เลือกปุ่ม Check-In หรือจาก Scan QR → เปิด Drawer \`/cane/check-in/new/cbm?cbm\_id={cbm\_id}\`    
\*\*Preconditions:\*\* ผู้ใช้มีสิทธิ์ Create (Gate Staff/ Admin); แถว CBM มี \`cbm\_id\` ที่ถูกต้อง; ไม่มี checkin ที่ยังไม่จบ ใช้ \`coin\_number\` เดียวกัน (server-side enforced)    
\*\*Exit / Postconditions:\*\* เรียก \`POST /api/cane-checkins\` (status → checked\_in → awaiting\_payment), เรียก \`PATCH /api/cbm/bookings/{cbm\_id}/status\` \`{phase\_cut\_transport: "awaiting\_payment"}\`; อีเวนต์ที่ยิง: \`cane.checkin.created\` (payload ใน Telemetry)

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*CheckinListPage / Row Check-In\*\* — ผู้ใช้กดปุ่ม Check-In บนแถว CBM    
   \- Trigger: NAV → เปิด Drawer (\`NAV\`) ไปที่ \`/cane/check-in/new/cbm?cbm\_id={cbm\_id}\`    
   \- map\_in: \`{ cbm\_id }\` (จาก row)    
   \- assert: client-side ตรวจว่า \`row.source\_type \== "cbm\_booking"\` และผู้ใช้มีสิทธิ์สร้าง (Gate Staff)    
   \- System: เปิด Drawer และ prefill ฟอร์มด้วยข้อมูล CBM (plate\_no, driver\_name, driver\_phone, quota\_id ถ้ามี) โดย client ดึงข้อมูลแถว (no new server call required) หรือเรียก CBM listing ถ้าจำเป็น    
   \- map\_out: — (prefill only)    
   \- UI Feedback: Drawer เปิด, focus ที่ \`coin\_number\` input; ปุ่ม primary ไม่ active จนกว่า validation ผ่าน    
   \- Navigation/State: ไม่มี navigation อื่น ๆ    
   \- Field & Copy Checklist:  
     \- Fields ที่ต้องกรอก:  
       \- \`coin\_number | หมายเลขเหรียญ | string | required: yes | default: '' | unit: none | validators: maxLength=12, regex=^\[\\w\\-\]+$ (suggest) | helper\_text\_th: "กรอกหมายเลขเหรียญ (สูงสุด 12 ตัวอักษร)" | error\_copy\_th: "กรอกหมายเลขเหรียญหรือเปลี่ยนหมายเลข" | visibility: editable\`  
       \- \`notes | หมายเหตุ | text | required: no | default: '' | validators: maxLength=500 | helper\_text\_th: "รายละเอียดเพิ่มเติม (ถ้ามี)" | visibility: editable\`  
     \- Fields ที่ต้องแสดง (read-only):  
       \- \`cbm\_id | รหัส CBM | visibility(read-only) | source(api/row)\`  
       \- \`plate\_no | ทะเบียนรถ | visibility(read-only) | source(api/row)\`  
       \- \`driver\_name | ชื่อคนขับ | visibility(read-only) | source(api/row)\`  
       \- \`driver\_phone | โทรคนขับ | visibility(read-only) | source(api/row)\`  
     \- UI Copy / Messages:  
       \- Helper: "ตรวจสอบหมายเลขเหรียญก่อนยืนยัน — ห้ามใช้หมายเลขซ้ำกับรายการที่ยังไม่จบ"  
       \- Confirm CTA: "ยืนยันเช็คอิน"  
       \- Validation copy: 409 → "หมายเลขเหรียญซ้ำ กรุณาเลือกหมายเลขอื่นหรือตรวจสอบรายการที่ยังไม่จบ"  
       \- Empty/loading: "กำลังดึงข้อมูล CBM..." / retry button "ลองอีกครั้ง"  
     \- data-test-id ที่เกี่ยวข้อง:  
       \- \`btn-row-checkin-cbm\` (จาก List row) — TODO: เพิ่มใน Page Definitions  
       \- \`drawer-checkin-cbm\` (Drawer root) — TODO: เพิ่มใน Page Definitions  
       \- \`input-coin-number\` (field) — TODO: เพิ่มใน Page Definitions  
       \- \`btn-confirm-checkin-cbm\` (primary) — TODO: เพิ่มใน Page Definitions  
     \- a11y:  
       \- focus order: drawer opened → cbm\_id(readonly) → plate\_no → driver\_name → driver\_phone → coin\_number (first editable) → notes → confirm button  
       \- aria-labels on inputs; hotkeys: Ctrl+Enter \= submit, Esc \= close  
2\) \*\*CheckinCBMDrawer / coin\_number Input\*\* — ผู้ใช้กรอก \`coin\_number\` และกด ยืนยันเช็คอิน    
   \- Trigger: \`FN-GET-/api/cane-checkins/validate\` (optional quick-validate) then \`POST /api/cane-checkins\`    
   \- map\_in (validate): \`{ coin\_number }\` (only)    
   \- assert: client-side เช็ครูปแบบ length\<=12; ถ้ามีระบบ validate ให้รันก่อนส่ง POST    
   \- System:  
     \- (Optional) เรียก \`GET /api/cane-checkins/validate?coin\_number={coin}\` → ถ้า available=true \= true ให้ดำเนิน; ถ้า false ให้โชว์ 409 UI  
     \- สร้าง idempotency-key: \`ui:{user.id}:create\_checkin:{hash(coin\_number|cbm\_id|plate\_no)}\`; ใส่ header \`X-Idempotency-Key\`  
     \- เรียก \`POST /api/cane-checkins\` body:  
       {  
         "source\_type":"cbm\_booking",  
         "cbm\_id":"{cbm\_id}",  
         "plate\_no":"{plate\_no}",  
         "driver\_name":"{driver\_name}",  
         "driver\_phone":"{driver\_phone}",  
         "coin\_number":"{coin\_number}",  
         "notes":"{notes}"  
       }  
     \- บนความสำเร็จ (201) ระบบจะคืนค่า \`checkin\_id\`, \`status\` (awaiting\_payment), \`checkin\_time\` และ ETag (optional)    
     \- ต่อไประบบจะเรียก \`PATCH /api/cbm/bookings/{cbm\_id}/status\` body \`{ "phase\_cut\_transport": "awaiting\_payment" }\` (side-effect/integration). หาก upstream ต้องการ \`If-Match\` ให้ใส่ถ้ามี ETag จาก upstream (not provided in current flow)    
   \- map\_out: \`{ checkin\_id, status, checkin\_time, coin\_number }\` — นำไปแสดง toast และรีเฟรช List    
   \- UI Feedback: เมื่อเรียก POST → ปุ่มเป็น loading skeleton; On success → toast success "เช็คอินสำเร็จ — รถเข้า awaiting\_payment" ; focus ไปที่ toast / แสดง summary drawer หรือนำทางไป Detail \`/cane/check-in/{checkin\_id}\`    
   \- Navigation/State: ปิด Drawer → reload List หรือ navigate to Detail; invalidate list cache (GET /api/cane-checkins)    
   \- Field & Copy Checklist (บน submit step):  
     \- Confirm copy: "ยืนยันเช็คอิน — หมายเลขเหรียญ {coin\_number}" (confirm dialog only if network offline or duplicate risk)    
     \- data-test-id: \`request-post-create-checkin-cbm\`, \`toast-checkin-success\`, \`link-detail-after-create\` — TODO: เพิ่มใน Page Definitions  
     \- a11y: aria-live region for toast; keyboard accessible confirm  
3\) System-side effect (sequenced) — PATCH CBM booking    
   \- Trigger: SIDE\_EFFECT (server) invoked after create (sequence)    
   \- map\_in: \`{ cbm\_id }\` (server owned)    
   \- assert: server ensures cbm booking in dispatchable state    
   \- System: call \`PATCH /api/cbm/bookings/{cbm\_id}/status\` with body \`{ "phase\_cut\_transport":"awaiting\_payment" }\` — if upstream returns INVALID\_STATE → log & surface error to user (toast "อัปเดตสถานะ CBM ล้มเหลว") and audit record    
   \- map\_out: \`{ cbm\_id, booking\_status }\`    
   \- UI Feedback: if PATCH fails with INVALID\_STATE or 412 → show modal "CBM state changed — ดึงข้อมูลล่าสุด" with CTA to refresh    
   \- Navigation/State: ensure list shows item in "เช็คอินแล้ว" tab after success

\#\#\#\# Variants & Exceptions  
\- Step 2 → VALIDATION:VALIDATION\_FAILED (server returns VALIDATION\_FAILED for missing/format)    
  \- Show inline error at \`input-coin-number\` with copy from API \`details\` or fallback "หมายเลขเหรียญไม่ถูกต้อง" and focus input.  
\- Step 2 → BUSINESS:VALIDATION\_FAILED (coin duplicate) — API returns VALIDATION\_FAILED with details \`duplicate for active checkin\` or HTTP 409    
  \- Show modal with conflicting record summary (if API provides) and options: Change coin / View conflicting record / Retry. Focus coin input.  
\- Step 2 → CONFLICT (409 on POST): Retry with same idempotency key is allowed; client should surface message "ความขัดแย้ง — ตรวจสอบหมายเลขเหรียญ" and allow retry. Use same \`X-Idempotency-Key\`.  
\- Step 2 → DEPENDENCY/IO/TIMEOUT: network 5xx or 429 → exponential backoff retry (3 attempts) and show toast "เชื่อมต่อล้มเหลว กำลังลองใหม่" and allow manual retry button.  
\- Access Control: If user lacks permission → primary button disabled with tooltip "ไม่มีสิทธิ์ดำเนินการ" (403). Server will also return 403 if attempted.

\#\#\#\# Telemetry & Audit  
\- Events:  
  \- \`checkin.create.attempt\` payload: { actor\_id, cbm\_id, plate\_no, coin\_number\_hash, correlation\_id, idempotency\_key }  
  \- \`checkin.create.success\` payload: { actor\_id, checkin\_id, status, cbm\_id, coin\_number, correlation\_id }  
  \- \`cbm.patch\_status.called\` payload: { cbm\_id, result\_status, correlation\_id }  
\- Audit Fields to persist: actor\_id, role, timestamp, correlation\_id, idempotency\_key, request body (masked PII: driver\_phone masked in logs), reason (if any), resource ids

\#\#\#\# Test Hooks  
\- data-test-id:  
  \- \`btn-row-checkin-cbm\`, \`drawer-checkin-cbm\`, \`input-coin-number\`, \`btn-confirm-checkin-cbm\`, \`toast-checkin-success\` — (mark: TODO to add in Page Definitions)  
\- Acceptance (Gherkin ย่อ):  
  \- Given a dispatchable CBM row and Gate Staff logged in    
  \- When user opens CBM Check-In drawer, fills coin\_number and submits    
  \- Then API \`POST /api/cane-checkins\` is called with required body and header X-Idempotency-Key and List shows new checkin in awaiting\_payment

\#\#\#\# Assumptions & Confidence  
\- สมมติฐาน: upstream CBM PATCH accepts unauthenticated ETag optional → Confidence: Medium    
\- สมมติฐาน: \`GET /api/cane-checkins/validate\` สามารถใช้ก่อน POST → Confidence: High (optional endpoint provided)

\---

\#\#\# Journey: สร้างและยืนยันเช็คอิน (Member — ไม่มีคิว) (Actor: Gate Staff)  
\*\*Entry:\*\* จากหน้า List → ปุ่ม Check-In (primary) → Choose mode → เลือก "ไม่มีคิว (สมาชิก)" → Drawer \`/cane/check-in/new/member\`    
\*\*Preconditions:\*\* ผู้ใช้มีสิทธิ์สร้าง; มี \`quota\_id\` ที่ค้นพบจาก TokenInput    
\*\*Exit / Postconditions:\*\* เรียก \`POST /api/cane-checkins\` with source\_type=member\_no\_booking → status → awaiting\_payment; event \`cane.checkin.created\`

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*CheckinCreateModeModal / เลือก member\_no\_booking\*\* — ผู้ใช้เลือกโหมดแล้ว Next    
   \- Trigger: NAV → \`/cane/check-in/new/member\`    
   \- map\_in: none (mode selection only)    
   \- assert: user has create permission    
   \- System: เปิด Drawer ฟอร์มสร้างแบบ member    
   \- data-test-id: \`modal-choose-mode\`, \`option-member-no-booking\` — TODO: add  
2\) \*\*CheckinMemberDrawer / กรอกฟอร์ม\*\* — ผู้ใช้กรอก quota\_id, plate\_no, driver\_name, driver\_phone, payment\_type\_1st/2nd, debt\_payment\_percent, coin\_number, notes    
   \- Trigger: POST \`/api/cane-checkins\`    
   \- map\_in: {  
       "source\_type":"member\_no\_booking",  
       "quota\_id",  
       "plate\_no",  
       "driver\_name",  
       "driver\_phone",  
       "payment\_type\_1st",  
       "payment\_type\_2nd",  
       "debt\_payment\_percent",  
       "coin\_number",  
       "notes"  
     } (ส่งเฉพาะฟิลด์ที่ user ให้; ห้ามส่ง totals ที่ server ต้องคำนวณ)    
   \- assert: client validates required fields, \`debt\_payment\_percent\` in 0..100, phone pattern \`^0\\d{8,9}$\`; quota\_id resolves via TokenInput (client ensures selected item has id)    
   \- System: generate idempotency-key: \`ui:{user.id}:create\_checkin:{hash(coin\_number|quota\_id|plate\_no)}\`; send POST with header \`X-Idempotency-Key\`    
   \- map\_out: \`{ checkin\_id, status, coin\_number }\`    
   \- UI Feedback: show inline validation errors; on success toast "เช็คอินสำเร็จ" and navigate to Detail or refresh List; disable form while pending    
   \- Navigation/State: invalidate list cache, show item in Tab "เช็คอินแล้ว"    
   \- Field & Copy Checklist:  
     \- Fields ที่ต้องกรอก:  
       \- \`quota\_id | โควต้า | token | required: yes | validators: must resolve | helper\_text\_th: "ค้นหาและเลือกโควต้า" | visibility: editable\`  
       \- \`payment\_type\_1st | งวดที่ 1 | enum(green\_bill|white\_bill) | required: yes\`  
       \- \`payment\_type\_2nd | งวดที่ 2 | enum | required: yes\`  
       \- \`debt\_payment\_percent | สัดส่วนหนี้ชำระ (%) | integer | required: yes | min:0 max:100 | helper\_text\_th: "0–100" | visibility: editable\`  
       \- plus \`coin\_number\`, \`plate\_no\`, \`driver\_name\`, \`driver\_phone\`, \`notes\` similar to CBM  
     \- Fields ที่ต้องแสดง: none additional  
     \- UI Copy / Messages: debt slider helper, validation messages for percent (use \`DEBT\_PERCENT\_OUT\_OF\_RANGE\` for server errors)  
     \- data-test-id: \`drawer-checkin-member\`, \`input-quota-token\`, \`input-debt-percent\`, \`input-coin-number-member\`, \`btn-confirm-checkin-member\` — TODO: add  
     \- a11y: focus order: quota → plate\_no → driver → phone → payment types → debt → coin → notes → submit  
3\) System response handling same as CBM (201, toast, list refresh)

\#\#\#\# Variants & Exceptions  
\- Server returns \`DEBT\_PERCENT\_OUT\_OF\_RANGE\` → show inline validation next to \`debt\_payment\_percent\` with API message and prevent submit  
\- \`VALIDATION\_FAILED\` for missing quota\_id → highlight quota token input and focus it  
\- \`CONFLICT\` (coin duplicate) → same handling as CBM: show conflict modal/options; allow retry with same idempotency key

\#\#\#\# Telemetry & Audit  
\- Events:  
  \- \`checkin.create.attempt\` with payload including \`source\_type:member\_no\_booking\`, hashed sensitive fields  
  \- \`checkin.create.success\`  
\- Audit fields recorded

\#\#\#\# Test Hooks & Acceptance  
\- data-test-id list as above; TODO to add to Page Definitions    
\- Gherkin: Given Gate Staff, When fill member checkin valid data and submit, Then POST called and list updated

\#\#\#\# Assumptions & Confidence  
\- TokenInput quota lookup exists and returns \`quota\_id\` → Confidence: High    
\- Server enforces uniqueness of coin\_number → Confidence: High

\---

\#\#\# Journey: สร้างและยืนยันเช็คอิน (Guest / โควต้ากลาง) (Actor: Gate Staff)  
\*\*Entry:\*\* จาก Choose Mode → เลือก "โควต้ากลาง" → Drawer \`/cane/check-in/new/guest\`    
\*\*Preconditions:\*\* ผู้ใช้มีสิทธิ์; guest\_flag true (read-only)    
\*\*Exit / Postconditions:\*\* POST \`/api/cane-checkins\` with source\_type=guest\_pool, guest\_flag=true → status awaiting\_payment

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Choose Mode → Guest\*\* — open guest drawer    
   \- Trigger: NAV to \`/cane/check-in/new/guest\`    
   \- data-test-id: \`option-guest-pool\`, \`drawer-checkin-guest\` — TODO: add  
2\) \*\*CheckinGuestDrawer / กรอกฟอร์ม\*\* — plate\_no, driver\_name, driver\_phone, payment types, coin\_number, notes (guest\_flag readonly true)    
   \- Trigger: POST \`/api/cane-checkins\`    
   \- map\_in:  
     {  
       "source\_type":"guest\_pool",  
       "plate\_no",  
       "driver\_name",  
       "driver\_phone",  
       "payment\_type\_1st",  
       "payment\_type\_2nd",  
       "coin\_number",  
       "guest\_flag": true,  
       "notes"  
     }    
   \- assert: client validates phone, coin length, required payment types    
   \- System: generate idempotency-key \`ui:{user.id}:create\_checkin:{hash(coin\_number|plate\_no)}\`; POST with header    
   \- map\_out: \`{ checkin\_id, status, coin\_number }\`    
   \- UI Feedback: success toast, show in list    
   \- Field & Copy Checklist:  
     \- \`guest\_flag | โควต้ากลาง | boolean | required: yes | default: true | visibility: read-only | helper\_text\_th: "โควต้ากลาง (Guest) — ไม่ผูกกับ CBM/Quota"\`  
     \- Other fields similar to member  
     \- data-test-id: \`input-coin-number-guest\`, \`btn-confirm-checkin-guest\` — TODO: add

\#\#\#\# Variants & Exceptions  
\- coin duplicate → same handling as others  
\- phone invalid → inline error

\#\#\#\# Telemetry & Audit  
\- \`checkin.create.success\` with source\_type guest\_pool

\#\#\#\# Assumptions & Confidence  
\- guest\_flag must be true server-side — Confidence: High

\---

\#\#\# Journey: ดูรายละเอียดเช็คอิน (Detail) (Actor: Gate Staff / Dispatcher / Supervisor)  
\*\*Entry:\*\* จาก List คลิกแถว → เปิด Drawer Detail \`/cane/check-in/{checkin\_id}\` หรือ deeplink \`/cane/check-in/{id}\`    
\*\*Preconditions:\*\* ผู้ใช้มีสิทธิ์ view; \`checkin\_id\` ถูกต้อง    
\*\*Exit / Postconditions:\*\* แสดงข้อมูลรายละเอียด, ETag ใส่ใน header ของ response; ถ้าต้องการแก้ไขจะใช้ PATCH with If-Match

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*CheckinListPage / Row Click\*\* — ผู้ใช้คลิกเพื่อดูรายละเอียด    
   \- Trigger: GET \`/api/cane-checkins/{checkin\_id}\` (NAV)    
   \- map\_in: \`{ checkin\_id }\`    
   \- assert: none (server will validate)    
   \- System: เรียก GET; response includes body และ \`ETag\` header (e.g., \`"W/\\"v123\\""\`). UI แสดง fields as KeyValue    
   \- map\_out: full detail JSON (see API 8.2)    
   \- UI Feedback: show skeleton while loading; on 404 show toast "ไม่พบรายการนี้" และ navigate back to list    
   \- Navigation/State: open detail drawer; store ETag in client state for future PATCH/void    
   \- Field & Copy Checklist:  
     \- Fields to show (read-only): checkin\_id, source\_type, cbm\_id, quota\_id, plate\_no, driver\_name, driver\_phone (partial mask in some contexts), coin\_number, entry\_channel, payment\_type\_1st, payment\_type\_2nd, debt\_payment\_percent (if present), checkin\_time, status, guest\_flag, notes, created\_by, created\_at, updated\_by, updated\_at  
     \- data-test-id: \`drawer-checkin-detail\`, \`detail-field-coin-number\`, \`detail-btn-edit\`, \`detail-etag\` — TODO: add  
     \- a11y: focus trap in drawer; first focus on H1 title; Esc closes drawer  
2\) \*\*Edit Guard\*\* — ถ้าผู้ใช้กด Edit (if allowed)  
   \- Trigger: NAV → \`/cane/check-in/:id/edit\` and GET detail first for ETag    
   \- map\_in: \`{ checkin\_id }\`    
   \- assert: status allows edit (editable only when status permits, per API: editable only when status permits; precondition client-side: status \== "checked\_in" maybe)    
   \- System: If status disallows edit, disable Edit button client-side and server will return 403/INVALID\_STATE if tried  
   \- map\_out: ETag saved for PATCH    
   \- data-test-id: \`detail-btn-edit\` — TODO: add

\#\#\#\# Variants & Exceptions  
\- GET \`/api/cane-checkins/{id}\` → 404 \`NOT\_FOUND\` → show toast and navigate to List  
\- After fetching, attempting PATCH without current ETag → server returns 412 \`CONFLICT\_UPDATE\_STALE\` → client should re-fetch and show merge dialog

\#\#\#\# Telemetry & Audit  
\- Events:  
  \- \`checkin.view.detail\` payload: { actor\_id, checkin\_id, correlation\_id }  
\- Audit: read action recorded

\#\#\#\# Test Hooks & Acceptance  
\- data-test-id as above; TODO to add

\#\#\#\# Assumptions & Confidence  
\- API returns ETag header reliably → Confidence: Medium (API docs say includes ETag but in list may be optional)

\---

\#\#\# Journey: แก้ไขเช็คอิน (Edit) (Actor: Gate Staff / Admin)  
\*\*Entry:\*\* จาก Detail คลิก Edit → route \`/cane/check-in/:id/edit\`    
\*\*Preconditions:\*\* status อยู่ในสถานะที่อนุญาตให้แก้ไข (not awaiting\_payment/completed); client has latest ETag; user has edit permission    
\*\*Exit / Postconditions:\*\* PATCH \`/api/cane-checkins/{checkin\_id}\` with header \`If-Match: "\<etag\>"\` → updated\_at/updated\_by set

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*CheckinDetail / Edit Click\*\* — User clicks Edit    
   \- Trigger: NAV → open Edit Drawer; client ensures has \`ETag\` from previous GET    
   \- map\_in: \`{ checkin\_id, etag }\`    
   \- assert: client checks \`status\` is editable; if not, disable Edit and show tooltip    
   \- System: populate form with editable fields (\`plate\_no\`, \`driver\_name\`, \`driver\_phone\`, \`notes\`) per API 8.4    
   \- data-test-id: \`btn-edit-checkin\`, \`drawer-edit-checkin\` — TODO  
2\) \*\*Edit Drawer / Submit\*\* — User submits changes    
   \- Trigger: PATCH \`/api/cane-checkins/{checkin\_id}\` with header \`If-Match: "\<etag\>"\`    
   \- map\_in: only user-editable fields, e.g. \`{ plate\_no, driver\_name, driver\_phone, notes }\` (do not send server-owned fields)    
   \- assert: client-side validators (phone pattern)    
   \- System: server validates If-Match and returns 200 or 412    
   \- map\_out: \`{ checkin\_id, status, updated\_at, updated\_by }\`    
   \- UI Feedback: show toast success; on 412 show modal to re-fetch    
   \- Navigation/State: close drawer, refresh detail and list  
   \- Field & Copy Checklist:  
     \- Editable fields: \`plate\_no | ทะเบียนรถ | string | required=yes | validators: pattern | visibility: editable\`  
     \- \`notes\` optional  
     \- data-test-id: \`input-plate-no-edit\`, \`btn-save-edit-checkin\` — TODO

\#\#\#\# Variants & Exceptions  
\- 412 \`CONFLICT\_UPDATE\_STALE\` → show dialog "ข้อมูลเปลี่ยนแปลง กรุณาดึงข้อมูลล่าสุดก่อนดำเนินการ" with CTA Refresh; if user chooses refresh, re-fetch detail  
\- 403 \`FORBIDDEN\` → show toast "คุณไม่มีสิทธิ์แก้ไขรายการนี้"

\#\#\#\# Telemetry & Audit  
\- Events:  
  \- \`checkin.update.attempt\`, \`checkin.update.success\` with actor\_id, checkin\_id, etag, changed\_fields  
\- Audit: record previous and updated values, actor\_id, timestamp

\#\#\#\# Assumptions & Confidence  
\- API requires If-Match header — Confidence: High

\---

\#\#\# Journey: Void (ยกเลิกเช็คอินเดี่ยว) (Actor: Gate Staff)  
\*\*Entry:\*\* List (Tab "เช็คอินแล้ว") → แถว \> Action "Void" → เปิด Modal \`/cane/check-in/{id}/void\`    
\*\*Preconditions:\*\* Current status \!= completed (server will enforce \`INVALID\_STATE\` for completed); user has permission to void; client has ETag (recommended)    
\*\*Exit / Postconditions:\*\* เรียก \`POST /api/cane-checkins/void\` จะเปลี่ยน status → \`voided\` และคืน \`coin\_number\`; event \`cane.checkin.voided\` emitted

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*CheckinListPage / Click Void\*\* — เปิด Confirm Void Modal    
   \- Trigger: DIALOG \`/cane/check-in/{id}/void\`    
   \- map\_in: \`{ checkin\_id }\` (from row)    
   \- assert: client ensures status \!= completed; else disable Void button    
   \- System: open modal; load existing checkin detail (if not in cache) to show \`coin\_number\` and status; capture ETag if present    
   \- data-test-id: \`btn-row-void\`, \`modal-void-checkin\`, \`textarea-void-reason\` — TODO  
2\) \*\*Void Modal / Submit Reason\*\* — ผู้ใช้กรอกเหตุผลและกด Void    
   \- Trigger: POST \`/api/cane-checkins/void\`    
   \- map\_in: \`{ checkin\_id, reason }\` (only these fields)    
   \- headers: \`X-Idempotency-Key: ui:{user.id}:void:{checkin\_id}\` (pattern per Hard Constraints §5 for Finalize), recommended \`If-Match: "\<etag\>"\` if available    
   \- assert: client validates \`reason\` required (min length 5\) and status still voidable (re-check via quick GET if desired)    
   \- System: POST call; on success 200 returns \`{ checkin\_id, status: "voided", released\_coin\_number, voided\_at }\`    
   \- map\_out: update UI: mark row as \`voided\` or remove from active list; show toast "ยกเลิกเช็คอินเรียบร้อย — หมายเลขเหรียญคืนสิทธิ์แล้ว"    
   \- UI Feedback: disable modal while pending; on success close modal & toast; on error show inline messages    
   \- Navigation/State: refresh list & detail (invalidate caches)    
   \- Field & Copy Checklist:  
     \- \`reason | เหตุผล | textarea | required: yes | validators: minLength=5 | helper\_text\_th: "ระบุเหตุผลอย่างน้อย 5 ตัวอักษร" | data-test-id: textarea-void-reason\`  
     \- Buttons: \`btn-cancel-void\`, \`btn-confirm-void\`  
     \- a11y: focus goes to textarea on open; Esc closes modal  
3\) System-side: release coin\_number (atomic DB op) so coin becomes available for reuse

\#\#\#\# Variants & Exceptions  
\- POST → \`INVALID\_STATE\` (cannot void completed) → Show modal error "ไม่สามารถยกเลิกรายการที่สถานะ completed" and close modal; no retry  
\- POST → 412 \`CONFLICT\_UPDATE\_STALE\` (If-Match mismatch) → prompt user to refresh detail and reattempt; do not auto-retry  
\- POST → 409/CONFLICT (e.g., already voided by another actor) → show "รายการถูกยกเลิกแล้ว" and refresh list  
\- Access Control: if approval for Void required (policy unclear), POST may return 202 pending\_approval — this behavior is NOT defined in APIs (see TODO)

\#\#\#\# Telemetry & Audit  
\- Events:  
  \- \`checkin.void.attempt\` payload: { actor\_id, checkin\_id, idempotency\_key, correlation\_id }  
  \- \`checkin.void.success\` payload: { actor\_id, checkin\_id, released\_coin\_number, voided\_at }  
\- Audit fields: actor\_id, role, reason, idempotency\_key, etag, timestamp

\#\#\#\# Test Hooks & Acceptance  
\- data-test-id list as above; TODO to add

\#\#\#\# Assumptions & Confidence  
\- If-Match recommended by API — Confidence: High    
\- Approval flow for Void not implemented in current API — Confidence: Low (needs TODO)

\---

\#\#\# Journey: Export List (CSV) (Actor: Gate Staff / Dispatcher)  
\*\*Entry:\*\* หน้า List \`/cane/check-in\` → ปุ่ม Export CSV (toolbar)    
\*\*Preconditions:\*\* ผู้ใช้มีสิทธิ์ export; current filters applied; export size reasonable (note: for very large exports async job not defined)    
\*\*Exit / Postconditions:\*\* Call \`GET /api/cane-checkins?{current\_filters}\&export=csv\` → synchronous CSV download

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*CheckinListPage / Click Export CSV\*\* — ผู้ใช้กดปุ่ม Export    
   \- Trigger: EXPORT → \`GET /api/cane-checkins?{filters}\&export=csv\`    
   \- map\_in: current filter params (q, status, source\_type, guest\_only, cbm\_id, quota\_id, page\_size, sort etc.) — do not send client-only UI flags    
   \- assert: client-side confirm (if \> 1000 rows recommend confirmation) — default page\_size=25 unless user changed    
   \- System: server returns CSV content (200) or error; client initiates file download \`cane-checkins-{timestamp}.csv\`    
   \- map\_out: CSV file stream/download    
   \- UI Feedback: show spinner overlay on export button; on success show toast "ดาวน์โหลดไฟล์สำเร็จ" and trigger file save; on 429 or 5xx show retry option    
   \- data-test-id: \`btn-export-csv\` — TODO  
   \- Telemetry: \`checkin.export.csv\` payload: { actor\_id, filters, result\_count(if provided) }  
2\) \*\*Client-side fallback\*\* — if server returns 202 (not in spec) or large export not handled, show message to user (Warning in UI): "ขนาดข้อมูลใหญ่ ส่งออกแบบไม่พร้อมใช้งาน — ทีมงานจะแจ้งเมื่อเสร็จ" (not implemented server-side)

\#\#\#\# Variants & Exceptions  
\- 429 Rate limit → show "ระบบยังคงหน่วงการส่งออก" and retry with backoff 2 attempts  
\- 500 → show "เกิดข้อผิดพลาดขณะส่งออก" and button Retry

\#\#\#\# Assumptions & Confidence  
\- Synchronous CSV supported for typical page sizes → Confidence: High; for large exports require async job (TODO)

\---

\#\#\# Journey: สแกน QR → เปิด CBM Check-In Drawer (Actor: Gate Staff)  
\*\*Entry:\*\* List toolbar → ปุ่ม Scan QR → Modal \`/cane/check-in/scan\`    
\*\*Preconditions:\*\* Camera permission granted; QR contains valid \`cbm\_id\` matching pattern \`^CBM-\\d{4}-\\d{7}$\`    
\*\*Exit / Postconditions:\*\* Parsed \`cbm\_id\` → navigate to \`/cane/check-in/new/cbm?cbm\_id={cbm\_id}\` (prefill)

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*CheckinListPage / Click Scan QR\*\* — เปิด Scan Modal    
   \- Trigger: DIALOG \`/cane/check-in/scan\`    
   \- UI: Camera preview active, fallback input if permission denied    
   \- data-test-id: \`btn-scan-qr\`, \`modal-scan-qr\`, \`camera-preview\` — TODO  
2\) \*\*QRScanner / parse cbm\_id\*\* — Scanner detects QR → emits cbm\_id    
   \- Trigger: SIDE\_EFFECT → NAV to \`/cane/check-in/new/cbm?cbm\_id={cbm\_id}\` (preferred)    
   \- map\_in: parsed \`cbm\_id\`    
   \- assert: client validates format; if invalid show error "QR ไม่ผ่านรูปแบบ"    
   \- System: close modal, open CBM drawer with prefill cbm\_id → proceed as Journey CBM above    
   \- Telemetry: \`checkin.qr.scan\` payload: { actor\_id, cbm\_id\_hashed, correlation\_id }

\#\#\#\# Variants & Exceptions  
\- Camera permission denied → show manual input field and retry instructions  
\- QR parsed but CBM not found → on navigating to CBM drawer, server or client fetch returns error → show "ไม่พบ CBM"

\#\#\#\# Assumptions & Confidence  
\- QR contains cbm\_id only — Confidence: High

\---

\#\#\# Journey: จัดการกรณี coin\_number ซ้ำ / Retry (Actor: Gate Staff)  
\*\*Entry:\*\* ระหว่าง Submit POST (any create flow) แสดง conflict (409) หรือ VALIDATION\_FAILED duplicate    
\*\*Preconditions:\*\* X-Idempotency-Key ถูกส่งตาม pattern; server-side unique constraint on coin\_number active    
\*\*Exit / Postconditions:\*\* ใช้แนวทาง retry หรือแก้ไขค่า coin\_number; หาก retry ให้ใช้ \`X-Idempotency-Key\` เดิม

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Create POST → รับ 409 / VALIDATION\_FAILED (duplicate)\*\*    
   \- Trigger: API response 409/VALIDATION\_FAILED    
   \- map\_in: (n/a)    
   \- assert: client must surface conflict message and options    
   \- System: show modal with options: (A) เลือกหมายเลขอื่น (focus coin input) (B) ดูรายการที่ขัดแย้ง (if API provided conflict summary) (C) Retry with same idempotency key if server indicates idempotent result available    
   \- UI Feedback: show error toast and modal; focus coin input for change or show details link    
   \- Telemetry: \`checkin.create.conflict\` payload: { actor\_id, coin\_number, correlation\_id, idempotency\_key }  
2\) \*\*User chooses Retry\*\* — If user retries without changing coin\_number and server indicates idempotent handling, client SHOULD reuse same \`X-Idempotency-Key\` and call POST again. On CONFLICT instruct to retry with same key; on success show success toast.    
   \- Retry policy: exponential backoff 3 attempts for 5xx/429; for 409 allow manual retry only.

\#\#\#\# Variants & Exceptions  
\- If conflict persists → recommend user change coin\_number; show quick-validate endpoint to check candidate coin numbers \`GET /api/cane-checkins/validate?coin\_number=...\`

\#\#\#\# Telemetry & Audit  
\- \`checkin.create.conflict\` \+ \`checkin.create.retry\` events

\#\#\#\# Test Hooks  
\- data-test-id: \`modal-coin-conflict\`, \`btn-retry-same-key\`, \`btn-change-coin\` — TODO

\#\#\#\# Assumptions & Confidence  
\- Server supports idempotency semantics on POST — Confidence: High

\---

\#\#\# Journey: เปิดจาก Notification (Deeplink ไปยัง Detail) (Actor: Gate Staff)  
\*\*Entry:\*\* ผู้ใช้คลิก Notification (system/email/push) ที่มีลิงก์ \`/cane/check-in/{checkin\_id}\`    
\*\*Preconditions:\*\* ผู้ใช้ authenticated; token valid; permission to view resource    
\*\*Exit / Postconditions:\*\* เปิด Detail Drawer / Page; telemetry event \`checkin.opened.via\_notification\`

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*Notification → คลิกลิงก์\*\*    
   \- Trigger: NAV to \`/cane/check-in/{checkin\_id}\` (NAV)    
   \- map\_in: \`{ checkin\_id }\` from URL    
   \- assert: client checks auth; if not authenticated redirect to login and then back to deeplink (preserve route)    
   \- System: GET \`/api/cane-checkins/{checkin\_id}\` retrieve detail \+ ETag; show drawer    
   \- UI Feedback: skeleton while loading; on 404 show toast "ไม่พบรายการ" and navigate to list    
   \- Telemetry: \`checkin.opened.via\_notification\` payload: { actor\_id, checkin\_id, source\_notification\_id }  
   \- data-test-id: \`link-deeplink-checkin\`, \`drawer-checkin-detail\` — TODO

\#\#\#\# Variants & Exceptions  
\- If user lacks view permission → server returns 403; client shows toast "คุณไม่มีสิทธิ์ดูรายการนี้" and navigate to list

\#\#\#\# Assumptions & Confidence  
\- Notification link preserves authentication flow → Confidence: High

\---

\#\#\# Journey: Finalize Check-In → completed (Payment callback) (Actor: Payment System → System effect)  
\*\*Entry:\*\* External payment system (not in current API) calls back to transition payment result → completed    
\*\*Preconditions:\*\* Payment integration webhook/API not specified in current inputs (TODO)    
\*\*Exit / Postconditions:\*\* Checkin status transitions \`awaiting\_payment\` → \`completed\`; event \`cane.checkin.completed\` emitted; UI list refresh

\#\#\#\# Happy Path — ขั้นตอนละเอียด (speculative; API missing)  
1\) \*\*Payment System → call internal API (not defined)\*\*    
   \- Trigger: WEBHOOK or API (not provided)    
   \- map\_in: likely \`{ checkin\_id, payment\_status, transaction\_id }\` (NOT defined)    
   \- assert: verify signature/auth (not defined)    
   \- System: server updates checkin.status → \`completed\` and persists payment info; emits \`cane.checkin.completed\`    
   \- UI Feedback: On next List refresh, item shows \`completed\` badge; if user viewing detail, show updated status and toast "ชำระเงินเรียบร้อย"    
   \- Telemetry: \`checkin.payment.completed\` with payment metadata

\#\#\#\# Variants & Exceptions  
\- Payment failure → remain \`awaiting\_payment\`; manual retry via payment UI (not defined)

\#\#\#\# Telemetry & Audit  
\- \`checkin.payment.completed\`, \`checkin.payment.failed\`

\#\#\#\# Assumptions & Confidence  
\- Payment webhook/API missing → Confidence: Low — TODO to define Payment contract

\---

\#\#\# Journey: Export / ดูเอกสาร (Document View & Download) — (Actor: Gate Staff)  
\*\*Entry:\*\* จาก Detail → ปุ่มดูเอกสาร/ใบเสร็จ (ไม่ปรากฏใน current API)    
\*\*Preconditions:\*\* API สำหรับสร้าง/ให้ดาวน์โหลดเอกสาร (ไม่ระบุ)    
\*\*Exit / Postconditions:\*\* เปิด viewer หรือดาวน์โหลดไฟล์; ต้องมี fallback “Open original link” (\`btn-open-original\`)

\#\#\#\# Happy Path — ขั้นตอนละเอียด (API missing)  
1\) \*\*User clicks View Document\*\*    
   \- Trigger: NAV / DOC\_GENERATE (API not defined)    
   \- map\_in: \`{ checkin\_id }\`    
   \- System: (Not defined) call to doc gen service returning PDF url or binary    
   \- UI: Open modal with PDF iframe; include \`btn-open-original\` to open direct link in new tab; provide download button    
   \- data-test-id required: \`btn-open-original\`, \`modal-doc-viewer\` — TODO  
2\) \*\*Fallback\*\* — if iframe cannot render, show \`btn-open-original\` prominent

\#\#\#\# Variants & Exceptions  
\- Doc generation fails → show "ไม่สามารถสร้างเอกสารได้" with Retry

\#\#\#\# Assumptions & Confidence  
\- Document generation API missing → Confidence: Low (TODO)

\---

\#\# Telemetry & Global Audit (สรุป)  
\- ชื่ออีเวนต์ (dot-case):  
  \- checkin.create.attempt  
  \- checkin.create.success  
  \- checkin.create.conflict  
  \- checkin.update.attempt  
  \- checkin.update.success  
  \- checkin.void.attempt  
  \- checkin.void.success  
  \- checkin.export.csv  
  \- checkin.qr.scan  
  \- checkin.opened.via\_notification  
  \- checkin.payment.completed (requires payment API)  
  \- cbm.patch\_status.called  
\- Payload fields (common): { actor\_id, actor\_role, correlation\_id, idempotency\_key, checkin\_id, cbm\_id, coin\_number\_hash, timestamp, request\_body\_summary }    
\- Audit fields stored per change: actor\_id, actor\_role, action, resource\_id(s), previous\_values, new\_values, reason (for void), etag, idempotency\_key, trace\_id

\#\# Test Hooks (สรุป data-test-id ที่ต้องมี)  
รายการ data-test-id ที่ต้องเพิ่ม (Page Definitions ไม่ได้ระบุเชิงชัดเจน) — โปรด implement ใน UI:  
\- List page: \`btn-row-checkin-cbm\`, \`btn-row-void\`, \`btn-export-csv\`, \`btn-scan-qr\`, \`input-search-checkin\`  
\- Drawers/Forms: \`drawer-checkin-cbm\`, \`drawer-checkin-member\`, \`drawer-checkin-guest\`, \`input-coin-number\`, \`input-coin-number-member\`, \`input-coin-number-guest\`, \`input-quota-token\`, \`input-debt-percent\`, \`btn-confirm-checkin-cbm\`, \`btn-confirm-checkin-member\`, \`btn-confirm-checkin-guest\`  
\- Modals: \`modal-choose-mode\`, \`modal-scan-qr\`, \`modal-void-checkin\`, \`btn-open-original\`, \`modal-doc-viewer\`  
\- Detail: \`drawer-checkin-detail\`, \`detail-btn-edit\`, \`detail-field-coin-number\`  
(หมายเหตุ: ด้านบนให้เป็น baseline; แต่ Page Definitions ต้องเติมรายการเหล่านี้ — ดู TODOs)

\#\# Self-Validation Checklist (ที่ตรวจสอบแล้ว)  
\- Status enum ใช้ค่าเดียวตาม API: checked\_in, awaiting\_payment, completed, voided — ไม่มี label ใหม่เช่น Pending Approval (ใช้ awaiting\_payment แทน)    
\- Map-In Minimalism: ทุก POST/PATCH map\_in ใน journey ส่งเฉพาะฟิลด์ที่ client ให้ (coin\_number, ids, notes, payment fields) — ไม่ส่งค่าที่ server ต้องคำนวณ (เช่น totals)    
\- Row Action Guards: Row-level Check-In/ Void ต้องถูกซ่อนหรือ disabled ใน client เมื่อสถานะหรือบทบาทไม่อนุญาต (ระบุในแต่ละ journey) — server ยังต้อง re-assert    
\- Idempotency Key Patterns:  
  \- Create Submit (POST create): \`X-Idempotency-Key: ui:{user.id}:create\_checkin:{sha256(coin\_number|source\_type|identifier)}\` — ตัวอย่าง: \`ui:user\_1001:create\_checkin:sha1...\`  
  \- Void Submit: \`X-Idempotency-Key: ui:{user.id}:void:{checkin\_id}\`  
  \- Finalize (payment) key: if needed \`ui:{user.id}:finalize:{checkin\_id}\`    
  \- On CONFLICT retry use same key    
\- Telemetry naming uses dot-case (ตัวอย่างข้างต้น)    
\- Document Viewer Fallback: ระบุ \`btn-open-original\` ใน Document journey (TODO implement)    
\- A11y/Hotkeys: Alt+C \= create (open Choose Mode), Ctrl+Enter \= submit drawer, Esc \= close modal/drawer; focus order specified per drawer/modal    
\- Navigation & Routes: ใช้ routes จาก Page Definitions (leading slash \`/cane/check-in\` etc.)    
\- Orchestrator Triggers: After successful create CBM flow, server triggers PATCH CBM booking — explicitly stated in Journey A    
\- Test Hooks: ทุก actionable step ระบุ data-test-id (แต่ Page Definitions ไม่มีรายการจริง — ดู TODOs)  
\- Per-step Field/COPY Coverage: ทุก Happy Path step มี Field & Copy Checklist รวมถึง validation copy

\#\# TODOs (รายการที่ต้องเติม/แก้ไขเพราะขาดข้อมูลหรือไม่สามารถ fabricate ได้)  
1\) Payment webhook / API เพื่อเปลี่ยนสถานะ \`awaiting\_payment\` → \`completed\` ไม่ได้ระบุในสเปค — ต้องเพิ่ม API/contract (endpoint, auth, payload, signature) เพื่อรองรับ Journey Finalize Check-In. (required)    
2\) Approval flow for Void (ถ้าจำเป็นตามนโยบาย Logistics Supervisor) — ไม่มี endpoints \`request\_void\` / \`approve\_void\` / \`reject\_void\` ในสเปค — ระบุว่าต้องเพิ่มหากต้องการระบบอนุมัติ (required if business requires approval). (required)    
3\) Document generation / download API for check-in documents/receipts ไม่ได้ระบุ — ต้องเพิ่ม endpoint(s) สำหรับสร้างและรับไฟล์ PDF/URL (required for Document View / Download). (required)    
4\) Page Definitions ยังไม่ระบุ \`data-test-id\` รายการที่ให้ใน Test Hooks — โปรดเพิ่มใน Page Definitions / component templates: see Test Hooks list above. (required)    
5\) Template tokens missing (จาก Warnings): \`{{subtitle}}\`, \`{{filter\_sum}}\`, \`{{import\_label}}\`, \`{{col\_ref}}\`, \`{{col\_loc}}\`, \`{{col\_qty}}\`, \`{{col\_wt}}\`, \`{{col\_updated}}\`, \`{{range\_text}}\`, \`{{page}}\` — ต้องแมปกับ content หรือเอาออกจาก templates. (action item)    
6\) CBM upstream PATCH may require \`If-Match\` with ETag — current flow mentions it optional; need to confirm upstream contract for ETag handling and how to obtain that ETag prior to PATCH. (clarify)    
7\) Large export async job: current API uses synchronous CSV download; for very large dataset, need async export endpoint (202 \+ job retrieval) — design required. (recommend)    
8\) Row-level scoping (branch/gate-limited views) not specified — if required add tenant/gate filter and RBAC scoping in APIs. (clarify)    
9\) Concrete data-test-id mapping into actual Page Definitions components (component props) missing — add mapping for all IDs listed in Test Hooks. (required)    
10\) QRScanner/CameraPreview component implementation details (permissions, fallbacks) not provided — UI team to implement per a11y guidelines. (implement)    
11\) Conflict UI: API support to return conflicting record summary (when coin duplicate) is optional; if desired, extend POST to include \`conflicting\_checkin\_summary\` in error details to render "ดูรายการที่ขัดแย้ง". (enhancement)    
12\) Confirm that \`GET /api/cane-checkins\` returns \`ETag\` header per item when used for cache/If-Match — docs ambiguous. If required for client-side concurrency, ensure API includes ETag on detail responses (already stated) and on list items if needed. (clarify)    
13\) Bulk Void / Bulk Cancel endpoint not defined — current spec only supports single \`POST /api/cane-checkins/void\`. If bulk is required add endpoint \`POST /api/cane-checkins/void/bulk\` or similar. (required if bulk needed)    
14\) Payment system security (HMAC signature) requirement mentioned in notes but webhook contract missing (see \#1). (define)    
15\) Masking policy for \`driver\_phone\` in UI/telemetry: implement masking in list contexts and log masking for PII — confirm the mask pattern. (define)  

หมายเหตุสุดท้าย: ทุกการกระทำที่เปลี่ยน state ต้องรวม \`actor\_id\`, \`idempotency\_key\` (สำหรับ POST), และ \`If-Match\` (สำหรับ PATCH/void เมื่อเป็นไปได้) ใน audit logs. หากต้องการให้ผมสร้าง Gherkin tests แบบเต็มหรือ sequence diagram สำหรับแต่ละ Journey แจ้งมาได้ — ผมจะขยายให้เป็นชุด automated acceptance tests และ API interaction mocks ตามจำเพาะ.

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

\# 11\. Business Rules

\#\#\# 11.1 Rules Inventory (merged)  
| Rule ID | Type (validation/domain) | Context (entity/endpoint) | State/Trigger | Condition | Expected | Error Code | Ref(A5/A6/A3) | Notes |  
|---|---|---|---|---|---|---|---|---|  
| R1 | validation | POST /api/cane-checkins | create | coin\_number reserved (status IN ('checked\_in','awaiting\_payment')) | reject | VALIDATION\_FAILED | A5 §8.3; A6 §10.0.2; A3 §5.2 | partial unique index enforces |  
| R2 | domain | DB constraint / concurrent create | simultaneous commit | unique partial index violation on coin\_number | reject | VALIDATION\_FAILED | A6 §10.0.2; A3 §5.2 | transaction retry / idempotency required |  
| R3 | validation | POST /api/cane-checkins | request | missing \`X-Idempotency-Key\` header | reject | VALIDATION\_FAILED | A5 §9.1; A3 §5.2.2 | header required for retriable POSTs |  
| R4 | domain | POST /api/cane-checkins | retry | duplicate \`X-Idempotency-Key\` for same payload | accept | — | A5 §9.4; A3 §5.2.2 | return original response (idempotent) |  
| R5 | validation | PATCH /api/cane-checkins/{checkin\_id} | update | missing or mismatched \`If-Match\` ETag | reject | CONFLICT\_UPDATE\_STALE | A5 §8.4; A3 §5.2.2 | client must re-fetch on 412 |  
| R6 | domain | PATCH /api/cane-checkins/{checkin\_id} | update | status NOT editable when IN ('awaiting\_payment','completed') | reject | INVALID\_STATE | A3 §5.1; A5 §9.2 | edits allowed only pre-awaiting\_payment |  
| R7 | domain | POST /api/cane-checkins/void | void | status \= 'completed' → cannot void | reject | INVALID\_STATE | A3 §5.2; A5 §8.5 | Void only before completed |  
| R8 | validation | POST /api/cane-checkins/void | void | missing \`reason\` in body | reject | VALIDATION\_FAILED | A5 §8.5; A6 §10.0.2 | \`void\_reason\` required by API |  
| R9 | validation | POST /api/cane-checkins/void | void | missing \`X-Idempotency-Key\` header | reject | VALIDATION\_FAILED | A5 §9.1; A3 §5.2.2 | Idempotency required for void |  
| R10 | validation | POST /api/cane-checkins (cbm) | create | \`cbm\_id\` not matching \`\\\`^CBM-\\d{4}-\\d{7}$\\\`\` | reject | VALIDATION\_FAILED | A6 §10.4; A5 §8.3 | QR/CBM prefill must match pattern |  
| R11 | validation | GET/PATCH/void path param | request | \`checkin\_id\` not matching \`\\\`^CHK-\\d{4}-\\d{6}$\\\`\` | reject | VALIDATION\_FAILED | A6 §10.4; A5 §8.2 | path param pattern enforced |  
| R12 | validation | POST/PATCH body | request | \`driver\_phone\` not matching \`\\\`^0\\d{8,9}$\\\`\` | reject | VALIDATION\_FAILED | A6 §10.4; A5 §9.2 | phone format validation |  
| R13 | validation | POST/PATCH body | request | \`coin\_number\` length not BETWEEN 1 AND 12 | reject | VALIDATION\_FAILED | A6 §10.4; A5 §8.3 | max 12 chars |  
| R14 | validation | POST /api/cane-checkins | create | \`source\_type\` NOT IN ('cbm\_booking','member\_no\_booking','guest\_pool') | reject | VALIDATION\_FAILED | A6 §10.0.2; A5 §8.3 | canonical values only |  
| R15 | validation | POST /api/cane-checkins (member) | create | missing \`debt\_payment\_percent\` for member\_no\_booking | reject | VALIDATION\_FAILED | A6 §10.3; A5 §8.3 | required for member\_no\_booking |  
| R16 | validation | POST /api/cane-checkins (member) | create | \`debt\_payment\_percent\` NOT BETWEEN 0 AND 100 | reject | DEBT\_PERCENT\_OUT\_OF\_RANGE | A6 §10.3; A5 §9.2 | numeric range enforced |  
| R17 | validation | POST /api/cane-checkins (guest) | create | \`debt\_payment\_percent\` present for guest\_pool | reject | VALIDATION\_FAILED | A6 §10.3; A5 §8.3 | guest\_pool must have NULL percent |  
| R18 | domain | POST /api/cane-checkins (cbm) | create | CBM upstream PATCH fails with \`INVALID\_STATE\` | reject | INVALID\_STATE | A5 §8.7; A3 §5.2 | CBM must be dispatchable |  
| R19 | domain | POST /api/cane-checkins (cbm) | create | CBM upstream PATCH returns NOT\_FOUND | reject | NOT\_FOUND | A5 §8.7; A3 §5.2 | cbm\_id must exist upstream |  
| R20 | validation | GET /api/cane-checkins | query | invalid filter shape (e.g., coin\_number too long) | reject | VALIDATION\_FAILED | A5 §8.1; A6 §10.0.2 | query validation on list/export |

\#\#\# 11.2 State→Action Guard Matrix (compact)  
State | Allowed | Blocked | Preconditions | Error Code  
\---|---|---|---|---  
checked\_in | update\<br\>void\<br\>view | submit/approve/complete | coin\_number unique validated\<br\`If-Match\` on PATCH | VALIDATION\_FAILED\<br\>CONFLICT\_UPDATE\_STALE  
awaiting\_payment | view\<br\>void | update (editable) / void if completed | cannot edit fields manually\<br\`status\` locked until payment | INVALID\_STATE\<br\>CONFLICT\_UPDATE\_STALE  
completed | view | update\<br\>void | terminal state; payment confirmed | INVALID\_STATE  
voided | view (audit) | update\<br\>void\<br\>submit | soft-deleted for operations; coin\_number released | INVALID\_STATE

\#\#\# 11.3 Soft-Delete & Retention (concise)  
\- Lists/Detail: exclude status='voided' by default from primary views; show in audit view on demand.    
\- Restore: no restore API defined; if restorable, target status should be \`checked\_in\`/\`awaiting\_payment\` and require \`If-Match\` / \`X-Idempotency-Key\`.    
\- \[Default\] exclude by default; restorable if not purged (restore API/policy not specified; gap logged).

\#\#\# 11.4 Compensation & Recovery (P0 only)  
Scenario | Preconditions | Action | Resulting State/Data | Idempotency/ETag | Observability  
\---|---|---|---|---|---  
Payment callback failure | awaiting\_payment, payment webhook missing | retry webhook / manual reconcile | state remains awaiting\_payment until success | use webhook idempotency / X-Idempotency-Key | audit log, eventbus alerts  
ETag mismatch on PATCH | client If-Match stale | client re-fetch then merge/retry | no unintended change; new version produced on success | If-Match required; 412 CONFLICT\_UPDATE\_STALE | trace\_id in error response  
Duplicate POST create | network retry with same X-Idempotency-Key | return original response / do not duplicate | single checkin row created | X-Idempotency-Key mandatory | request trace and idempotency logs  
Partial CBM flow failure | local insert succeeded but PATCH CBM failed | compensate by voiding local row or rollback transaction | local row voided or removed; coin\_number released | use X-Idempotency-Key to avoid duplicate actions | audit entry, cbm patch error logged  
Webhook retry / DLQ | payment webhook repeatedly failing | enqueue to DLQ and notify ops | eventual reconcile manual or retry | webhook idempotency recommended | DLQ metrics / alerts

\#\#\# 11.5 Findings & Follow-ups  
\- A5 uses \`VALIDATION\_FAILED\` not \`VALIDATION\_ERROR\`; adjust normalization (owner: API) — see A5 §9.2.    
\- Normalization wanted \`PRECONDITION\_FAILED\` for ETag, but A5 uses \`CONFLICT\_UPDATE\_STALE\` (owner: API) — see A5 §9.2.    
\- No generic \`CONFLICT\` named code in A5 for coin race; used \`VALIDATION\_FAILED\` instead (owner: API/A6).    
\- Payment callback endpoint/contract not specified; define webhook URL/payload/auth (owner: Integrations) — see A3 Warnings.    
\- Large-export async behavior undefined; define async job or limits (owner: API/Product) — see A5 §9.6.    
\- Void approval workflow ambiguous (Logistics Supervisor conditional); define approval endpoints if required (owner: Product/RBAC).    
\- No restore API specified for voided rows; add restore contract or record purge policy (owner: Product).    
\- Events/webhook payload schemas (checkin.created/completed/voided) unspecified; define contract (owner: Integrations).    
\- ETag/version semantics: A6 uses \`version\` → map to \`ETag\` header (owner: API/DB) — ensure consistent encoding.