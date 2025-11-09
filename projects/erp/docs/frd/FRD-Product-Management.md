\# 1\. Feature Overview  
\- Feature Id : feat\_product\_management\_20251109120000  
\- Feature Name : การจัดการสินค้า  
\- Module : ข้อมูลมาสเตอร์ × จัดซื้อ × คลังสินค้า/สินค้า × การเงิน (แมป GL)  
\- Base Path : /erp/master/products  
\- Menu Trail : ERP \> ข้อมูลมาสเตอร์ \> สินค้า

\---

\# 2\. Objective & Background

\#\# 2.1 Objectives  
\- มีแคตาล็อกสินค้ากลางที่บังคับการแมป GL, Tax, Base UOM ก่อนสถานะ Active ภายในระบบ ERP เพื่อให้สินค้าที่ใช้งานใน P2P มีข้อมูลครบถ้วนและตรวจสอบได้  
\- ลดอัตราความไม่สอดคล้องของ UOM/GL/Tax/ Vendor ในเอกสาร P2P ให้เหลือน้อยกว่า 1% ภายใน 3 เดือนหลังใช้งาน  
\- ตรวจจับและป้องกันกรณี UOM cycle และ barcode ซ้ำ/ไม่ถูกต้อง โดยตั้งเป้า Duplicate/invalid barcode rate \< 0.5%  
\- ทำให้เวลาจากการสร้างสินค้า (create) ถึงใช้งานได้ (active) ≤ 2 วันทำการ สำหรับ P80 ของรายการใหม่  
\- สนับสนุน lifecycle การควบคุม (Draft → In Review → Approved → Active → Deactivate/Obsolete) พร้อมกระบวนการอนุมัติและบันทึก Audit trail

\#\# 2.2 Business Context  
\- Pain (ปัจจุบัน): ไม่มีแคตาล็อกสินค้ากลางที่มี governance ทำให้ข้อมูล UOM, โค้ดผู้ขาย, การแมป GL/Tax และสถานะไม่สอดคล้องในเอกสาร PR→PO→GRN→Putaway→Invoice  
\- Why now: ความไม่สอดคล้องของ master data ก่อให้เกิดความผิดพลาดทางโลจิสติกส์และการเงิน (เช่น บันทึก GL ผิด, tax ผิด, หน่วยวัดสับสน) จำเป็นต้องแก้ที่แหล่งข้อมูลต้นทางก่อนกระบวนการ P2P  
\- Desired future state: Product Master เดียวถูกควบคุม มี workflow สร้าง/ส่งตรวจ/อนุมัติ/เปิดใช้งาน ป้องกันการ Activate หากขาด GL/Tax และรองรับการบูรณาการกับ GL/Tax/Vendor masters  
\- Journey หลักที่ต้องรองรับ: Create → Save Draft → Submit (In Review) → Approve → Activate → ใช้งานใน PR/PO/GRN; รองรับการดูแล UOM conversions, การแมป Vendor, การ Import/Export และการพิมพ์ Label ตาม J1–J6

\#\# 2.3 Success Metrics (KPIs)  
\- KPI: Catalog completeness (GL/Tax/UOM/vendor set) ≥ 98%  
\- KPI: Duplicate/invalid barcode rate \< 0.5%  
\- KPI: New product lead time (create → active) ≤ 2 business days (P80)  
\- KPI: Import success rate for 10k rows ≥ defined SLA (ค่า SLA ต้องกำหนด)  
\- KPI: Search latency p95 ≤ 300ms  
\- KPI: ระบบป้องกัน UOM cycles \= 100% (no cyclic conversions allowed)

\#\#\# Warnings (if any)  
\- ค่า SLA สำหรับ "Import success rate for 10k rows" ยังไม่ได้กำหนดเป็นตัวเลขที่ชัดเจน — ต้องระบุค่า SLA เพื่อวัด KPI นี้  
\- บทบาทผู้อนุมัติ (Reviewer/Controller override) และสิทธิ์รายละเอียดไม่ได้กำหนดชัดเจน — ต้องระบุ role/permission model สำหรับการอนุมัติและการยกเว้น  
\- เป้าหมาย "ลดความไม่สอดคล้อง \<1%" เป็นเป้าหมายเชิงธุรกิจที่ต้องมี baseline ก่อนวัดผล — ไม่มี baseline ปัจจุบันในข้อมูลที่ได้รับมา

\# 3\. Scope & Constraints

\#\# 3.1 In Scope  
\- Product master CRUD (Create / Read / Update / Delete) พร้อม lifecycle management: Draft → In Review → Approved → Active → Deactivate → Obsolete  
\- UOM และ UOM Conversions: สร้าง/แก้ไข conversion (factor) และบังคับให้กราฟเป็น acyclic  
\- Vendor mapping: ตาราง vendor lines (vendor\_id, preferred, moq, lead\_time, price\_hint, currency) พร้อมข้อบังคับหนึ่ง preferred ต่อสกุลเงิน  
\- Tax / GL classification: บังคับแมป GL account และ tax code ก่อน Activate  
\- Attachments: images/docs แนบได้ในฟอร์มสินค้า  
\- Label / Barcode generation: พิมพ์ฉลากจาก template เป็น PDF  
\- Import / Export: CSV/XLSX import with preview/validation และ export ตาม filters  
\- หน้าที่ครอบคลุม: Product List (/erp/master/products/list) — รายการคอลัมน์, filters, toolbar และ row actions ตาม Page Definitions  
\- หน้าที่ครอบคลุม: Product Create/Edit (/erp/master/products) — sections: Header, Classification, Dimensions, Barcodes, UOM Conversions, Vendors, Attachments; actions \[Save Draft\], \[Submit\], \[Approve\]/\[Activate\] ตามบทบาท  
\- หน้าที่ครอบคลุม: Product Detail — Tabs: Overview | UOM | Vendors | Tax/GL | Images/Docs | Audit; header actions สอดคล้องกับ List row actions  
\- Journey หลัก (จาก User Journeys): J1 Create & Submit; J2 Approve & Activate; J3 Maintain UOM & Conversions; J4 Add/Manage Vendors; J5 Edit/Deactivate/Obsolete (with guards); J6 Import/Export/Label

\#\# 3.2 Out of Scope  
\- BOM / product variants  
\- Batch attributes นอกเหนือจาก lot/serial ที่บังคับ  
\- Price lists และ complex pricing workflows  
\- Workflow QA และการตรวจสอบคุณภาพเฉพาะทาง (not in MVP)

\#\# 3.3 Assumptions  
\- มีการเข้าถึงและ API สำหรับ GL master, Tax master, Vendor master, Category master เพื่อ validate และเลือกค่า  
\- API design รองรับ idempotency สำหรับ POST import/creates (X-Idempotency-Key) และ concurrency control ผ่าน If-Match สำหรับ PATCH ตาม Page Definitions  
\- ระบบเป็นบริษัทเดียว (single company) และกฎสกุลเงินถูกกำหนดให้สอดคล้องกับโซ่ P2P ตาม Constraint  
\- Downstream consumers (PR/PO, GRN/Putaway, Reporting/BI) จะ subscribe/consume outbound product events เพื่ออัพเดต catalog cache หรือ flags  
\- ระบบจะบันทึก Audit trail สำหรับการเปลี่ยนสถานะและการอนุมัติ

\#\# 3.4 Dependencies & Integrations  
\- Upstream masters: GL master (accounts), Tax master (codes), Vendor master, Category master — ต้องใช้สำหรับ validation และ picklists  
\- APIs (ตาม Page Definitions): GET /api/master/products, POST /api/master/products (X-Idempotency-Key), GET /api/master/products/{id}, PATCH /api/master/products/{id} (If-Match), และ endpoints สำหรับ submit/approve/activate/deactivate/obsolete/import/export/label  
\- Outbound events: product.created, product.submitted, product.approved, product.activated, product.deactivated, product.obsoleted, product.updated — ผู้บริโภคหลักคือ PR/PO services, GRN/Putaway, Reporting/BI  
\- Downstream requirements: PR/PO ต้องได้รับรายการ Active เท่านั้นและอาจใช้ preferred vendor/price\_hint; GRN/Putaway ต้องได้รับ flag สำหรับ tracking (lot/serial/expiry)  
\- Guardrails ที่ต้องบังคับจากระบบ: ห้าม Activate หากไม่มี GL/Tax; ห้าม Obsolete หากมี on-hand หรือเอกสารเปิด; UOM graph ต้องเป็น acyclic; ห้ามมีมากกว่าหนึ่ง preferred vendor ต่อสกุลเงิน

\#\#\# Warnings (if any)  
\- บทบาทที่สามารถทำ "controller override" และเงื่อนไขการยกเลิกการล็อก/Deactivate ยังไม่ได้กำหนดรายละเอียด — ต้องระบุ role/permission และ audit requirements  
\- รายละเอียด SLA สำหรับการ Import ขนาด 10k rows ไม่มีตัวเลขชัดเจน — ต้องกำหนดค่า SLA ก่อนออกแบบเชิงเทคนิค  
\- หากมีความขัดแย้งระหว่าง routes/APIs ที่ระบุและนโยบาย security/permission ของ platform ต้องแจ้งเพื่ออัปเดต API contracts

\# 4\. Target Users & RBAC

\> Feature: การจัดการสินค้า · Module: ข้อมูลมาสเตอร์ × จัดซื้อ × คลังสินค้า/สินค้า × การเงิน (แมป GL) · Base Path: /erp/master/products · Menu: ERP \> ข้อมูลมาสเตอร์ \> สินค้า

\#\# 4.1 Personas / Roles  
\- \*\*Viewer (Warehouse)\*\* — สิทธิ์อ่านเป็นหลัก: ดูข้อมูลบาร์โค้ด/UOM/ธงจัดการค่าพื้นฐาน, สแกนบาร์โค้ดเพื่ออ้างอิงการรับของ/lot/serial/expiry, พิมพ์ป้าย/ฉลาก    
\- \*\*Editor (Procurement (Buyer))\*\* — ค้นหา/อ่านสินค้าเป็นหลัก และจัดการ ProductVendor (preferred vendor, moq, lead\_time, price\_hint) ภายใต้ DOA; อาจนำเข้าข้อมูล vendor/catalog ตามสิทธิ์    
\- \*\*Approver (Finance)\*\* — ตรวจสอบการแมป GL/Tax และอนุมัติเพื่อให้สินค้าสามารถ Active ได้; ตรวจสอบความถูกต้องด้านบัญชี/ภาษีก่อนเปิดใช้งาน    
\- \*\*Admin (Master Data Admin)\*\* — สร้าง/แก้ไขสินค้าเต็มรูปแบบ, จัดการ UOM & conversions, สถานะ (submit/approve/activate/deactivate/obsolete), นำเข้า/ส่งออกรายการ (CSV/XLSX), และการกู้คืนข้อมูล

\#\# 4.2 RBAC Matrix (Role × Action × Route/API)

\#\#\# 4.2.1 Page-level Permissions  
\_เส้นทางหลัก\_  
\- List: /erp/master/products  
\- Create: /erp/master/products/new  
\- Detail: /erp/master/products/:id  
\- Edit: /erp/master/products/:id/edit

\*\*Additional Pages/Tabs (จาก Page Definitions)\*\*  
\- /erp/master/products/list — Product List (columns/filters/toolbar/row actions) — หน้าเดียวกับหลัก (view \+ row actions ตามสิทธิ์)  
\- /erp/master/products/new, /erp/master/products/:id/edit — Product Create/Edit — actions: Save Draft, Submit, (Admin) Approve/Activate  
\- /erp/master/products/:id — Product Detail with tabs:  
  \- /erp/master/products/:id/overview — Overview tab — view-only fields, header actions per status  
  \- /erp/master/products/:id/uom — UOM tab — add/edit conversions (act: create/update UOM conversions — conditional)  
  \- /erp/master/products/:id/vendors — Vendors tab — add/edit vendor lines (create/update/delete vendor rows, set preferred)  
  \- /erp/master/products/:id/tax-gl — Tax/GL tab — view/edit GL/tax (Finance visibility/approval)  
  \- /erp/master/products/:id/images — Images/Docs tab — attachments upload/download (download:doc)  
  \- /erp/master/products/:id/audit — Audit tab — view audit trail (view-only)  
\- Import modal/drawer: /erp/master/products/import — CSV upload → preview → commit (act: import:csv)  
\- Label/Export: /erp/master/products/:id/label (modal/flow) — choose template → GET \-\> export\_pdf (Print Label)

Journey หลัก (จาก User Journeys):  
\- Product Create → Submit → POST /api/master/products/{id}:submit → status=In Review  
\- Reviewer (Finance) → POST /api/master/products/{id}:approve → status=Approved  
\- Admin → POST /api/master/products/{id}:activate → status=Active → usable in PR/PO/GRN  
\- UOM tab → create/update conversions → if Active and critical change → requires re-approval (flow: save → POST {id}:submit)  
\- Vendors tab → add vendor lines (one preferred per currency constraint) → save  
\- Import → POST /api/master/products/import (X-Idempotency-Key) → preview → commit  
\- Print Label → GET /api/master/products/{id}:label → PDF

| Route / Action | Viewer | Editor | Approver | Admin |  
|---|:---:|:---:|:---:|:---:|  
| View List | ✓ | ✓ | ✓ | ✓ |  
| Search/Filter | ✓ | ✓ | ✓ | ✓ |  
| View Detail | ✓ | ✓ | ✓ | ✓ |  
| Create (full product) | — | — | — | ✓ |  
| Update (full product) | — | C | — | ✓ |  
| Update (vendors / non-critical fields) | — | ✓ | — | ✓ |  
| Delete (Soft) | — | — | — | ✓ |  
| Restore | — | — | — | ✓ |  
| Export CSV / XLSX | ✓ | C | ✓ | ✓ |  
| Bulk Import (CSV) | — | C | — | ✓ |  
| Bulk Actions (e.g., bulk:approve/import) | — | C | C | ✓ |  
| Status: Submit (Draft → In Review) | — | C | — | ✓ |  
| Status: Approve / Reject | — | — | ✓ | ✓ |  
| Status: Activate | — | — | C | ✓ |  
| Status: Deactivate | — | — | C | ✓ |  
| Status: Obsolete | — | — | — | ✓ |  
| UOM Conversions: create/update | — | C | — | ✓ |  
| Vendors: create/update/delete rows | — | ✓ | — | ✓ |  
| Export PDF (Print Label) | ✓ | ✓ | ✓ | ✓ |  
| Download Attachments | ✓ | ✓ | ✓ | ✓ |  
| Import Preview/Commit | — | C | — | ✓ |  
| Scan Barcode (view/lookup only) | ✓ | C | — | C |

Legend: ✓ อนุญาต · — ไม่อนุญาต · C มีเงื่อนไข    
Conditional Notes:  
\- C1: Editor (Procurement) สามารถสร้าง/แก้ไขได้เฉพาะ ProductVendor rows, price\_hint และฟิลด์ non-critical (ไม่สามารถสร้าง product หลัก หรือแก้ไขฟิลด์ที่ต้อง re-approval เช่น base\_uom, GL mapping)    
\- C2: การแก้ไขฟิลด์ที่ถือว่า "critical" (เช่น base\_uom, tracking, GL accounts, tax\_code) ขณะที่สถานะเป็น Active จะต้องผ่านกระบวนการ re-approval (Submit → Approve) ก่อนจะ Active ใหม่    
\- C3: Activate/Deactivate/Obsolete ถูกจำกัด: Activate ต้องผ่านการ Approve โดย Finance (Approver) และโดยปกติทำโดย Master Data Admin; Deactivate/Obsolete ต้องเป็นไปตามเงื่อนไข (no open PR/PO/GRN, no on-hand) — action อาจถูกบล็อก/ส่งกลับ (409/412) หากเงื่อนไขไม่ผ่าน    
\- C4: Bulk Import/Export และการใช้ X-Idempotency-Key / If-Match จำกัดเฉพาะผู้ที่มีสิทธิ์ Admin หรือผู้ที่ได้รับมอบหมาย (ตาม DOA)    
\- C5: Scan Barcode ในบริบทหน้าสินค้าจะเป็นการดู/ตรวจสอบบาร์โค้ด (read-only); การบันทึก lot/serial/expiry เกิดขึ้นใน GRN/Receiving flows (นอก scope feature นี้) — Warehouse ได้สิทธิ์ดู/พิมพ์ฉลาก

\#\#\# 4.2.2 API Scopes & Endpoints (Mapping)  
\> ใช้กับ Bearer JWT — ใส่ใน \`scopes\[\]\` หรือ \`roles\[\]\` ตามนโยบายระบบ

\- Recommended Scopes:  
  \- product.read, product.write, product.delete, product.restore  
  \- product.export, product.bulk, product.status, product.approve, product.import  
  \- product.label (export\_pdf)  
\- Endpoint Patterns (APIs ตาม Page Definitions ใช้ /api/master/products):  
  \- GET  /api/master/products — scope: product.read  
  \- POST /api/master/products — scope: product.write (X-Idempotency-Key)  
  \- GET  /api/master/products/{id} — scope: product.read  
  \- PATCH /api/master/products/{id} — scope: product.write (If-Match)  
  \- DELETE /api/master/products/{id} — scope: product.delete  
  \- POST /api/master/products/{id}:restore — scope: product.restore  
  \- POST /api/master/products:bulk — scope: product.bulk  
  \- POST /api/master/products/{id}:submit — scope: product.write  
  \- POST /api/master/products/{id}:approve — scope: product.approve  
  \- POST /api/master/products/{id}:activate — scope: product.status  
  \- POST /api/master/products/{id}:deactivate — scope: product.status  
  \- POST /api/master/products/{id}:obsolete — scope: product.status  
  \- POST /api/master/products/import — scope: product.import (X-Idempotency-Key)  
  \- GET  /api/master/products/export — scope: product.export  
  \- GET  /api/master/products/{id}:label — scope: product.label (export\_pdf)

\#\#\# 4.2.3 Data Access Constraints  
\- ระดับหน่วยงาน/สาขา: (ไม่ระบุใน A0) — ถ้ามีระบบแบ่งข้อมูลตาม org/site ควรกำหนด \`org\_id\`-based filtering; หากต้องการให้ผู้ใช้เห็นเฉพาะสินค้าของสาขา ให้ระบุในนโยบายต่อไป    
\- ระดับฟิลด์:  
  \- ฟิลด์ GL accounts / tax\_code: แสดง/แก้ไขได้เฉพาะ \`Admin\` และ \`Approver\` (Finance) — ผู้ใช้อื่นเห็นเป็น masked/RO    
  \- price\_hint/cost: แสดงได้สำหรับ Admin และ Procurement; อาจปิดบังค่า cost สำหรับ Warehouse    
\- Constraints for actions:  
  \- Deactivate/Obsolete: blocked if open PR/PO/GRN or on-hand \> 0 (API returns 409 Conflict)    
  \- Update protections: PATCH ต้องใช้ \`If-Match\` (ETag) เพื่อป้องกัน concurrent updates    
  \- Import: requires X-Idempotency-Key and server-side validation preview before commit

\#\# 4.3 Authentication & Authorization  
\- Auth: Bearer JWT (headers: Authorization). Use \`X-Idempotency-Key\` for create/import; \`If-Match\` (ETag) for update.  
\- Claims required in token: sub, roles\[\], scopes\[\], org\_id, user\_id  
\- Audit: บันทึก who/when/what สำหรับ create/update/delete/approve/restore/submit/import/activate/deactivate/obsolete/label-export  
\- Elevation: การอนุมัติ (approve) และการเปลี่ยนสถานะสำคัญ (activate/deactivate/obsolete) ต้องเป็น \`Approver\` หรือ \`Admin\` ขึ้นอยู่กับการกำหนดสิทธิ์ (see Conditional Notes)  
\- Fail Paths: 401 (unauthenticated), 403 (forbidden), 409 (conflict/reference e.g., open docs), 412 (etag mismatch), 422 (validation errors from import preview)

\#\#\# Warnings (if any)  
\- ไม่พบข้อมูลชัดเจนใน A0 ว่าใครเป็นผู้สั่ง Activate โดยตรง (Finance/Approver หรือ Master Data Admin); เอกสารระบุเพียงลำดับ Approve → Activate (J2) — ต้องตกลงนโยบาย (ระบุใน C3 ว่าโดยปกติ Master Data Admin จะ Activate หลังจาก Finance Approve)    
\- การจำกัดระดับหน่วยงาน/สาขา (org/site-level visibility) ไม่ได้ระบุใน A0 — หากระบบต้องการ scope per org ต้องกำหนด \`org\_id\`-based rules เพิ่มเติม    
\- รายละเอียดฟิลด์ที่ถือเป็น "critical" (จะต้อง re-approval เมื่อแก้ไขขณะ Active) ถูกอ้างถึงใน Journeys แต่ไม่ได้กำหนดรายการฟิลด์ชัดเจน — กรุณาระบุรายการฟิลด์ที่ต้องถือเป็น critical (เช่น base\_uom, tracking, GL accounts, tax\_code) เพื่อกำหนดนโยบาย RBAC/approval ให้ชัดเจน    
\- การสแกนบาร์โค้ดและการบันทึก lot/serial/expiry เกิดขึ้นในกระบวนการรับสินค้า (GRN/Receiving) ซึ่งอยู่นอก scope feature นี้; ในหน้า Product ให้จำกัดเป็นการดู/พิมพ์ฉลากเท่านั้น (หากต้องการให้หน้านี้ทำ checkin/receive ต้องมี Journey/APIs เพิ่มเติม)

\> Feature: การจัดการสินค้า · Module: ข้อมูลมาสเตอร์ × จัดซื้อ × คลังสินค้า/สินค้า × การเงิน (แมป GL) · Base Path: /erp/master/products · Menu: ERP \> ข้อมูลมาสเตอร์ \> สินค้า

\#\# 5.1 Status Model  
\- \*\*Draft\*\* — สถานะเริ่มต้นเมื่อสร้างสินค้า; อยู่ในระหว่างการกรอกข้อมูล/บันทึกแบบไม่เปิดใช้งาน; ผู้สร้าง: Master Data Admin  
\- \*\*In Review\*\* — สถานะหลังผู้ใช้กด Submit; อยู่ระหว่างการตรวจสอบโดยผู้ตรวจสอบ (Finance/Procurement ตาม DOA)  
\- \*\*Approved\*\* — สถานะที่ผ่านการตรวจสอบ (GL/Tax/Base UOM ถูกต้อง) แต่ยังไม่ถูกปลดล็อกให้ใช้งานในระบบซื้อ/คลังจนกว่าจะ Active  
\- \*\*Active\*\* — สถานะพร้อมใช้งานสำหรับ PR/PO/GRN/การทำธุรกรรมอื่น ๆ; อาจต้องมีการล็อก/revision เมื่อแก้ไขฟิลด์วิกฤต  
\- \*\*Inactive\*\* — สถานะไม่ใช้งานชั่วคราว; ห้ามย้ายหากมี PR/PO/GRN เปิดอยู่ ยกเว้นมี controller override  
\- \*\*Obsolete\*\* — สถานะสิ้นสุด (irreversible); เงื่อนไขก่อนย้าย: ไม่มี on-hand และไม่มีเอกสารเปิด

\> หมายเหตุ: ใช้การสะกดสถานะตาม canonical map; หากต้องมีสถานะย่อยเพิ่มเติมให้ระบุใน Warnings

\#\# 5.2 State Transitions  
ตารางทรานซิชัน (สรุป From → To → ผู้กระทำ → เงื่อนไข → ผลข้างเคียง/เหตุการณ์ → API):

| From | To | Allowed Roles | Preconditions / Guards | Side Effects (Events/Webhooks) | API |  
|---|---|---:|---|---|---|  
| Draft | In Review | Master Data Admin | ฟิลด์บังคับครบ (code/name/base\_uom); UOM/GL/tax มีค่าเริ่มต้นได้ | emit: product.submitted (payload: id, actor, timestamp, snapshot) | POST /erp/master/products/{id}:submit |  
| In Review | Approved | Finance; Procurement (Buyer) (ตาม DOA) | GL \+ Tax \+ Base UOM ถูกต้องตาม validation; หากต้องการ multi-level ให้ครบตาม DOA | emit: product.approved (approver(s), timestamp, notes) | POST /erp/master/products/{id}:approve |  
| In Review | Draft | Finance; Procurement (Buyer) | ReviewerReject with reason; ต้องบันทึกเหตุผล | emit: product.rejected (actor, reason, timestamp) | POST /erp/master/products/{id}:reject |  
| Approved | Active | Finance; Procurement (Buyer) | Validation ผ่าน (no validation errors); ไม่มีเอกสารอ้างอิงเปิดที่ขัดแย้ง | emit: product.activated (actor, timestamp) | POST /erp/master/products/{id}:activate |  
| Active | Inactive | Finance; Procurement (Buyer); (Controller override role may apply) | ห้ามเมื่อมี PR/PO/GRN เปิดอยู่ เว้นแต่มี controller override flag | emit: product.deactivated (actor, reason, timestamp); block new PR/PO creation if policy applies | POST /erp/master/products/{id}:deactivate |  
| Active | Obsolete | ? | ไม่มี on-hand และไม่มีเอกสารเปิด; irreversible | emit: product.obsoleted (actor, timestamp, final\_snapshot) | POST /erp/master/products/{id}:obsolete |  
| Any editable state | Draft (on edit save) | Master Data Admin | เมื่อบันทึกการแก้ไขระหว่างรอบอนุมัติ (ตาม field criticality) | emit: product.updated (draft\_revision\_id, actor) | PATCH /erp/master/products/{id} (If-Match) |  
| Active (critical-change) | In Review | Master Data Admin | เปลี่ยนฟิลด์วิกฤต (base\_uom, tax/GL, tracking) → สร้าง revision และ submit ใหม่ | emit: product.revision\_submitted | POST /erp/master/products/{id}:submit |

\*\*เงื่อนไขเสริม (ตัวอย่าง)\*\*  
\- Decision required: หาก DOA ระบุ multi-approver (Finance \+ Procurement) ต้องผ่านครบทั้งสองก่อน Approved  
\- ห้าม Obsolete หรือ Deactivate หากมี on-hand หรือเอกสารเปิด (PR/PO/GRN) เว้นแต่มี controller override (role/flag ยังไม่ชัดเจน — ดู Warnings)

\#\#\# 5.2.1 Error & Conflict Paths  
\- 401/403 — ไม่ยืนยันตัวตนหรือไม่มีสิทธิ์ดำเนินการ (เช่น user role ไม่อยู่ใน Allowed Roles)  
\- 409 CONFLICT — ขัดแย้งเชิงธุรกรรม (เช่น มีเอกสารอ้างอิงเปิด/มีการเปลี่ยนแปลง concurrent)  
\- 412 Precondition Failed — ETag mismatch (ต้อง refresh แล้วลองใหม่)  
\- 422 Unprocessable Entity — ไม่ผ่าน validation (เช่น GL/Tax/UOM ไม่ครบหรือกราฟ UOM ผิด)

\#\#\# 5.2.2 Concurrency & Idempotency  
\- ใช้ If-Match: \`\<etag\>\` header สำหรับคำสั่งเปลี่ยนสถานะและการ PATCH เพื่อตรวจจับ concurrent edits  
\- ใช้ Idempotency-Key สำหรับคำสั่งที่ retriable (เช่น approve/activate/deactivate/obsolete/submit) เพื่อลดผลกระทบจากการ retry  
\- ควรคืน 412 เมื่อ ETag ไม่ตรง และ 409 เมื่อตรวจพบ conflict ของ business references

\#\#\# 5.2.3 Page & Journey Bindings (ถ้ามีข้อมูล)  
\- Page Visibility (จาก Page Definitions):  
  \- Product List (/erp/master/products/list) — แสดงรายการสินค้าทุกสถานะ; สามารถกรองตาม Status; คอลัมน์ Status แสดงค่า: Draft | In Review | Approved | Active | Inactive | Obsolete  
  \- Product Create/Edit (/erp/master/products/{id}) — แสดงฟิลด์ทั้งหมด; สถานะ (RO) แสดงสถานะปัจจุบัน  
  \- Product Detail Tabs — Overview | UOM | Vendors | Tax/GL | Images/Docs | Audit — ทุกแท็บมองเห็นข้อมูลตามสิทธิ์; Audit tab แสดง log การอนุมัติ/เปลี่ยนสถานะ  
\- Action Gating (จาก Page Definitions Row/Toolbar Actions):  
  \- \[Create\] — visible to Master Data Admin  
  \- \[Save Draft\] — enabled in Create/Edit for Master Data Admin  
  \- \[Submit\] — visible/enabled when status \= Draft (Create/Edit, List row action)  
  \- \[Approve\] — visible/enabled when status \= In Review (List row action, Detail Header/Approval tab); roles: Finance, Procurement (ตาม DOA)  
  \- \[Activate\] — visible/enabled when status \= Approved; roles: Finance/Approver  
  \- \[Deactivate\] — visible/enabled when status \= Active; roles: Finance/Approver; blocked if open PR/PO/GRN unless override  
  \- \[Obsolete\] — visible/enabled when status in {Active, Inactive}? (ต้องตรวจเงื่อนไข: no on-hand & no open docs)  
  \- \[Edit\] — editable when status in {Draft, In Review, Approved}; edits on Active allowed but critical-field changes require revision+re-approval  
  \- \[Import\]/\[Export\]/\[Print Label\] — Toolbar actions; Import uses POST /api/master/products/import  
\- Journey Triggers (จาก User Journeys):  
  \- J1 — Create & Submit Product: Product Create → \[Save Draft\] → Draft (local); \[Submit\] → Transition: Draft → In Review; Preconditions: mandatory fields (code/name/base\_uom) and at least one barcode; Side Effects: emit product.submitted; API: POST /erp/master/products/{id}:submit; Idempotency-Key recommended during commit.  
  \- J2 — Approve & Activate: Product Detail (Approval) → \[Approve\] → Transition: In Review → Approved; Preconditions: GL+Tax+Base UOM valid; Side Effects: emit product.approved; API: POST /erp/master/products/{id}:approve. Then \[Activate\] → Transition: Approved → Active; Preconditions: validation pass & no open references; Side Effects: emit product.activated; API: POST /erp/master/products/{id}:activate.  
  \- J3 — Maintain UOM & Conversions: Detail → UOM tab → edit conversions → save → If product Active and change is critical → Transition: Active (edit) → In Review (via revision submit); Preconditions: system validates acyclic conversion graph; Side Effects: emit product.revision\_submitted; API: PATCH /erp/master/products/{id} (If-Match) then POST /erp/master/products/{id}:submit if re-approval required.  
  \- J4 — Add/Manage Vendors: Vendors tab → add vendor → save → affects procurement selection; Preconditions: only one preferred per currency enforced; Side Effects: emit product.vendor.updated; API: PATCH /erp/master/products/{id} (If-Match).  
  \- J5 — Edit / Deactivate / Obsolete:  
    \- Edit: allowed in Draft/In Review/Approved; Active edits on critical fields require revision (see J3).  
    \- Deactivate: List/Detail → \[Deactivate\] → Transition: Active → Inactive; Preconditions: no open PR/PO/GRN OR controller override flag; Side Effects: emit product.deactivated; API: POST /erp/master/products/{id}:deactivate.  
    \- Obsolete: List/Detail → \[Obsolete\] → Transition: Active/Inactive → Obsolete; Preconditions: no on-hand AND no open documents; irreversible; Side Effects: emit product.obsoleted; API: POST /erp/master/products/{id}:obsolete.  
  \- J6 — Import / Export / Label:  
    \- Import: Toolbar \[Import\] → preview validation → commit → creates Drafts or updates existing (behavior depends on import mode); Preconditions: CSV validation pass; Side Effects: emit product.imported report; API: POST /api/master/products/import (X-Idempotency-Key)  
    \- Export: Toolbar \[Export\] → GET /api/master/products/export  
    \- Label: \[Print Label\] → GET /api/master/products/{id}:label

\#\# 5.3 Approval Flow  
\- \*\*ระดับการอนุมัติ (Levels):\*\*  
  \- Level 1: Finance (ตรวจ GL/Tax/Base UOM)  
  \- Level 2 (optional, per DOA): Procurement (Buyer) (ตรวจ vendor/preferred/PR-compatibility)  
  \- DOA: อาจระบุว่าเป็น single-approver หรือ multi-approver (ทั้ง Finance และ Procurement) — ให้ปฏิบัติตาม DOA ขององค์กร  
\- \*\*ผู้อนุมัติ (Approvers):\*\*  
  \- Finance  
  \- Procurement (Buyer)  
  \- (หากมี role อื่นตาม DOA ให้ระบุในระบบ)   
\- \*\*หลักฐาน/บันทึก:\*\*  
  \- บันทึก audit ทุกการเปลี่ยนสถานะ: actor, role, timestamp, การกระทำ (approve/reject/submit/activate/deactivate/obsolete), reason/comments, snapshot ก่อน/หลัง (diff)  
  \- Audit tab ใน Product Detail แสดงประวัติทั้งหมด  
\- \*\*การแจ้งเตือน:\*\*  
  \- แจ้งเมื่อ submit → ส่งแจ้งเตือนไปยัง approver(s) ตาม DOA  
  \- แจ้งเมื่อ approve/reject/activate/deactivate/obsolete → ส่งแจ้งเตือนไปยังผู้เกี่ยวข้อง (Master Data Admin, Procurement, Finance, Warehouse)  
  \- การแจ้งสามารถส่งผ่าน internal notifications / email / webhook integrations (กำหนด integration ตามระบบ)

Workflow Diagram (Mermaid syntax; plain lines, no fences)  
stateDiagram-v2  
  \[\*\] \--\> Draft  
  Draft \--\> "In Review": submit  
  "In Review" \--\> Approved: approve (Finance/Procurement per DOA)  
  "In Review" \--\> Draft: reject  
  Approved \--\> Active: activate  
  Active \--\> Inactive: deactivate  
  Active \--\> Obsolete: obsolete  
  Inactive \--\> Obsolete: obsolete  
  Active \--\> Draft: edit-critical \-\> submit (revision flow)

\#\#\# Warnings (ข้อควรระวัง / ข้อมูลไม่ครบ)  
\- Allowed Roles สำหรับการทำ Obsolete ไม่ได้ระบุชัด (ผู้ใดเป็นผู้มีสิทธิ final-obsolete) — ต้องระบุ role เช่น Admin/Finance/Controller ในนโยบายองค์กร  
\- API POST :reject ไม่ปรากฏใน Page Definitions APIs list (Page Definitions ระบุ :approve/:activate/:deactivate/:obsolete แต่ไม่มี :reject) — ระบบต้องยืนยันว่า endpoint /api/master/products/{id}:reject มีอยู่หรือให้ใช้ PATCH เพื่อเปลี่ยนสถานะแทน  
\- Controller override: ระบุไม่ชัดว่า role ใดสามารถใช้ override และต้องมี flag/authorization อย่างไร — ต้องนิยาม policy และ API parameter (e.g., override=true \+ approver signature)  
\- Multi-level approval / DOA flow: รูปแบบ (sequential vs parallel) ไม่ได้ระบุชัด ต้องอิง DOA ขององค์กร  
\- รายละเอียด webhook/event payload schemas ไม่ได้ถูกกำหนด; ควรสรุป schema สำหรับ product.submitted/approved/activated/etc.  
\- การจัดการการนำเข้า (import) — พฤติกรรมเมื่อพบสินค้าที่มีอยู่ (upsert vs create new revision) ไม่ได้ระบุชัด  
\- การจัดการ preferred vendor per currency: enforcement rule (server-side validation) ต้องระบุชัดเจน  
\- ชื่อ role "Approver" ถูกใช้งานในคำอธิบายต้นทาง แต่ canonical\_map ไม่มี "Approver" เป็น role แยก — ใช้ Finance / Procurement (Buyer) แทนตามบริบท  
\- ระบุ ETag header ชื่อ/ฟอร์แมต (If-Match: "\<etag\>") โดยละเอียดยังไม่กำหนดในสเปค API  
\- หากต้องการ endpoint alternative ชื่อมาตรฐาน (inactivate/reactivate/archive) กับ endpoints ที่มีใน Page Definitions (deactivate/obsolete) ต้องแมปให้ชัดเจน

\# 6\. Capabilities Overview & Layout Patterns

\> Feature: \*\*การจัดการสินค้า\*\* · Module: \*\*ข้อมูลมาสเตอร์ × จัดซื้อ × คลังสินค้า/สินค้า × การเงิน (แมป GL)\*\* · Base Path: \*\*/erp/master/products\*\* · Menu: \*\*ERP \> ข้อมูลมาสเตอร์ \> สินค้า\*\*

\#\# 6.1 เป้าหมายและกรอบความสามารถ (ยึดตาม use cases)  
\- รองรับการสร้างสินค้าเป็นร่าง → ส่งตรวจ → อนุมัติ → เปิดใช้งาน (Draft → In Review → Approved → Active)  
\- รองรับการแก้ไขส่วนต่างๆ: Classification, UOM conversions, Barcodes, Vendors, Tax/GL, Dimensions, Attachments  
\- รองรับการบันทึก Audit (who/when/what) สำหรับสถานะและการเปลี่ยนแปลงสำคัญ  
\- รองรับการนำเข้าแบบกลุ่ม (Import CSV/XLSX) ด้วย preview/validation และ X-Idempotency-Key  
\- รองรับการส่งออก (Export CSV/XLSX) และพิมพ์ฉลาก (Label → PDF)  
\- รองรับ Bulk actions/Batch operations ตามสิทธิ์ (Admin รองรับเต็มรูปแบบ, Editor มีข้อจำกัด)  
\- บังคับใช้ RBAC (Viewer / Editor / Approver / Admin) และการป้องกัน concurrency (ETag / If-Match) และ Idempotency

\#\# 6.2 Layout Patterns (ตัวอย่างอ้างอิง — ให้ AI สร้างจริงตามอินพุต)  
\- List Page: Breadcrumb → Page Header → Search/Filter Row → Toolbar (Import/Export/Create) → ActionBar/BulkActions → \[\*\*Table\*\*\] (compact, checkbox แถวซ้ายสุด) → Pagination  
\- Create/Edit Page: Header \[status read-only\] → Main: 12-column grid (8/4) → Left: \[\*\*Form Sections\*\*\] (Classification, Dimensions, Barcodes, UOM, Vendors, Attachments) → Right: \[\*\*Summary / Status / Actions\*\*\]  
\- Detail Page: Header (code, name, status, primary actions) → Tabs (Overview | UOM | Vendors | Tax/GL | Images/Docs | Audit) → Tab content: Key–Value / Tables / Attachment panels  
\- Drawers/Modals: Slide-in Drawer (right) สำหรับ Create/Edit/Import/Preview; Confirm Modal สำหรับลบ/obsolete/override; Drawer/Modal ต้องมี focus-trap และ sticky footer action bar

\#\# 6.3 Navigation Rules  
\- URL pattern:  
  \- List \= \`\<base\_path\>\`    
  \- Create \= \`\<base\_path\>/new\`    
  \- Detail \= \`\<base\_path\>/:id\`    
  \- Edit \= \`\<base\_path\>/:id/edit\`  
\- ห้ามเข้าหน้า Edit เมื่อสถานะเป็น \*\*Obsolete\*\* (immutable) / Edit สำหรับ Active จะอนุญาตแต่หากเปลี่ยนฟิลด์ "critical" จะสร้าง revision \+ ต้อง re-submit (re-approval)  
\- หาก RBAC ไม่เพียงพอ → redirect ไปหน้า List \+ แสดง toast 403  
\- Create/Update สำเร็จ → redirect → Detail พร้อม toast success  
\- ETag mismatch (412) → ดึงข้อมูลล่าสุด → เปิด dialog ช่วย merge

\#\# 6.4 Microcopy & States (i18n/A11y)  
\- สายข้อความหลักต้องเป็นภาษาไทย (Success/Error/Empty/403/409/412) พร้อม aria-label และ role  
\- Focus order: toolbar → search/filters → table → pagination → toast  
\- ปุ่มหลัก (primary) อยู่ขวาสุดของ toolbar/footer เสมอ

\#\# 6.5 Page–Journey Cohesion (ใหม่)  
\- ทุกหน้า/โมดัลต้องผูกปุ่ม/แอ็กชันกับ Journey step ชัดเจน: ปุ่ม → journey\_id → API → preconditions → side-effects (events/webhooks) → navigation  
\- Visibility & Action Gating ต้องระบุตาม Role (A2) และ Status Model (A3)

Warnings (ข้อควรระวัง)  
\- ยังไม่ระบุ role ชัดเจนสำหรับ "controller override" (ใครสามารถ bypass guard เปิด/ปิดสินค้าที่มีเอกสารเปิด) — ต้องกำหนดในนโยบายองค์กร  
\- Endpoint \`:reject\` ถูกอ้างถึงใน transitions แต่ไม่ได้อยู่ใน Page Definitions APIs list — กรุณายืนยัน API (POST /api/master/products/{id}:reject) หรือใช้ PATCH เพื่อเปลี่ยนสถานะ  
\- การแบ่งข้อมูลตาม org/site-level (org\_id scope) ไม่ได้ระบุ — หากต้องการควรเพิ่มนโยบาย filtering  
\- รายการฟิลด์ที่ถือเป็น "critical" (ต้อง re-approval เมื่อแก้ไขขณะ Active) ควรระบุชัด (ปัจจุบันอ้างถึง base\_uom, tax/GL, tracking แต่ยังไม่ครบ)  
\- template\_source: ใช้เทมเพลตจากไลบรารี (packingList.v1, createDrawer.v2, editStepperDrawer.v1, viewDrawer.v1, importDrawer.v1, deleteConfirm.v1) — หากต้องการปรับเลย์เอาต์หลักต้องยืนยัน  
\- missing\_components: สร้าง placeholder components ใหม่ใน sheet สำหรับชุดคอมโพเนนต์เฉพาะฟีเจอร์ (ดู Section 7 Warnings)

\---

\# 7\. Page Inventory (URLs & Screens)

\> Feature: \*\*การจัดการสินค้า\*\* · Base Path: \*\*/erp/master/products\*\*

\#\# 7.1 URLs & Routing  
\- \*\*List\*\*: \`/erp/master/products\` — เริ่ม \`?page=1\&page\_size=25\&sort=-updated\_at\`  
\- \*\*Create\*\*: \`/erp/master/products/new\`  
\- \*\*Detail\*\*: \`/erp/master/products/:id\`  (tabs: \`/overview\`, \`/uom\`, \`/vendors\`, \`/tax-gl\`, \`/images\`, \`/audit\`)  
\- \*\*Edit\*\*: \`/erp/master/products/:id/edit\` (drawer)  
\- \*\*Import Drawer\*\*: \`/erp/master/products/import\` (drawer)  
\- \*\*Label / Print\*\*: flow via modal/drawer → GET \`/api/master/products/{id}:label\`  
\- \*\*Routing guards\*\*: ห้าม Edit เมื่อ \`status=Obsolete\`; RBAC ไม่พอ → redirect \`/erp/master/products\` \+ toast 403

\#\# 7.2 Page Definitions

\#\#\# 7.2.1 Product List — \`/erp/master/products\` (route: list)  
\*\*Purpose\*\*: แสดงรายการสินค้าแบบค้นหา/กรอง, ทำ bulk actions และเปิดรายการเพื่อดู/แก้ไข/เปลี่ยนสถานะ

\#\#\#\# Layout  
\- Grid Spec (จาก template packingList.v1): 12col; fixed-header; search row \+ filters; toolbar right-aligned (Import, Export, Create); table density=compact; checkbox แถวซ้ายสุด; numeric columns ชิดขวา

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| Breadcrumbs: ERP › ข้อมูลมาสเตอร์ › สินค้า                                  |  
\+------------------------------------------------------------------------------+  
| H1 Title: รายการสินค้า                                                         |  
| H2 Subtitle: ดูรายการสินค้าและจัดการสถานะ                                      |  
\+------------------------------------------------------------------------------+  
| 🔍 Search: \[ ค้นหาโค้ด/ชื่อ/บาร์โค้ด \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ \]  |  
|                                                     Filter: 6 selected ▼    |  
|                                                     \[ Advanced Filters \]     |  
\+------------------------------------------------------------------------------+  
|                                                     \[ นำเข้า \] \[ ส่งออก \] \[ สร้าง \] |  
\+------------------------------------------------------------------------------+  
| \[ \] Code  | Name           | Type   | Category | Base UOM | Tracking | Preferred |  
|--------------+------------+------------+--------------+-------------+--------|  
| … (rows rendered by data source; numeric → right, badges center)            |  
\+------------------------------------------------------------------------------+  
| Showing 1–25 of 1,234                     « Previous  \[1\]  Next »           |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- breadcrumb → \[\*\*Breadcrumbs\*\*\]  
\- header\_title → \[\*\*PageHeaderTitle\*\*\] (แสดง \*\*รายการสินค้า\*\*)  
\- header\_desc → \[\*\*PageDescription\*\*\] (สั้น)  
\- toolbar\_left → \[\*\*SearchBar\*\*\] (field: \*\*q\*\*)  
\- controls\_top\_right → \[\*\*FilterDropdown\*\*\] \+ \[\*\*AdvancedFilterDrawerV2\*\*\]  
\- toolbar\_right → \[\*\*Button\*\* (Import), \*\*Button\*\* (Export), \*\*Button\*\* (Create)\]  
\- main → \[\*\*MasterDataTable\*\*\] (configured as \[\*\*ProductTable\*\*\])  
  \- Table columns mapping (MasterDataTable row):  
    \- Code → clickable link to Detail (field: \*\*code\*\*) \[\*\*Link\*\*\]  
    \- Name → field: \*\*name\*\* \[\*\*Text\*\*\]  
    \- Type → field: \*\*type\*\* \[\*\*Badge\*\*\]  
    \- Category → field: \*\*category\_id\*\* (render name) \[\*\*Text\*\*\]  
    \- Base UOM → field: \*\*base\_uom\*\* \[\*\*Text\*\*\]  
    \- Tracking → field: \*\*tracking\*\* \[\*\*StatusBadge\*\*\]  
    \- Preferred Vendor → derived from ProductVendor (field: \*\*preferred\_vendor\*\*) \[\*\*Text\*\*\]  
    \- Status → field: \*\*status\*\* \[\*\*StatusBadge\*\*\]  
    \- Updated At → field: \*\*updated\_at\*\* \[\*\*DateTime\*\*\]  
\- footer\_info → \[\*\*ResultsInfo\*\*\]  
\- pagination → \[\*\*PaginationControls\*\*\]

\#\#\#\# Actions / Events & Binding  
\- Toolbar:  
  \- \[\*\*Create\*\*\] \[\*\*Button\*\*\] → GET \`/erp/master/products/new\` (open Create Drawer)  
  \- \[\*\*Import\*\*\] \[\*\*Button\*\*\] → open \`/erp/master/products/import\` \[\*\*ImportDrawer\*\*\]  
  \- \[\*\*Export\*\*\] \[\*\*Button\*\*\] → GET \`/api/master/products/export\` (scope: product.export)  
\- Row actions (per-row, visible by role/status):  
  \- \[\*\*Open\*\*\] → GET \`/api/master/products/{id}\` → open Detail \`/erp/master/products/{id}\`  
  \- \[\*\*Edit\*\*\] → open Edit drawer \`/erp/master/products/{id}/edit\` (guard: status \!= Obsolete; role: Admin or Editor partial)  
  \- \[\*\*Submit\*\*\] → POST \`/api/master/products/{id}:submit\` (headers: X-Idempotency-Key) — visible status=Draft; role: Admin or Editor (C1)  
  \- \[\*\*Approve\*\*\] → POST \`/api/master/products/{id}:approve\` (role: Approver/Finance) — visible status=In Review  
  \- \[\*\*Activate\*\*\] → POST \`/api/master/products/{id}:activate\` (role: Admin/Approver) — visible status=Approved  
  \- \[\*\*Deactivate\*\*\] → POST \`/api/master/products/{id}:deactivate\` (role: Approver/Admin) — visible status=Active; precondition: no open PR/PO/GRN else API returns 409  
  \- \[\*\*Obsolete\*\*\] → POST \`/api/master/products/{id}:obsolete\` (role: Admin) — preconditions: on-hand \== 0 && no open documents  
  \- \[\*\*Print Label\*\*\] → GET \`/api/master/products/{id}:label\` (open Label modal/preview) — visible to all roles per matrix

\#\#\#\# Validation  
\- Search/Filter params validated server-side (status/type/category/vendor/tracking/updated\_range)  
\- Bulk export limited by max rows (system policy)  
\- Deactivate/Obsolete returns 409 if business guards fail

\#\#\#\# RBAC & Status Gating  
\- List visible to all roles  
\- Row action visibility per RBAC matrix (A2) and status model (A3)  
\- If role not allowed for action → action hidden or disabled (preferred: hidden) and attempt to call API returns 403

\#\#\#\# Microcopy (i18n/A11y)  
\- Search placeholder: \*\*ค้นหาโค้ด/ชื่อ/บาร์โค้ด\*\*  
\- Button labels: \*\*สร้าง\*\*, \*\*นำเข้า\*\*, \*\*ส่งออก\*\*  
\- Status badges aria-label: e.g., aria-label="สถานะ: Active"  
\- Table rows: checkbox first column with aria-label="เลือกสินค้า {code}"

\#\#\#\# Journey Bindings  
\- J1 (Create & Submit): List \`/erp/master/products\` → \[Create\] → open Create Drawer → Fill → \[Save Draft\] → Draft local → \[Submit\] → POST \`/api/master/products/{id}:submit\` → status=In Review  
\- J2 (Approve & Activate): List row \[Approve\] → POST \`/api/master/products/{id}:approve\` → status=Approved → then \[Activate\] → POST \`/api/master/products/{id}:activate\` → status=Active  
\- J6 (Import/Export/Label): \[Import\] → open Import Drawer → POST \`/api/master/products/import\` (X-Idempotency-Key); \[Export\] → GET \`/api/master/products/export\`; \[Print Label\] → GET \`/api/master/products/{id}:label\`

\#\#\#\# Notes  
\- Table head fixed; row density compact; numeric columns right-aligned

\---

\#\#\# 7.2.2 Product Create — \`/erp/master/products/new\`  
\*\*Purpose\*\*: สร้างสินค้าใหม่ (Save Draft / Submit) — multi-section form พร้อม attachments และตาราง barcodes/uom/vendors

\#\#\#\# Layout  
\- Template: createDrawer.v2 — Drawer:right; width=40%; vertical form; footer sticky with \[Cancel\] \[Save as Draft\] \[Create\]

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| H1: สร้างสินค้า                                            \[ ☐ Expand \] \[  ✖  \] |  
| Sub: กรอกข้อมูลสินค้า (โค้ด, ชื่อ, UOM, GL/Tax ฯลฯ)                          |  
\+------------------------------------------------------------------------------+  
| Form (scrollable)                                                            |  
| ┌ Section: Header                                                            |  
| | \*\*รหัสสินค้า\*\* \[Input\] (field: \*\*code\*\*)                                   |  
| | \*\*ชื่อสินค้า\*\* \[Input\] (field: \*\*name\*\*)                                    |  
| | \*\*ประเภท\*\* \[Select ▾\] (field: \*\*type\*\*)                                     |  
| | \*\*หมวดหมู่\*\* \[Select ▾\] (field: \*\*category\_id\*\*)                            |  
| └─────────────────────────────────────────────────────────────────────────────|  
| ┌ Section: Classification                                                    |  
| | \*\*Base UOM\*\* \[Select ▾\] (field: \*\*base\_uom\*\*)                               |  
| | \*\*Purchase UOM\*\* \[Select ▾\] (field: \*\*purchase\_uom\*\*)                       |  
| | \*\*Tracking\*\* \[Select ▾\] (field: \*\*tracking\*\*)                                |  
| | \*\*Tax Code\*\* \[Select ▾\] (field: \*\*tax\_code\_id\*\*)                             |  
| | \*\*GL Inventory\*\* \[Select ▾\] (field: \*\*gl\_inventory\_acct\_id\*\*)                |  
| | \*\*GL Expense\*\* \[Select ▾\] (field: \*\*gl\_expense\_acct\_id\*\*)                    |  
| └─────────────────────────────────────────────────────────────────────────────|  
| ┌ Section: Dimensions                                                        |  
| | \*\*Weight\*\* \[InputNumber\] (field: \*\*weight\*\*)  \*\*Length/Width/Height\*\* etc.  |  
| └─────────────────────────────────────────────────────────────────────────────|  
| ┌ Section: Barcodes (table)                                                  |  
| | \[\*\*ProductBarcodeTable\*\*\] columns: symbology, value, is\_primary             |  
| └─────────────────────────────────────────────────────────────────────────────|  
| ┌ Section: UOM Conversions (table)                                           |  
| | \[\*\*ProductUomConvTable\*\*\] columns: from\_uom, to\_uom, factor                |  
| └─────────────────────────────────────────────────────────────────────────────|  
| ┌ Section: Vendors (table)                                                   |  
| | \[\*\*ProductVendorsTable\*\*\] columns: vendor\_id, preferred, moq, lead\_time    |  
| └─────────────────────────────────────────────────────────────────────────────|  
| ┌ Section: Attachments                                                       |  
| | \[\*\*FileUploader\*\*\] (images/docs)                                           |  
| └─────────────────────────────────────────────────────────────────────────────|  
\+------------------------------------------------------------------------------+  
| Left:  \[Cancel\]                             Right: \[Save as Draft\] \[Create\]  |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- drawer\_header → \[\*\*DrawerHeader\*\*\] (title/subtitle/actions)  
\- form\_body → \[\*\*FormLayout\*\*\]  
\- form\_sections → \[\*\*ProductForm\*\*\] (composed)  
  \- Header fields:  
    \- \*\*code\*\* → \[\*\*Input\*\*\] (field: \*\*code\*\*)  
    \- \*\*name\*\* → \[\*\*Input\*\*\] (field: \*\*name\*\*)  
    \- \*\*type\*\* → \[\*\*Select\*\*\] (field: \*\*type\*\*, enum: Stock|NonStock|Service)  
    \- \*\*category\_id\*\* → \[\*\*Select\*\*\] (field: \*\*category\_id\*\*)  
    \- \*\*status\*\* → \[\*\*StatusBadge\*\*\] (field: \*\*status\*\*, RO)  
    \- \*\*remarks\*\* → \[\*\*Textarea\*\*\] (field: \*\*remarks\*\*)  
  \- Classification:  
    \- \*\*base\_uom\*\*, \*\*purchase\_uom\*\*, \*\*tracking\*\*, \*\*tax\_code\_id\*\*, \*\*gl\_inventory\_acct\_id\*\*, \*\*gl\_expense\_acct\_id\*\* → \[\*\*Select\*\*\]/\[\*\*Input\*\*\] per field  
  \- Dimensions:  
    \- \*\*weight\*\*, \*\*length\*\*, \*\*width\*\*, \*\*height\*\*, \*\*weight\_uom\*\*, \*\*volume\_uom\*\* → \[\*\*InputNumber\*\*\]/\[\*\*Select\*\*\]  
  \- Barcodes:  
    \- table: \[\*\*ProductBarcodeTable\*\*\] rows (fields: \*\*symbology\*\*, \*\*value\*\*, \*\*is\_primary\*\*) → \[\*\*Input\*\*\]/\[\*\*Select\*\*\]/\[\*\*Checkbox\*\*\]  
  \- UOM Conversions:  
    \- table: \[\*\*ProductUomConvTable\*\*\] (fields: \*\*from\_uom\*\*, \*\*to\_uom\*\*, \*\*factor\*\*)  
  \- Vendors:  
    \- table: \[\*\*ProductVendorsTable\*\*\] (fields: \*\*vendor\_id\*\*, \*\*vendor\_sku\*\*, \*\*preferred\*\*, \*\*moq\*\*, \*\*lead\_time\_days\*\*, \*\*price\_hint\*\*, \*\*currency\*\*)  
  \- Attachments:  
    \- \[\*\*FileUploader\*\*\] for images/docs (ProductImage/ProductDoc)

\- footer\_buttons → \[\*\*Button\*\*(cancel), \*\*Button\*\*(save\_draft), \*\*Button\*\*(create)\]

\#\#\#\# Actions / Events & Binding  
\- \[\*\*Save as Draft\*\*\] → POST \`/api/master/products\` (X-Idempotency-Key) → 201 draft (response: id, etag)  
\- \[\*\*Create\*\*\] (aka Submit on create) → if user chooses Save+Submit: POST \`/api/master/products\` then POST \`/api/master/products/{id}:submit\` (X-Idempotency-Key recommended)  
\- Attachment upload → multipart POST to file service (file\_url stored in ProductImage/ProductDoc) — (implementation detail beyond APIs list)  
\- Client must collect response ETag and store for subsequent PATCH (If-Match)

\#\#\#\# Validation  
\- Required: \*\*code\*\*, \*\*name\*\*, \*\*base\_uom\*\*  
\- Must have at least one barcode row with \*\*is\_primary\*\* \= true (J1)  
\- GL/tax required for submission if org policy requires (precondition for Approved)  
\- UOM conversion table must validate acyclic graph (no cycles) on client-side prior to submit  
\- Vendors: one \*\*preferred\*\* per currency validated client/server-side

\#\#\#\# RBAC & Status Gating  
\- Create Drawer visible only to \*\*Admin\*\*  
\- Editor role cannot access full create (per A2)  
\- \[\*\*Create\*\*\]/\[\*\*Save Draft\*\*\] actions allowed: Admin; Import uses X-Idempotency-Key and only Admin

\#\#\#\# Microcopy (i18n/A11y)  
\- Create primary button: \*\*สร้าง\*\* aria-label="สร้างสินค้า"  
\- Save draft tooltip: \*\*บันทึกเป็นร่าง\*\*  
\- Barcode table column header checkbox aria: "ตั้งเป็นบาร์โค้ดหลัก"

\#\#\#\# Journey Bindings  
\- J1: Create Drawer \`/erp/master/products/new\` → \[Save as Draft\] → POST \`/api/master/products\` (X-Idempotency-Key) → Draft  
\- J1: After draft saved → \[Submit\] (in drawer or after save) → POST \`/api/master/products/{id}:submit\` → status=In Review; Preconditions: required fields \+ ≥1 barcode

\#\#\#\# Notes  
\- FormGuard (\[\*\*FormGuard\*\*\]) to warn on unsaved changes and ensure If-Match for subsequent edits

\---

\#\#\# 7.2.3 Product Edit — \`/erp/master/products/:id/edit\` (drawer)  
\*\*Purpose\*\*: แก้ไขข้อมูลสินค้า (สร้าง revision หากแก้ไขฟิลด์ critical ขณะ Active)

\#\#\#\# Layout  
\- Template: editStepperDrawer.v1 — Drawer:right; width=45%; stepper optional; footer sticky with \[Back\]\[Next\]\[Save\]

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| H1: แก้ไขสินค้า — PROD-000123                         \[ ☐ Expand \] \[ ✖ \]    |  
| Sub: แก้ไขข้อมูลสินค้า (ETag required)                                       |  
\+------------------------------------------------------------------------------+  
| Stepper: ● 1\. Header  — ○ 2\. Classification — ○ 3\. Barcodes — ○ 4\. Vendors     |  
\+------------------------------------------------------------------------------+  
| Section: Header                                                              |  
| | \*\*รหัสสินค้า\*\* \[Input (readonly when created)\] (field: \*\*code\*\*)           |  
| | \*\*ชื่อสินค้า\*\* \[Input\] (field: \*\*name\*\*)                                   |  
| | \*\*สถานะ\*\* \[StatusBadge\] (field: \*\*status\*\*) (RO)                           |  
\+------------------------------------------------------------------------------+  
| (Tabs optional inside drawer)                                                 |  
\+------------------------------------------------------------------------------+  
| Left: \[Cancel\]                             Right: \[← Back\] \[Next →\] \[Save\]    |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- drawer\_header → \[\*\*DrawerHeader\*\*\] (meta: entity\_code)  
\- stepper → \[\*\*Stepper\*\*\] (current step indicator)  
\- content\_sections → \[\*\*ProductForm\*\*\] (pre-filled, supports ETag via \[\*\*FormGuard\*\*\])  
\- footer\_buttons → \[\*\*Button\*\*(cancel), \*\*Button\*\*(back), \*\*Button\*\*(next), \*\*Button\*\*(save)\]

\#\#\#\# Actions / Events & Binding  
\- Load: GET \`/api/master/products/{id}\` → returns ETag  
\- Save: PATCH \`/api/master/products/{id}\` (If-Match: \`\<etag\>\`) → 200 or 412  
\- If client changes critical field while \`status=Active\` → client should:  
  \- PATCH as draft revision (server stores revision) → POST \`/api/master/products/{id}:submit\` to start re-approval (emit product.revision\_submitted)  
\- Buttons:  
  \- \[\*\*Save\*\*\] → PATCH \`/api/master/products/{id}\` (If-Match)  
  \- \[\*\*Submit\*\*\] (if triggered by critical-edit) → POST \`/api/master/products/{id}:submit\`  
\- Concurrency:  
  \- On 412 → show merge dialog and option to refresh

\#\#\#\# Validation  
\- Same field validations as Create  
\- Critical field edit detection list (base\_uom, tax\_code\_id, gl\_\* , tracking) → triggers revision flow

\#\#\#\# RBAC & Status Gating  
\- Edit allowed: Admin for all fields; Editor limited to vendors and non-critical fields (C1)  
\- Edit disabled when status \= Obsolete (read-only)

\#\#\#\# Microcopy (i18n/A11y)  
\- ETag mismatch message (ไทย): \*\*ข้อมูลเปลี่ยนแปลงแล้ว กรุณาดึงข้อมูลล่าสุดก่อนบันทึก\*\* (provide action: ดึงข้อมูลใหม่ / ยุติ)  
\- Save button label: \*\*บันทึก\*\*

\#\#\#\# Journey Bindings  
\- J5 Edit flow: Detail → \[Edit\] → open Edit Drawer → change critical → PATCH (If-Match) → server creates revision → POST \`/api/master/products/{id}:submit\` → status transitions to In Review (revision flow)

\#\#\#\# Notes  
\- FormGuard must prompt to obtain latest ETag before saving changes

\---

\#\#\# 7.2.4 Product Detail — Overview Tab — \`/erp/master/products/:id\` (tab: overview)  
\*\*Purpose\*\*: ดูข้อมูลสินค้าโดยรวม (Header \+ Key details) และเข้าถึง action (Submit/Approve/Activate/Deactivate/Obsolete/Print Label)

\#\#\#\# Layout  
\- Template: viewDrawer.v1 (applied as full Detail page layout) — header \+ tabs \+ key-value sections

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| Breadcrumbs: ERP › ข้อมูลมาสเตอร์ › สินค้า › PROD-000123                    |  
\+------------------------------------------------------------------------------+  
| H1: PROD-000123 — ชื่อสินค้า                                       \[Edit\] \[⋯\] |  
| Sub: ประเภท: Stock · หมวด: Raw Materials · สถานะ: Active                       |  
\+------------------------------------------------------------------------------+  
| Tabs: Overview | UOM | Vendors | Tax/GL | Images/Docs | Audit                 |  
\+------------------------------------------------------------------------------+  
| Section: Key Details                                                         |  
|  • รหัสสินค้า : PROD-000123                                                  |  
|  • ชื่อสินค้า : ชื่อจริงสินค้า                                                |  
|  • ประเภท : Stock                                                           |  
|  • Base UOM : PCS                                                            |  
|  • Tracking : Lot                                                            |  
|  • GL Inventory : 1100-INV                                                   |  
|  • Updated At : 2025-11-01 09:12                                              |  
\+------------------------------------------------------------------------------+  
| Actions (header/right) : \[Submit\] \[Approve\] \[Activate\] \[Deactivate\] \[Obsolete\] |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- drawer\_header / page header → \[\*\*DrawerHeader\*\*\] / \[\*\*PageHeader\*\*\]  
\- tabs → \[\*\*Tabs\*\*\] (Overview default)  
\- content\_sections → \[\*\*KeyValueGrid-2col\*\*\] for overview fields  
\- footer\_buttons / header actions → \[\*\*StatusActions\*\*\], \[\*\*ApprovalActions\*\*\], \[\*\*Button\*\* Print Label\]

Fields / Components mapping (Overview)  
\- \*\*code\*\* → \[\*\*Text\*\*\] (field: \*\*code\*\*)  
\- \*\*name\*\* → \[\*\*Text\*\*\] (field: \*\*name\*\*)  
\- \*\*type\*\* → \[\*\*Badge\*\*\] (field: \*\*type\*\*)  
\- \*\*category\_id\*\* → \[\*\*Text\*\*\]  
\- \*\*base\_uom\*\* → \[\*\*Text\*\*\]  
\- \*\*purchase\_uom\*\* → \[\*\*Text\*\*\]  
\- \*\*tracking\*\* → \[\*\*StatusBadge\*\*\]  
\- \*\*status\*\* → \[\*\*StatusBadge\*\*\]  
\- \*\*gl\_inventory\_acct\_id\*\*, \*\*gl\_expense\_acct\_id\*\*, \*\*tax\_code\_id\*\* → \[\*\*Masked/RO\*\* unless role Approver/Admin\]  
\- Primary actions in header mapped to StatusActions component

\#\#\#\# Actions / Events & Binding  
\- \[\*\*Edit\*\*\] → open Edit Drawer \`/erp/master/products/:id/edit\` (role gating)  
\- \[\*\*Submit\*\*\] → POST \`/api/master/products/{id}:submit\` (visible when status=Draft)  
\- \[\*\*Approve\*\*\] → POST \`/api/master/products/{id}:approve\` (visible when status=In Review, role=Approver)  
\- \[\*\*Activate\*\*\] → POST \`/api/master/products/{id}:activate\` (visible when status=Approved)  
\- \[\*\*Deactivate\*\*\] → POST \`/api/master/products/{id}:deactivate\` (visible when status=Active; precondition: no open PR/PO/GRN else 409\)  
\- \[\*\*Obsolete\*\*\] → POST \`/api/master/products/{id}:obsolete\` (preconditions: on-hand \== 0 && no open docs)  
\- \[\*\*Print Label\*\*\] → GET \`/api/master/products/{id}:label\` → open PDF preview

\#\#\#\# Validation  
\- Attempt to Approve requires GL/Tax/Base UOM present → otherwise server returns 422  
\- Activate requires no open references → server returns 409 if conflict

\#\#\#\# RBAC & Status Gating  
\- Read: all roles  
\- Edit: Admin or Editor (conditional)  
\- Approve/Activate: Approver/Finance (A2), Admin permitted per DOA

\#\#\#\# Microcopy (i18n/A11y)  
\- Status badges: \*\*สถานะ: Draft / In Review / Approved / Active / Inactive / Obsolete\*\*  
\- Approve modal label: \*\*ยืนยันการอนุมัติสินค้า\*\*

\#\#\#\# Journey Bindings  
\- J2: Detail \`/erp/master/products/:id\` → \[Approve\] → POST \`/api/master/products/{id}:approve\` → on success emit product.approved and keep user on Detail with toast  
\- J2: After approve → \[Activate\] → POST \`/api/master/products/{id}:activate\` → emit product.activated and toast \+ possibly redirect to usage docs

\---

\#\#\# 7.2.5 Product Detail — UOM Tab — \`/erp/master/products/:id/uom\`  
\*\*Purpose\*\*: จัดการหน่วยและอัตราแปลง (validate acyclic graph; critical-change triggers re-approval)

\#\#\#\# Layout  
\- Template: viewDrawer.v1 content section with DataTable for conversions; 12-col with table

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| Tabs: Overview | UOM (active) | Vendors | Tax/GL | Images/Docs | Audit        |  
\+------------------------------------------------------------------------------+  
| Section: UOM Conversions                                                      |  
| Columns: From UOM | To UOM | Factor | Actions                                 |  
| \--------------------------------------------------------------------------- |  
| PCS              | BOX    | 0.100000 | \[Edit\] \[Delete\]                         |  
| …                                                                           |  
\+------------------------------------------------------------------------------+  
| \[Add Conversion\] (bottom-left)                                \[Save Changes\]  |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- tabs → \[\*\*Tabs\*\*\]  
\- content\_sections → \[\*\*ProductUomConvTable\*\*\]  
  \- fields: \*\*from\_uom\*\* \[\*\*Select\*\*\], \*\*to\_uom\*\* \[\*\*Select\*\*\], \*\*factor\*\* \[\*\*InputNumber\*\*\]

\#\#\#\# Actions / Events & Binding  
\- Add row → client insert → validate acyclic → PATCH \`/api/master/products/{id}\` (If-Match)  
\- Edit row → PATCH \`/api/master/products/{id}\` (If-Match)  
\- On save: if product \*\*status=Active\*\* and change touches critical unit mapping → client should POST \`/api/master/products/{id}:submit\` to start re-approval (emit product.revision\_submitted)

\#\#\#\# Validation  
\- Acyclic graph validation (client & server): disallow cycles; numeric factor precision decimal(18,6)  
\- Unique pair (from\_uom, to\_uom) per product

\#\#\#\# RBAC & Status Gating  
\- Create/Update conversions: Admin full; Editor cannot (A2)  
\- If Active & critical-change → requires re-approval (submit)

\#\#\#\# Microcopy (i18n/A11y)  
\- Add button: \*\*เพิ่มอัตราแปลง\*\*  
\- Validation message: \*\*ไม่สามารถสร้างวงจรการแปลง (cycle) ได้\*\*

\#\#\#\# Journey Bindings  
\- J3: Detail UOM tab → add/edit conversions → validate → if Active+critical → PATCH \+ POST \`/api/master/products/{id}:submit\` → status In Review for revision

\---

\#\#\# 7.2.6 Product Detail — Vendors Tab — \`/erp/master/products/:id/vendors\`  
\*\*Purpose\*\*: จัดการข้อมูล vendor ต่อสินค้าหนึ่งรายการ (preferred per currency constraint)

\#\#\#\# Layout  
\- Template: viewDrawer.v1 with table card for vendors

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| Tabs: Overview | UOM | Vendors (active) | Tax/GL | Images/Docs | Audit        |  
\+------------------------------------------------------------------------------+  
| Section: Vendors                                                             |  
| Columns: Vendor | Vendor SKU | Preferred | MOQ | Lead Time (days) | Price  |  
| \--------------------------------------------------------------------------- |  
| Vendor A    | SKU-A        | ●         | 10  | 7                | 12.3456  |  
| …                                                                           |  
\+------------------------------------------------------------------------------+  
| \[Add Vendor\]                                \[Save Vendors\]                   |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- content\_sections → \[\*\*ProductVendorsTable\*\*\]  
  \- fields: \*\*vendor\_id\*\* \[\*\*Select\*\*\], \*\*vendor\_sku\*\* \[\*\*Input\*\*\], \*\*preferred\*\* \[\*\*Checkbox\*\*\], \*\*moq\*\* \[\*\*InputNumber\*\*\], \*\*lead\_time\_days\*\* \[\*\*InputNumber\*\*\], \*\*price\_hint\*\* \[\*\*InputNumber\*\*\], \*\*currency\*\* \[\*\*Select\*\*\]

\#\#\#\# Actions / Events & Binding  
\- Add/Edit/Delete vendor row → PATCH \`/api/master/products/{id}\` (If-Match)  
\- Server validates: only one \*\*preferred\*\* per currency; if violation → 422

\#\#\#\# Validation  
\- One preferred vendor per currency  
\- MOQ ≥ 0; lead\_time\_days integer ≥ 0; price\_hint decimal(18,4)

\#\#\#\# RBAC & Status Gating  
\- Editor (Procurement) can add/update vendor rows (C1)  
\- Admin can full manage vendors

\#\#\#\# Microcopy (i18n/A11y)  
\- Preferred hint: \*\*เลือกผู้ขายหลักต่อสกุลเงินเดียวเท่านั้น\*\*  
\- Add vendor button: \*\*เพิ่มผู้ขาย\*\*

\#\#\#\# Journey Bindings  
\- J4: Vendors tab → add vendor → client-side validate preferred-per-currency → PATCH \`/api/master/products/{id}\` (If-Match) → emit product.vendor.updated

\---

\#\#\# 7.2.7 Product Detail — Tax/GL Tab — \`/erp/master/products/:id/tax-gl\`  
\*\*Purpose\*\*: ตรวจสอบ/แก้ไขการแมปบัญชีและรหัสภาษี (Finance review area)

\#\#\#\# Layout  
\- Template: viewDrawer.v1 key-value card with edit controls (GL accounts masked for non-approver)

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| Tabs: Overview | UOM | Vendors | Tax/GL (active) | Images/Docs | Audit        |  
\+------------------------------------------------------------------------------+  
| Section: Tax & GL Mapping                                                    |  
|  • Tax Code : VAT-7                                                       \[Edit\]|  
|  • GL Inventory Account : 1100-INV (masked for non-Finance)                 |  
|  • GL Expense Account : 5000-COGS                                         |  
\+------------------------------------------------------------------------------+  
| \[Request Change\] (for non-Finance)                      \[Save Changes\] \[Approve\] |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- content\_sections → \[\*\*KeyValueGrid\*\*\] \+ \[\*\*SelectDropdown\*\*\] for edit  
  \- \*\*tax\_code\_id\*\*, \*\*gl\_inventory\_acct\_id\*\*, \*\*gl\_expense\_acct\_id\*\* → \[\*\*Select\*\*\] (Finance/Admin editable; Viewer masked)

\#\#\#\# Actions / Events & Binding  
\- Save changes → PATCH \`/api/master/products/{id}\` (If-Match)  
\- Approve (finance) → POST \`/api/master/products/{id}:approve\` (when status=In Review)  
\- Change detection for critical fields triggers revision flow if product Active

\#\#\#\# Validation  
\- GL accounts must exist in GL master; server returns 422 if invalid  
\- Field-level masking for roles without permission

\#\#\#\# RBAC & Status Gating  
\- Edit visible to Approver/Finance and Admin only  
\- Viewer sees read-only masked fields

\#\#\#\# Microcopy (i18n/A11y)  
\- Field helper: \*\*GL account จำเป็นสำหรับการอนุมัติ\*\*

\#\#\#\# Journey Bindings  
\- J2: Finance reviews Tax/GL tab → \[Approve\] → POST \`/api/master/products/{id}:approve\`

\---

\#\#\# 7.2.8 Product Detail — Images/Docs Tab — \`/erp/master/products/:id/images\`  
\*\*Purpose\*\*: ดู/อัปโหลดรูปและเอกสารแนบ (Spec/MSDS/Cert/Other)

\#\#\#\# Layout  
\- Template: viewDrawer.v1 attachment card \+ file list

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| Tabs: Overview | UOM | Vendors | Tax/GL | Images/Docs (active) | Audit      |  
\+------------------------------------------------------------------------------+  
| Section: Images                                                               |  
| \[ Thumbnail grid: primary image highlighted \]                                 |  
\+------------------------------------------------------------------------------+  
| Section: Documents                                                            |  
| Columns: Doc Type | File Name | Uploaded By | Actions (Download/Delete)     |  
\+------------------------------------------------------------------------------+  
| \[Upload Image\] \[Upload Document\]                                              |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- content\_sections → \[\*\*AttachmentPanel\*\*\], \[\*\*FileUploader\*\*\]  
  \- ProductImage: \*\*url\*\*, \*\*alt\_text\*\*, \*\*is\_primary\*\*  
  \- ProductDoc: \*\*file\_url\*\*, \*\*doc\_type\*\*

\#\#\#\# Actions / Events & Binding  
\- Upload image/doc → file service → PATCH \`/api/master/products/{id}\` (If-Match) with returned file\_url  
\- Download → direct GET to file\_url

\#\#\#\# Validation  
\- Allowed doc types: Spec|MSDS|Cert|Other  
\- Max file size/config per system policy

\#\#\#\# RBAC & Status Gating  
\- Upload/Delete allowed for Admin; Editor limited for docs images tied to vendors maybe per policy

\#\#\#\# Microcopy (i18n/A11y)  
\- Upload hint: \*\*รองรับไฟล์ .jpg .png .pdf ขนาดไม่เกิน 10MB\*\*

\#\#\#\# Journey Bindings  
\- J1 optional attachments step: Create → Upload images/docs before Submit

\---

\#\#\# 7.2.9 Product Detail — Audit Tab — \`/erp/master/products/:id/audit\`  
\*\*Purpose\*\*: แสดงประวัติการกระทำ (audit trail) ของสินค้านี้

\#\#\#\# Layout  
\- Template: viewDrawer.v1 with ActivityLog card

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| Tabs: Overview | UOM | Vendors | Tax/GL | Images/Docs | Audit (active)        |  
\+------------------------------------------------------------------------------+  
| Section: Audit Log                                                            |  
| • 2025-11-02 09:10 — user@domain — Submitted (Draft → In Review) \[View\]       |  
| • 2025-11-03 14:22 — finance@ — Approved (In Review → Approved) \[View Notes\]  |  
| …                                                                            |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- content\_sections → \[\*\*ActivityLog\*\*\] (list of audit entries with actor/role/timestamp/action/reason/diff)

\#\#\#\# Actions / Events & Binding  
\- Read-only GET \`/api/master/products/{id}\` includes audit or separate GET \`/api/master/products/{id}/audit\` (implementation detail)  
\- Each audit entry may open a modal to view snapshot/diff

\#\#\#\# Validation  
\- Pagination and time-range filters for large audit logs

\#\#\#\# RBAC & Status Gating  
\- Audit view visible to all roles; sensitive data redacted for non-Admin if policy applies

\#\#\#\# Microcopy (i18n/A11y)  
\- Audit heading: \*\*ประวัติการเปลี่ยนแปลงสินค้า\*\*

\#\#\#\# Journey Bindings  
\- All transitions (submit/approve/activate/deactivate/obsolete) emit events logged here

\---

\#\#\# 7.2.10 Import Drawer — \`/erp/master/products/import\`  
\*\*Purpose\*\*: นำเข้าสินค้าจำนวนมากด้วย CSV/XLSX → preview validation → commit

\#\#\#\# Layout  
\- Template: importDrawer.v1 — Drawer:right; width=45%; stepper (Upload → Preview & Confirm), left content dropzone (7/12) and required columns list (5/12)

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| H1: นำเข้าสินค้า (Import)                               \[ ☐ Expand \] \[ ✖ \]   |  
| Sub: อัปโหลดไฟล์ CSV/XLSX → ตรวจสอบ → บันทึก                         |  
\+------------------------------------------------------------------------------+  
| Stepper: ● 1\. Upload File   ○ 2\. Preview & Confirm                         |  
\+------------------------------------------------------------------------------+  
| ⬆ Drag and drop your file here, or browse                                   |  
| Supported formats: .csv, .xlsx; Max size: 10MB                              |  
| \[ SelectedFile.csv \]  \[ Remove \]                                            |  
\+------------------------------------------------------------------------------+  
| Required Columns: Code (ตัวอย่าง), Name, Base UOM, Category, Type          |  
\+------------------------------------------------------------------------------+  
| Left:  \[Cancel\]                                  Right:  \[Next →\]            |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- drawer\_header → \[\*\*DrawerHeader\*\*\]  
\- stepper → \[\*\*Stepper\*\*\]  
\- helper\_actions → \[\*\*InlineHelp\*\*\] \+ \[\*\*Button(download\_template)\*\*\]  
\- main\_left → \[\*\*FileDropzone\*\*\], \[\*\*FileChipList\*\*\]  
\- main\_right → \[\*\*RequiredColumnsList\*\*\]  
\- footer\_buttons → \[\*\*Button\*\*(cancel), \*\*Button\*\*(next/upload)\]

\#\#\#\# Actions / Events & Binding  
\- Upload → client upload → server parse \+ validate → returns preview (422 rows flagged)  
\- Commit → POST \`/api/master/products/import\` (X-Idempotency-Key) → response: import report  
\- Preview step must show per-row validation messages; user can fix errors or skip rows per policy

\#\#\#\# Validation  
\- CSV columns mapping; required columns; per-row validation returns 422 details  
\- Idempotency via X-Idempotency-Key on commit

\#\#\#\# RBAC & Status Gating  
\- Import allowed to Admin; Editor may have conditional (C1/C4) for vendor/catalog import

\#\#\#\# Microcopy (i18n/A11y)  
\- Template download: \*\*ดาวน์โหลดเทมเพลต (.csv)\*\*  
\- Import commit confirmation: \*\*ยืนยันการนำเข้า — ไม่สามารถย้อนกลับได้สำหรับบางรายการ\*\*

\#\#\#\# Journey Bindings  
\- J6: From List \[Import\] → Import Drawer → Upload → Preview → Commit → POST \`/api/master/products/import\` (X-Idempotency-Key) → server creates drafts/updates per import mode

\---

\#\#\# 7.2.11 Delete / Deactivate / Obsolete Confirm Modal — (modal)  
\*\*Purpose\*\*: ยืนยันการกระทำที่มีผลถาวรหรือกึ่งถาวร (soft-delete/deactivate/obsolete) โดยแสดงเงื่อนไขและผลกระทบ

\#\#\#\# Layout  
\- Template: deleteConfirm.v1 — Modal:center; width≈480px; header icon \+ title; footer right-aligned \[Cancel\] \[Delete\]

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
|                           ⚠️  ยืนยัน: ยกเลิกการใช้งาน PROD-000123            |  
\+------------------------------------------------------------------------------+  
| คุณแน่ใจหรือไม่ว่าต้องการยกเลิกการใช้งาน \*\*PROD-000123\*\*?                  |  
| การกระทำนี้อาจไม่สามารถย้อนกลับได้ (Obsolete) หรืออาจถูกบล็อกหากมีเอกสาร |  
| Context: มีเอกสารเปิดใน PR-00045 (ถ้ามี)                                      |  
\+------------------------------------------------------------------------------+  
|                                               \[ ยกเลิก \]   \[ ยืนยัน (ยกเลิก) \] |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- modal\_header → \[\*\*Icon(Warning)\*\*\] \+ \[\*\*ModalTitle\*\*\]  
\- modal\_body → \[\*\*Paragraph\*\*\] \+ context text  
\- modal\_footer → \[\*\*Button\*\*(cancel), \*\*Button\*\*(confirm-danger)\]

\#\#\#\# Actions / Events & Binding  
\- Confirm Delete/Deactivate → POST \`/api/master/products/{id}:deactivate\` or POST \`/api/master/products/{id}:obsolete\` or DELETE \`/api/master/products/{id}\`  
\- API returns:  
  \- 200 on success  
  \- 409 if business guard (open PR/PO/GRN or on-hand \> 0\)  
  \- 403 if RBAC insufficient

\#\#\#\# Validation  
\- If precondition fails → show server reason (e.g., "มี PR/PO/GRN เปิดอยู่: PR-00045")

\#\#\#\# RBAC & Status Gating  
\- Only Admin/Approver per policy can perform Deactivate/Obsolete (A2 \+ C3)  
\- Obsolete irreversible; require explicit confirmation checkbox "รับทราบว่าการกระทำนี้ไม่สามารถย้อนกลับ"

\#\#\#\# Microcopy (i18n/A11y)  
\- Warning title: \*\*ยืนยันการยกเลิกการใช้งาน\*\*  
\- Danger confirm button: \*\*ยืนยัน (ยกเลิกการใช้งาน)\*\* aria-label="ยืนยันยกเลิกสินค้าชั่วคราว/ถาวร"

\#\#\#\# Journey Bindings  
\- J5: From List/Detail → \[Deactivate\] modal → confirm → POST \`/api/master/products/{id}:deactivate\` → 200 or 409 conflict  
\- J5: From List/Detail → \[Obsolete\] modal → confirm with extra guard → POST \`/api/master/products/{id}:obsolete\`

\---

\#\#\# 7.2.12 Print Label / Label Template Modal — (modal/drawer)  
\*\*Purpose\*\*: เลือก template ฉลากและพิมพ์ฉลากสินค้า (PDF)

\#\#\#\# Layout  
\- Template: viewDrawer.v1 (used as modal/drawer for preview \+ template select)

\#\#\#\# ASCII Wireframe  
\`\`\`   
\+------------------------------------------------------------------------------+  
| H1: พิมพ์ฉลาก — PROD-000123                                  \[ ✖ \]         |  
\+------------------------------------------------------------------------------+  
| เลือกเทมเพลตฉลาก: \[Select ▾\]                                              |  
| ตัวอย่าง PDF Preview                                                         |  
| \--------------------------------------------------------------------------- |  
| \[Download PDF\]                                 \[Cancel\]    \[Print Label\]      |  
\+------------------------------------------------------------------------------+  
\`\`\`

\#\#\#\# Components (by slots)  
\- header → \[\*\*DrawerHeader\*\*\] / modal title  
\- template\_select → \[\*\*Select\*\*\] (list of barcode templates)  
\- preview → \[\*\*PDFPreview\*\*\] (iframe or embedded viewer)  
\- actions → \[\*\*Button\*\*(download), \*\*Button\*\*(print)\]

\#\#\#\# Actions / Events & Binding  
\- Fetch label → GET \`/api/master/products/{id}:label\` (scope product.label) → returns PDF or job id  
\- Choose template parameter → GET \`/api/master/products/{id}:label?template={template\_id}\`  
\- On success: download or open PDF preview

\#\#\#\# Validation  
\- Template must support product's symbology/tracking; if unsupported return 422

\#\#\#\# RBAC & Status Gating  
\- All roles can view/print labels per A2 (Warehouse/View allowed)  
\- If role lacks product.read → 403

\#\#\#\# Microcopy (i18n/A11y)  
\- Select template label: \*\*เลือกเทมเพลตฉลาก\*\*  
\- Download button: \*\*ดาวน์โหลด PDF\*\*

\#\#\#\# Journey Bindings  
\- J6: From List/Detail → \[Print Label\] → modal → select template → GET \`/api/master/products/{id}:label\` → PDF

\---

\#\# 7.3 Screen Components (React-friendly names)  
\- Pages: ProductListPage, ProductCreatePage, ProductDetailPage, ProductEditPage  
\- Composables: ProductFilterBar, ProductTable, PaginationBar, BulkActionsBar, ProductForm, FormActionBar, FormGuard, ToastHost, ActivityLog, StatusActions, ApprovalActions, AttachmentPanel, ProductUomConvTable, ProductVendorsTable, ProductBarcodeTable

\#\# 7.4 Client Flows (Create/Update/Delete/Restore/Bulk)  
\- Create: client-validate → POST /api/master/products (+ X-Idempotency-Key) → 201 \+ ETag → redirect to Detail  
\- Submit: POST /api/master/products/{id}:submit (+Idempotency) → 200 → status=In Review → emit product.submitted  
\- Approve: POST /api/master/products/{id}:approve → 200 → status=Approved → emit product.approved  
\- Activate: POST /api/master/products/{id}:activate → 200 → status=Active → emit product.activated  
\- Update: GET \=\> obtain ETag → PATCH /api/master/products/{id} (If-Match) → 200 or 412  
\- Delete (soft / deactivate / obsolete): POST /api/master/products/{id}:deactivate | POST /api/master/products/{id}:obsolete → 200 | 409  
\- Import: POST /api/master/products/import (X-Idempotency-Key) after preview → server import report

\#\# 7.5 Microcopy / Empty / Error States (i18n & A11y)  
\- Empty List: \*\*ไม่มีสินค้าที่ตรงกับเงื่อนไขนี้\*\*  
\- Confirm Submit: \*\*ยืนยันการส่งตรวจสินค้า\*\*  
\- 403: \*\*คุณไม่มีสิทธิ์ดำเนินการนี้\*\*  
\- 409: \*\*คำขอถูกบล็อกเนื่องจากเอกสารอ้างอิงเปิดอยู่: {ref}\*\*  
\- 412: \*\*ข้อมูลไม่ตรงกัน กรุณาดึงข้อมูลล่าสุดก่อนบันทึก\*\*  
\- All toasts: short Thai message \+ role-appropriate detail; aria-live polite

\#\# 7.6 Journey ↔ Page Crosswalk (ใหม่ แนะนำ)  
\- J1 Create & Submit → ProductCreatePage → \[Save Draft\] (POST /api/master/products) → \[Submit\] (POST /api/master/products/{id}:submit)  
\- J2 Approve & Activate → ProductDetailPage (Tax/GL tab) → \[Approve\] (POST /api/master/products/{id}:approve) → \[Activate\] (POST /api/master/products/{id}:activate)  
\- J3 Maintain UOM → ProductDetailPage (UOM tab) → \[Save\] → PATCH (If-Match) → optionally POST :submit if Active+critical  
\- J4 Vendors → ProductDetailPage (Vendors tab) → PATCH \`/api/master/products/{id}\` (If-Match)  
\- J5 Deactivate/Obsolete → ProductList/ProductDetail → confirm modal → POST :deactivate/:obsolete  
\- J6 Import/Export/Label → List toolbar \+ ImportDrawer \+ GET /export \+ GET /:label

\#\#\# Warnings (ข้อควรระวัง / ข้อมูลไม่ครบ)  
\- template\_source used:  
  \- Product List → packingList.v1 (template\_source=packingList.v1)  
  \- Create → createDrawer.v2 (template\_source=createDrawer.v2)  
  \- Edit → editStepperDrawer.v1 (template\_source=editStepperDrawer.v1)  
  \- Detail & Tabs → viewDrawer.v1 (template\_source=viewDrawer.v1)  
  \- Import → importDrawer.v1 (template\_source=importDrawer.v1)  
  \- Confirm Modal → deleteConfirm.v1 (template\_source=deleteConfirm.v1)  
  \- Label Modal → viewDrawer.v1 (re-used)    
\- missing\_components (สร้าง placeholder ใน sheet “New Component”):    
  \- ProductListPage, ProductCreatePage, ProductDetailPage, ProductEditPage, ProductFilterBar, ProductTable, ProductForm, ProductUomConvTable, ProductVendorsTable, ProductBarcodeTable, FormActionBar, FormGuard, ActivityLog, StatusActions, ApprovalActions, ToastHost    
\- ข้อควรชี้แจงจาก input:  
  \- ใครมีสิทธิ์ “controller override” ยังไม่ชัด → ต้องกำหนด role และ API flag (เช่น override=true \+ approver signature)  
  \- Endpoint \`:reject\` ถูกอ้างถึงใน transitions แต่ไม่อยู่ใน API list → ยืนยันว่ามี \`POST /api/master/products/{id}:reject\` หรือใช้ PATCH แทน  
  \- พฤติกรรม Import (upsert vs create new revision) ไม่ชัด → ต้องกำหนด policy  
  \- รายการฟิลด์ที่ถือเป็น "critical" ควรยืนยันรายการอย่างเป็นทางการ (ปัจจุบันอ้าง base\_uom, tax/GL, tracking)  
  \- Org/site-level filtering (org\_id) ไม่ได้ระบุ — หากระบบต้องการ scope per org โปรดเพิ่ม rule  
\- Rules/Lint violations to note:  
  \- หากต้องการ stepper \>5 steps → ต้องลดขั้นตอน (rule: stepper\_max)    
  \- Drawer width: editStepperDrawer uses width=45% (allowed "wide") — เงื่อนไขพิเศษให้ยืนยันหากต้องการ 55% หรือ 100%    
\- unknown tokens (หากมีการปรับเทมเพลตเพิ่มเติม โปรดแจ้ง): ทุก tokenใน ASCII ถูกแทนด้วยข้อความภาษาไทยที่สอดคล้องกับอินพุต; หากต้องการ text ที่ต่างกัน โปรดระบุ  

\#\# 8\) API Endpoints    
Base URL: \`\<base\_url\>\`    
Base Path: \`/erp/master/products\`

| Method | Path | Use case | Notes |  
|---|---|---|---|  
| GET | /erp/master/products | ดึงรายการสินค้า (List) | Headers: Authorization; Query filters: q,status,type,category\_id,vendor\_id,tracking,page,page\_size,sort,updated\_from,updated\_to; returns items: Product\[\] \+ pagination |  
| POST | /erp/master/products | สร้างสินค้า (Save Draft / Create) | Headers: Authorization, X-Idempotency-Key; idempotent create; request may include ProductBarcode\[\], ProductUomConv\[\], ProductVendor\[\], ProductImage\[\], ProductDoc\[\] |  
| GET | /erp/master/products/{id} | ดูรายละเอียดสินค้า (Detail) | Headers: Authorization; response: Product (full) with child arrays: ProductBarcode\[\], ProductUomConv\[\], ProductVendor\[\], ProductImage\[\], ProductDoc\[\]; returns ETag header |  
| PATCH | /erp/master/products/{id} | แก้ไขสินค้า (Update, partial) | Headers: Authorization, If-Match; optimistic concurrency; critical-field edits on Active create revision (see notes) |  
| POST | /erp/master/products/{id}:submit | ส่งตรวจสินค้า (Draft → In Review / revision submit) | Traceable action from Create/Edit; Headers: Authorization, X-Idempotency-Key; may require validation of GL/Tax/Base UOM |  
| POST | /erp/master/products/{id}:approve | อนุมัติสินค้า (In Review → Approved) | Headers: Authorization, If-Match, X-Idempotency-Key, X-Audit-Reason (optional); role: Finance/Procurement per DOA |  
| POST | /erp/master/products/{id}:reject | ปฏิเสธการอนุมัติ (In Review → Draft) | Headers: Authorization, If-Match, X-Audit-Reason (required); returns reason logged |  
| POST | /erp/master/products/{id}:activate | เปิดใช้งานสินค้า (Approved → Active) | Headers: Authorization, If-Match, X-Idempotency-Key, X-Audit-Reason (optional); preconditions: no open references; may return 409 |  
| POST | /erp/master/products/{id}:deactivate | ยกเลิกการใช้งานชั่วคราว (Active → Inactive) | Headers: Authorization, If-Match, X-Idempotency-Key, X-Audit-Reason; blocked → 409 if open PR/PO/GRN (unless controller override) |  
| POST | /erp/master/products/{id}:obsolete | ปิดใช้งานถาวร (→ Obsolete) | Headers: Authorization, If-Match, X-Idempotency-Key, X-Audit-Reason; irreversible; preconditions: on-hand \== 0 && no open docs; returns 409/422 as applicable |  
| GET | /erp/master/products/{id}:label | สร้าง/ดาวน์โหลดฉลาก (PDF) | Headers: Authorization; Query: template={template\_id}; returns application/pdf or 202 job id if async; validates symbology/tracking |  
| POST | /erp/master/products/import | นำเข้า (Import CSV/XLSX) | Headers: Authorization, X-Idempotency-Key; request references uploaded file\_id; preview/commit flow; returns import report |  
| GET | /erp/master/products:export | ส่งออก (Export CSV/XLSX) | Headers: Authorization; Query filters same as list; may return CSV (200) or 202 \+ job id for async large exports |  
| GET | /erp/master/products/{id}/audit | ดึง Audit log รายสินค้า | Headers: Authorization; returns audit\_entries\[\] (actor, role, action, timestamp, reason, diff) |  
| POST | /erp/master/products:bulk | Bulk actions (e.g., bulk-activate/bulk-deactivate) | Headers: Authorization, X-Idempotency-Key; request: action, ids\[\]; response per id status; RBAC gated |

\---

\#\#\# 8.1 List — \`GET /erp/master/products\`  
Traceability: Page \= Product List (\`/erp/master/products\`) · Action \= view:list · Journey \= J1 / J6 / general listing    
Headers (required/optional): Authorization: Bearer \<token\>    
Query params:  
| Name | Type | Req | Default | Description |  
|---|---:|:---:|---|---|  
| q | string | no | \- | ค้นหาโค้ด/ชื่อ/บาร์โค้ด |  
| status | string\[\] | no | \- | กรองตามสถานะ (Draft,In Review,Approved,Active,Inactive,Obsolete) |  
| type | string | no | \- | ประเภทสินค้า (Stock|NonStock|Service) |  
| category\_id | string | no | \- | รหัสหมวดหมู่ |  
| vendor\_id | string | no | \- | รหัส vendor (กรองโดย vendor relation) |  
| tracking | string | no | \- | Tracking (None|Lot|Serial) |  
| page | integer | no | 1 | หมายเลขหน้า |  
| page\_size | integer | no | 25 | ขนาดหน้า |  
| sort | string | no | \-updated\_at | sort field (e.g., code, \-updated\_at) |  
| updated\_from | string (ISO-8601) | no | \- | กรองวันที่อัพเดตจาก |  
| updated\_to | string (ISO-8601) | no | \- | กรองวันที่อัพเดตถึง |

\#\#\#\# Response (success):  
\`\`\`json  
{  
  "items": \[  
    {  
      "id": "1001",  
      "code": "PROD-0001",  
      "name": "น้ำยาทดสอบ",  
      "type": "Stock",  
      "category\_id": "CAT-10",  
      "base\_uom": "PCS",  
      "tracking": "Lot",  
      "preferred\_vendor": "VND-01",  
      "status": "Active",  
      "updated\_at": "2025-11-01T09:12:00Z"  
    }  
  \],  
  "meta": {  
    "page": 1,  
    "page\_size": 25,  
    "total": 1234  
  }  
}  
\`\`\`

\#\#\#\# Error (shared model applies):  
\`\`\`json  
{ "code": "400\_VALIDATION\_FAILED", "message": "Invalid filter: updated\_from must be ISO-8601", "details": \[ { "field": "updated\_from", "message": "invalid datetime" } \], "trace\_id": "tid-1234" }  
\`\`\`

\---

\#\#\# 8.2 Create — \`POST /erp/master/products\`  
Traceability: Page \= Product Create (\`/erp/master/products/new\`) · Action \= create · Journey \= J1    
Headers (required/optional): Authorization: Bearer \<token\>, X-Idempotency-Key (recommended)    
\#\#\#\# Request:  
\`\`\`json  
{  
  "code": "PROD-0002",  
  "name": "สารเคมีทดสอบ",  
  "type": "Stock",  
  "category\_id": "CAT-12",  
  "base\_uom": "L",  
  "purchase\_uom": "BOX",  
  "tracking": "None",  
  "tax\_code\_id": "VAT-7",  
  "gl\_inventory\_acct\_id": "1100",  
  "gl\_expense\_acct\_id": "5000",  
  "cost\_method": "Standard",  
  "standard\_cost": 12.3456,  
  "hazardous": false,  
  "shelf\_life\_days": 365,  
  "remarks": "ตัวอย่างสินค้า",  
  "product\_barcode": \[  
    { "symbology": "EAN13", "value": "1234567890123", "is\_primary": true }  
  \],  
  "product\_uom\_conv": \[  
    { "from\_uom": "L", "to\_uom": "ML", "factor": 1000.000000 }  
  \],  
  "product\_vendor": \[  
    { "vendor\_id": "VND-01", "vendor\_sku": "SKU-123", "preferred": true, "moq": 10, "lead\_time\_days": 7, "price\_hint": 12.3456, "currency": "THB" }  
  \],  
  "product\_image": \[  
    { "url": "https://files.example.com/img-1.jpg", "alt\_text": "รูปสินค้า", "is\_primary": true }  
  \],  
  "product\_doc": \[  
    { "file\_url": "https://files.example.com/spec-1.pdf", "doc\_type": "Spec" }  
  \]  
}  
\`\`\`

\#\#\#\# Response (success 201):  
Headers: ETag: "\<etag-value\>"  
\`\`\`json  
{  
  "id": "1002",  
  "code": "PROD-0002",  
  "status": "Draft",  
  "created\_at": "2025-11-05T08:30:00Z"  
}  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "400\_VALIDATION\_FAILED", "message": "Missing required field: base\_uom", "details": \[ { "field": "base\_uom", "message": "required" } \], "trace\_id": "tid-2345" }  
\`\`\`

\---

\#\#\# 8.3 Detail — \`GET /erp/master/products/{id}\`  
Traceability: Page \= Product Detail (\`/erp/master/products/:id\`) · Action \= view:detail · Journey \= J1 / J2 / J3 / J4 / J5    
Headers (required/optional): Authorization: Bearer \<token\>    
\#\#\#\# Response (success):  
Headers: ETag: "\<etag-value\>"  
\`\`\`json  
{  
  "id": "1002",  
  "code": "PROD-0002",  
  "name": "สารเคมีทดสอบ",  
  "type": "Stock",  
  "category\_id": "CAT-12",  
  "status": "Approved",  
  "base\_uom": "L",  
  "purchase\_uom": "BOX",  
  "tracking": "Lot",  
  "weight": 1.250,  
  "length": 10.00,  
  "width": 5.00,  
  "height": 2.50,  
  "weight\_uom": "KG",  
  "volume\_uom": "L",  
  "tax\_code\_id": "VAT-7",  
  "gl\_inventory\_acct\_id": "1100",  
  "gl\_expense\_acct\_id": "5000",  
  "cost\_method": "Standard",  
  "standard\_cost": 12.3456,  
  "hazardous": false,  
  "shelf\_life\_days": 365,  
  "remarks": "ตัวอย่างสินค้า",  
  "product\_barcode": \[  
    { "id": "2001", "symbology": "EAN13", "value": "1234567890123", "is\_primary": true }  
  \],  
  "product\_uom\_conv": \[  
    { "id": "3001", "from\_uom": "L", "to\_uom": "ML", "factor": 1000.000000 }  
  \],  
  "product\_vendor": \[  
    { "id": "4001", "vendor\_id": "VND-01", "vendor\_sku": "SKU-123", "preferred": true, "moq": 10, "lead\_time\_days": 7, "price\_hint": 12.3456, "currency": "THB" }  
  \],  
  "product\_image": \[  
    { "id": "5001", "url": "https://files.example.com/img-1.jpg", "alt\_text": "รูปสินค้า", "is\_primary": true }  
  \],  
  "product\_doc": \[  
    { "id": "6001", "file\_url": "https://files.example.com/spec-1.pdf", "doc\_type": "Spec" }  
  \],  
  "updated\_at": "2025-11-05T09:00:00Z",  
  "created\_at": "2025-11-05T08:30:00Z"  
}  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "404\_NOT\_FOUND", "message": "Product 1002 not found", "details": \[\], "trace\_id": "tid-3456" }  
\`\`\`

\---

\#\#\# 8.4 Update — \`PATCH /erp/master/products/{id}\`  
Traceability: Page \= Product Edit (\`/erp/master/products/:id/edit\`) · Action \= edit · Journey \= J5 / J3 / J4    
Headers (required/optional): Authorization: Bearer \<token\>, If-Match: "\<etag-value\>"    
\#\#\#\# Request:  
\`\`\`json  
{  
  "name": "สารเคมีทดสอบ (รุ่นใหม่)",  
  "remarks": "อัพเดตคำอธิบาย",  
  "product\_vendor": \[  
    { "id": "4001", "preferred": false },  
    { "vendor\_id": "VND-02", "vendor\_sku": "SKU-999", "preferred": true, "moq": 5, "lead\_time\_days": 10, "price\_hint": 11.5000, "currency": "THB" }  
  \]  
}  
\`\`\`

\#\#\#\# Response (success):  
Headers: ETag: "\<new-etag\>"  
\`\`\`json  
{  
  "id": "1002",  
  "status": "Draft",  
  "updated\_at": "2025-11-06T10:00:00Z"  
}  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "412\_PRECONDITION\_FAILED", "message": "ETag mismatch", "details": \[\], "trace\_id": "tid-4567" }  
\`\`\`

\---

\#\#\# 8.5 Submit — \`POST /erp/master/products/{id}:submit\`  
Traceability: Page \= Product Create / Product Edit / Product List row · Action \= submit · Journey \= J1 / J5 / J3    
Headers (required/optional): Authorization: Bearer \<token\>, X-Idempotency-Key, If-Match (recommended), X-Audit-Reason (optional)    
\#\#\#\# Request (optional payload):  
\`\`\`json  
{ "comment": "ส่งตรวจเพื่ออนุมัติ", "notify\_approvers": true }  
\`\`\`

\#\#\#\# Response:  
\`\`\`json  
{ "id": "1002", "status": "In Review", "submitted\_at": "2025-11-06T10:05:00Z" }  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "422\_INVALID\_STATE", "message": "Required fields missing for submit: base\_uom, product\_barcode (primary)", "details": \[ { "field": "product\_barcode", "message": "At least one primary barcode required" } \], "trace\_id": "tid-5678" }  
\`\`\`

\---

\#\#\# 8.6 Approve — \`POST /erp/master/products/{id}:approve\`  
Traceability: Page \= Product Detail (Tax/GL tab) / List row · Action \= approve · Journey \= J2    
Headers (required): Authorization: Bearer \<token\>, If-Match: "\<etag-value\>", X-Idempotency-Key, X-Audit-Reason (recommended)    
Request (optional):  
\`\`\`json  
{ "comment": "Approved by finance", "approver\_id": "user-fin-01" }  
\`\`\`

\#\#\#\# Response:  
\`\`\`json  
{ "id": "1002", "status": "Approved", "approved\_at": "2025-11-07T14:22:00Z" }  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "403\_FORBIDDEN", "message": "User not authorized to approve", "details": \[\], "trace\_id": "tid-6789" }  
\`\`\`

\---

\#\#\# 8.7 Reject — \`POST /erp/master/products/{id}:reject\`  
Traceability: Page \= Product Detail / List row · Action \= reject · Journey \= J2    
Headers (required): Authorization: Bearer \<token\>, If-Match: "\<etag-value\>", X-Audit-Reason (required)    
Request:  
\`\`\`json  
{ "reason": "GL account missing", "comment": "กรุณาแก้ไข GL และส่งใหม่" }  
\`\`\`

\#\#\#\# Response:  
\`\`\`json  
{ "id": "1002", "status": "Draft", "reverted\_at": "2025-11-07T15:00:00Z" }  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "400\_VALIDATION\_FAILED", "message": "Reason is required for reject", "details": \[ { "field": "reason", "message": "required" } \], "trace\_id": "tid-7890" }  
\`\`\`

\---

\#\#\# 8.8 Activate — \`POST /erp/master/products/{id}:activate\`  
Traceability: Page \= Product Detail / List row · Action \= activate · Journey \= J2    
Headers (required): Authorization: Bearer \<token\>, If-Match: "\<etag-value\>", X-Idempotency-Key, X-Audit-Reason (optional)    
Request (optional):  
\`\`\`json  
{ "comment": "Activate for procurement" }  
\`\`\`

\#\#\#\# Response:  
\`\`\`json  
{ "id": "1002", "status": "Active", "activated\_at": "2025-11-07T16:00:00Z" }  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "409\_CONFLICT", "message": "Cannot activate: open PR exists PR-00045", "details": \[ { "field": "references", "message": "PR-00045" } \], "trace\_id": "tid-8901" }  
\`\`\`

\---

\#\#\# 8.9 Deactivate — \`POST /erp/master/products/{id}:deactivate\`  
Traceability: Page \= Product Detail / List row / Confirm Modal · Action \= deactivate · Journey \= J5    
Headers (required): Authorization: Bearer \<token\>, If-Match: "\<etag-value\>", X-Idempotency-Key, X-Audit-Reason (recommended)    
Request:  
\`\`\`json  
{ "reason": "Discontinued for season", "override": false }  
\`\`\`

\#\#\#\# Response:  
\`\`\`json  
{ "id": "1002", "status": "Inactive", "deactivated\_at": "2025-11-08T09:00:00Z" }  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "422\_INVALID\_STATE", "message": "Cannot deactivate: open GRN/PO/PR exist", "details": \[ { "field": "references", "message": "PR-00045" } \], "trace\_id": "tid-9012" }  
\`\`\`

\---

\#\#\# 8.10 Obsolete — \`POST /erp/master/products/{id}:obsolete\`  
Traceability: Page \= Product Detail / List row / Confirm Modal · Action \= obsolete · Journey \= J5    
Headers (required): Authorization: Bearer \<token\>, If-Match: "\<etag-value\>", X-Idempotency-Key, X-Audit-Reason (required)    
Request:  
\`\`\`json  
{ "reason": "End of life", "acknowledge\_irreversible": true }  
\`\`\`

\#\#\#\# Response:  
\`\`\`json  
{ "id": "1002", "status": "Obsolete", "obsoleted\_at": "2025-11-09T10:00:00Z" }  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "409\_CONFLICT", "message": "Cannot obsolete: on-hand \> 0", "details": \[ { "field": "on\_hand", "message": "10 units" } \], "trace\_id": "tid-0123" }  
\`\`\`

\---

\#\#\# 8.11 Label — \`GET /erp/master/products/{id}:label\`  
Traceability: Page \= Print Label modal (\`Print Label\`) · Action \= label · Journey \= J6    
Headers (required/optional): Authorization: Bearer \<token\>    
Query params:  
| Name | Type | Req | Default | Description |  
|---|---:|:---:|---|---|  
| template | string | no | default\_template | id ของเทมเพลตฉลาก |  
| format | string | no | pdf | format (pdf) |

\#\#\#\# Response (sync PDF):  
Content-Type: application/pdf (binary)  
OR async:  
\`\`\`json  
{ "job\_id": "job-789", "status": "accepted" }  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "422\_INVALID\_STATE", "message": "Template does not support symbology QR for this product", "details": \[\], "trace\_id": "tid-1122" }  
\`\`\`

\---

\#\#\# 8.12 Import — \`POST /erp/master/products/import\`  
Traceability: Page \= Import Drawer (\`/erp/master/products/import\`) · Action \= import:commit · Journey \= J6    
Headers (required): Authorization: Bearer \<token\>, X-Idempotency-Key    
\#\#\#\# Request:  
\`\`\`json  
{  
  "file\_id": "file-123",  
  "mode": "upsert",   
  "default\_category\_id": "CAT-12",  
  "notify": true  
}  
\`\`\`

\#\#\#\# Response:  
\`\`\`json  
{  
  "import\_id": "imp-001",  
  "created": 120,  
  "updated": 30,  
  "errors": 2,  
  "report\_url": "https://files.example.com/import-reports/imp-001.csv"  
}  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "400\_VALIDATION\_FAILED", "message": "File parsing failed: missing required column code", "details": \[\], "trace\_id": "tid-2233" }  
\`\`\`

\---

\#\#\# 8.13 Export — \`GET /erp/master/products:export\`  
Traceability: Page \= Product List (\`Export\` toolbar) · Action \= export · Journey \= J6    
Headers (required/optional): Authorization: Bearer \<token\>    
Query params: same as list filters \+ format=csv/xlsx

\#\#\#\# Response (sync small):  
Content-Type: text/csv (binary)    
OR async:  
\`\`\`json  
{ "job\_id": "exp-001", "status": "accepted", "download\_url": null }  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "429\_TOO\_MANY\_REQUESTS", "message": "Export rate limit exceeded", "details": \[\], "trace\_id": "tid-3344" }  
\`\`\`

\---

\#\#\# 8.14 Audit — \`GET /erp/master/products/{id}/audit\`  
Traceability: Page \= Product Detail (Audit tab) · Action \= view:audit · Journey \= all journeys (events)    
Headers (required/optional): Authorization: Bearer \<token\>    
Query params: page, page\_size, from, to

\#\#\#\# Response:  
\`\`\`json  
{  
  "audit\_entries": \[  
    { "timestamp": "2025-11-07T14:22:00Z", "actor": "finance@org", "role": "Finance", "action": "approve", "reason": "OK", "diff": {} }  
  \],  
  "meta": { "page": 1, "page\_size": 25, "total": 10 }  
}  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "404\_NOT\_FOUND", "message": "Product audit not found", "details": \[\], "trace\_id": "tid-4455" }  
\`\`\`

\---

\#\#\# 8.15 Bulk — \`POST /erp/master/products:bulk\`  
Traceability: Page \= Product List (Bulk actions) · Action \= bulk · Journey \= J6 / admin tasks    
Headers (required): Authorization: Bearer \<token\>, X-Idempotency-Key    
\#\#\#\# Request:  
\`\`\`json  
{ "action": "deactivate", "ids": \["1003","1004"\], "params": { "reason": "seasonal", "override": false } }  
\`\`\`

\#\#\#\# Response:  
\`\`\`json  
{  
  "action": "deactivate",  
  "results": \[  
    { "id": "1003", "status": "success", "message": "deactivated" },  
    { "id": "1004", "status": "failed", "message": "open PR PR-00050" }  
  \]  
}  
\`\`\`

\#\#\#\# Error:  
\`\`\`json  
{ "code": "403\_FORBIDDEN", "message": "Insufficient role for bulk deactivate", "details": \[\], "trace\_id": "tid-5566" }  
\`\`\`

\---

\# 9\. API Contract — Notes & Conventions

9.1 Security & Headers    
\- Authentication: Bearer JWT (Authorization: Bearer \<token\>) \+ RBAC/Scopes per role (Viewer / Editor / Approver / Admin).    
\- Headers ที่ใช้บ่อย:    
  \- Authorization: Bearer \<token\> (required)    
  \- X-Idempotency-Key: สำหรับคำสั่งที่ต้องการ idempotency (create, import commit, submit, approve, activate, deactivate, obsolete, bulk)    
  \- If-Match: "\<etag\>" — สำหรับ PATCH และ state-changing requests เพื่อป้องกัน concurrent edits (required where noted)    
  \- X-Audit-Reason: สำหรับการเปลี่ยนสถานะ/การกระทำที่ต้องการเหตุผล (status changes, reject, obsolete)    
\- ETag: server คืน ETag header ใน GET/POST responses; client ต้องส่ง If-Match เมื่อ PATCH หรือ action ที่ระบุ

9.2 Error Model & Codes    
\- ใช้ HTTP codes: 400, 401, 403, 404, 409, 412, 422, 429, 500 ตามบริบท    
\- รูปแบบ error กลาง:  
\`\`\`json  
{ "code": "…", "message": "…", "details": \[ { "field": "…", "message": "…" } \], "trace\_id": "…" }  
\`\`\`  
\- ตัวอย่าง mapping:    
  \- 400 VALIDATION\_FAILED — ขาดฟิลด์จำเป็น / UOM graph มีวงจร / duplicate barcode    
  \- 403 FORBIDDEN — สิทธิ์ไม่เพียงพอ (approve/activate/deactivate/obsolete)    
  \- 404 NOT\_FOUND — GL/Tax/Vendor/Category ไม่พบ    
  \- 409 CONFLICT — code ซ้ำ; business guards (open PR/PO/GRN)    
  \- 412 PRECONDITION\_FAILED — ETag mismatch (แนะนำ UX: ดึงข้อมูลล่าสุด → merge)    
  \- 422 INVALID\_STATE — ห้ามแก้ไขในสถานะปัจจุบัน หรือ validation domain (e.g., preferred vendor per currency)

9.3 Rate Limits & Required Headers    
\- ค่าเริ่มต้นแนะนำ: 120 requests/minute per client (ปรับได้ตาม NFR)    
\- เมื่อ 429 คืน header Retry-After (seconds)    
\- ให้ใช้ X-Idempotency-Key บังคับสำหรับ create/import/submit/approve/activate/deactivate/obsolete/bulk เพื่อรองรับ retry โดย client

9.4 Idempotency & Concurrency    
\- Idempotency: commands ที่เปลี่ยน state ควรรับ X-Idempotency-Key และทำ dedupe server-side    
\- Concurrency: ใช้ ETag \+ If-Match สำหรับ PATCH และ state transitions เพื่อตรวจจับ concurrent edits → เมื่อ mismatch (412) ให้ client ดึงข้อมูลใหม่และแสดง merge dialog    
\- 409 ใช้เมื่อ conflict เชิงธุรกิจ (เช่น มีเอกสารอ้างอิงเปิด) — แยกความหมายจาก 412

9.5 Example Requests (cURL)  
\- List (มี filters):  
curl \-H "Authorization: Bearer \<token\>" "\<base\_url\>/erp/master/products?q=PROD\&page=1\&page\_size=25\&status=Active"  
\- Create (มี X-Idempotency-Key):  
curl \-X POST \-H "Authorization: Bearer \<token\>" \-H "X-Idempotency-Key: key-123" \-H "Content-Type: application/json" \-d '{ "code":"PROD-0002", "name":"ตัวอย่าง", "base\_uom":"PCS" }' "\<base\_url\>/erp/master/products"  
\- Update (พร้อม If-Match):  
curl \-X PATCH \-H "Authorization: Bearer \<token\>" \-H 'If-Match: \\"etag-xyz\\"' \-H "Content-Type: application/json" \-d '{ "remarks": "อัพเดต" }' "\<base\_url\>/erp/master/products/1002"  
\- Action (approve) ตัวอย่าง:  
curl \-X POST \-H "Authorization: Bearer \<token\>" \-H 'If-Match: \\"etag-abc\\"' \-H "X-Idempotency-Key: key-approve-1" \-H "Content-Type: application/json" \-d '{ "comment":"Approved" }' "\<base\_url\>/erp/master/products/1002:approve"  
\- Import commit:  
curl \-X POST \-H "Authorization: Bearer \<token\>" \-H "X-Idempotency-Key: imp-789" \-H "Content-Type: application/json" \-d '{ "file\_id":"file-123", "mode":"upsert" }' "\<base\_url\>/erp/master/products/import"

9.6 Notes (Integrations & Export)  
\- Integrations (Inbound): GL master, Tax master, Vendor master, Category master — API validates FK existence (404 if not found).    
\- Outbound Events: publish events product.created, product.submitted, product.approved, product.activated, product.deactivated, product.obsoleted, product.updated with payload including id, actor, timestamp, snapshot\_id. Ensure retry/backoff for event delivery per NFR.    
\- Export: small exports may return CSV synchronously (200); large exports should be async (202 \+ job\_id). Provide job polling endpoint (not enumerated here) or callback webhook.    
\- Webhooks/Events: transitions and critical actions must emit audit & events; consumers (PR/PO/GRN) subscribe to product.activated, product.updated (tracking changes), product.obsoleted.    
\- PII & Masking: GL account/tax fields may be masked for non-Finance roles in responses (masking applied by server).    
\- Data precision: numeric fields must follow precision rules (decimal(18,6) for factors, decimal(18,4) for money, decimal(18,3) for weight, decimal(18,2) for dimensions). Dates/times in ISO-8601 UTC (e.g., 2025-01-01T00:00:00Z) — UI may render Asia/Bangkok.  

\-- End of API Contract.

\# Journey  
\#\#\# Journey: สร้างสินค้าและส่งตรวจ (Actor: Editor/Creator หรือ Admin)  
\*\*Entry:\*\* จากหน้า List \`/erp/master/products\` → ปุ่ม สร้าง (Create) / หรือ deeplink \`/erp/master/products/new\`    
\*\*Preconditions:\*\* ผู้ใช้มีสิทธิ์สร้างสินค้า (role \= Admin หรือ Editor ที่อนุญาต) ; ต้นทางข้อมูล FK (category\_id, tax\_code\_id, vendor\_id, gl\_\* ถ้ามี) ต้องมีอยู่หรือจะรับการแจ้ง 404 จาก API ; เน็ตเวิร์กปกติ    
\*\*Exit / Postconditions:\*\* สร้าง Product record เป็นสถานะ \`Draft\` (server คืน id \+ ETag) → ถ้าผู้ใช้กด Submit ต่อ จะเปลี่ยนเป็น \`In Review\` และปล่อยเหตุการณ์ product.submitted

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*list / btn-create-product\*\* — ผู้ใช้กดปุ่ม สร้าง (Create)    
   \- Trigger: NAV → เปิด route \`/erp/master/products/new\` (drawer)    
   \- map\_in: none    
   \- assert: ผู้ใช้มีสิทธิ์ Create (client-side check)    
   \- System: เปิด UI Create Drawer (client)    
   \- map\_out: n/a    
   \- UI Feedback: เปิด Drawer; focus ไปที่ \`input-code\`    
   \- Navigation/State: ไม่มี navigation เปลี่ยนหน้า (drawer)    
   \- Field & Copy Checklist:  
     \- Fields ที่ต้องกรอก:  
       \- code | รหัสสินค้า | text | required(yes) | default: auto/empty | validators: regex /^\[A-Z0-9\\-\\\_\]+$/? (ถ้าระบุ) | helper\_text\_th: "รหัสต้องไม่ซ้ำ" | error\_copy\_th: "กรุณากรอกรหัสสินค้า" | visibility(editable)  
       \- name | ชื่อสินค้า | text | required(yes) | error\_copy\_th: "กรุณากรอกชื่อสินค้า" | visibility(editable)  
       \- type | ประเภท | enum(select: Stock|NonStock|Service) | required(yes) | helper:"เลือกรูปแบบสินค้า" | visibility(editable)  
       \- category\_id | หมวดหมู่ | select | required(no) | visibility(editable)  
       \- base\_uom | Base UOM | select | required(yes) | helper:"หน่วยฐาน ใช้คำนวณสต็อก" | error\_copy\_th: "Base UOM จำเป็นสำหรับการบันทึก/ส่งตรวจ" | visibility(editable)  
       \- purchase\_uom | Purchase UOM | select | required(no) | visibility(editable)  
       \- tracking | Tracking | enum(select: None|Lot|Serial) | required(no) | visibility(editable)  
       \- tax\_code\_id | รหัสภาษี | select | required(no/depends) | visibility(editable)  
       \- gl\_inventory\_acct\_id | GL สินค้าคงคลัง | select | required(no/depends) | visibility(editable/read-only masked for non-Finance)  
       \- gl\_expense\_acct\_id | GL ค่าใช้จ่าย | select | required(no/depends) | visibility(editable/read-only masked)  
       \- standard\_cost | ราคามาตรฐาน | number(decimal(18,4)) | required(no) | validators: \>=0  
       \- product\_barcode (table) | ตารางบาร์โค้ด: symbology|value|is\_primary (at least one primary required before submit) | file\_types: n/a  
       \- product\_uom\_conv (table) | from\_uom|to\_uom|factor (factor decimal(18,6)) — client must validate acyclic graph  
       \- product\_vendor (table) | vendor\_id|vendor\_sku|preferred|moq|lead\_time\_days|price\_hint|currency — unique preferred per currency validation  
       \- product\_image / product\_doc | url|alt\_text|is\_primary / file\_url|doc\_type — file upload via file service, max\_size per policy  
     \- Fields ที่ต้องแสดง:  
       \- status | สถานะ | read-only | source: client-initial "Draft"  
       \- created\_at | สร้างเมื่อ | read-only | source: server after create  
     \- UI Copy / Messages:  
       \- Create primary: \*\*สร้าง\*\*; Save draft: \*\*บันทึกเป็นร่าง\*\*; helper: "Base UOM จำเป็นสำหรับการคำนวณสต็อก"  
       \- Validation inline: "ต้องมีบาร์โค้ดหลักอย่างน้อย 1 รายการ"  
       \- Empty states: drawer empty fields; loading skeleton khi POST  
     \- data-test-id ที่เกี่ยวข้อง: btn-open-create, drawer-create-product, input-code, input-name, select-base\_uom, table-barcode, btn-save-draft, btn-create-submit  
     \- a11y: focus order \= input-code → input-name → select-type → base\_uom → barcode table → footer buttons; modal trap; Esc closes drawer  
2\) \*\*create drawer / btn-save-draft\*\* — ผู้ใช้กด Save as Draft    
   \- Trigger: POST /erp/master/products    
   \- map\_in: { code, name, type, category\_id?, base\_uom, purchase\_uom?, tracking?, tax\_code\_id?, gl\_inventory\_acct\_id?, gl\_expense\_acct\_id?, product\_barcode\[\], product\_uom\_conv\[\], product\_vendor\[\], product\_image\[\], product\_doc\[\] } — ห้ามส่งค่า server-owned (เช่น on\_hand, totals)    
   \- assert: client-side validation required fields present (code,name,base\_uom) & barcode primary if user intends to submit later (but draft may allow missing primary); UOM cycle client validation (warn)    
   \- System: Server validates, creates resource, returns 201 \+ body {id, code, status:"Draft", created\_at} \+ ETag header    
   \- map\_out: { id, code, status, created\_at } \+ ETag \-\> store etag in client (product.etag)    
   \- UI Feedback: show toast success "บันทึกสินค้าเป็นร่างแล้ว" (telemetry: product.create) ; disable create button while awaiting; show spinner on btn-save-draft    
   \- Navigation/State: Keep drawer open or (preferred) navigate to Detail \`/erp/master/products/{id}\` after success (Page Definitions: redirect to Detail) — implementation: redirect to Detail and open Edit drawer if desired    
   \- Field & Copy Checklist: same as above; ensure data-test-id: api-create-call (instrumentation), toast-create-success  
3\) \*\*detail page / btn-submit\*\* — ผู้ใช้กด Submit เพื่อส่งตรวจ (จาก drawer หรือจาก Detail)    
   \- Trigger: POST /erp/master/products/{id}:submit    
   \- map\_in: { comment?, notify\_approvers?: boolean } and Headers: X-Idempotency-Key \= ui:{user.id}:{product.id}:{hash(code|base\_uom|tax\_code\_id)} ; If-Match: etag (recommended)    
   \- assert: client-side check before submit: required fields filled (base\_uom present, at least one barcode primary) — server will re-assert and may return 422 with details    
   \- System: Server validates domain rules (GL/Tax presence if org policy, barcode uniqueness, UOM acyclic, vendor preferred per currency) → on success set status="In Review" and return {id, status:"In Review", submitted\_at} and emit event product.submitted    
   \- map\_out: { id, status:"In Review", submitted\_at } — update UI: status badge, disable edit of some fields per workflow    
   \- UI Feedback: show modal confirm "ยืนยันการส่งตรวจสินค้า?" with confirm copy; on success toast "ส่งตรวจเรียบร้อย" ; on 422 show inline error list \+ focus first invalid field    
   \- Navigation/State: stay on Detail page \`/erp/master/products/{id}\` ; invalidate product list cache; emit telemetry release.submitted? (use product.submitted)    
   \- Field & Copy Checklist:  
     \- Confirmation modal copy: "ยืนยันการส่งตรวจสินค้าไปยังผู้อนุมัติ?" ; confirm button data-test-id: confirm-submit-product  
     \- data-test-id: btn-submit-product, modal-submit-confirm, toast-submit-success  
     \- a11y: Ctrl+Enter triggers Submit in modal; Esc cancels modal  
4\) … (end of happy path)

\#\#\#\# Variants & Exceptions  
\- Step 2 → VALIDATION:400\_VALIDATION\_FAILED (missing base\_uom)    
  \- UX: show field error at select-base\_uom, focus select-base\_uom, message "Base UOM จำเป็น"    
\- Step 2 → BUSINESS:409\_CONFLICT (code duplicate)    
  \- UX: show banner "รหัสสินค้าซ้ำในระบบ" with action "ตรวจสอบ/แก้ไข" (focus input-code)    
\- Step 2 → VALIDATION:UOM\_CYCLE (400\_VALIDATION\_FAILED)    
  \- UX: prevent submit/persist? Allow draft but warn on submit — show "พบวงจรการแปลงหน่วย (cyclic) โปรดแก้ไข" and highlight ProductUomConvTable rows    
\- Step 3 → 412\_PRECONDITION\_FAILED (ETag mismatch)    
  \- UX: show merge dialog with options: ดึงข้อมูลล่าสุด / ยกเลิก / merge (manual) ; telemetry: product.submit.conflict    
  \- Recovery: refetch GET /erp/master/products/{id} to get new ETag then retry Submit with same X-Idempotency-Key  
\- Step 3 → CONFLICT 422\_INVALID\_STATE (missing primary barcode)    
  \- UX: inline error, focus barcode table, helper to add primary  
\- Idempotency CONFLICT (server indicates duplicate request processed) → Retry client MUST reuse same X-Idempotency-Key; if server returns 409 with guidance, show toast "คำขอนี้ถูกดำเนินการแล้ว" and load resource.

\#\#\#\# Telemetry & Audit  
\- Events:  
  \- product.create { id, code, actor\_id, correlation\_id } (dot-case)    
  \- product.submitted { id, actor\_id, comment?, correlation\_id }    
\- Audit Fields: actor\_id, correlation\_id, idempotency\_key, resource id

\#\#\#\# Test Hooks  
\- data-test-id: btn-open-create, drawer-create-product, input-code, input-name, select-base\_uom, table-barcode, btn-save-draft, api-create-call, btn-submit-product, confirm-submit-product, toast-create-success, toast-submit-success    
\- Acceptance (Gherkin ย่อ):  
  \- Given ผู้ใช้มีสิทธิ์สร้างสินค้า    
  \- When ผู้ใช้กรอกฟิลด์ที่จำเป็นและกด บันทึกเป็นร่าง แล้วกด ส่งตรวจ    
  \- Then ระบบสร้างสินค้าสถานะ Draft แล้วเปลี่ยนเป็น In Review หลังส่งตรวจ และ ETag ถูกเก็บไว้

\#\#\#\# Assumptions & Confidence  
\- สมมติว่าไฟล์อัปโหลดไปยัง service แยกต่างหากและ client ได้รับ file\_url ก่อนเรียก POST create (Confidence: High for API contract; Medium for upload details)

\---

\#\#\# Journey: อนุมัติสินค้า (DOA) (Actor: Approver / Finance)  
\*\*Entry:\*\* แจ้งเตือนหรือเข้าหน้า Detail \`/erp/master/products/{id}\` (status \= In Review)    
\*\*Preconditions:\*\* สินค้าอยู่ในสถานะ \`In Review\`; ผู้ใช้มีสิทธิ์ Approve (role Approver/Finance); client มี current ETag from GET    
\*\*Exit / Postconditions:\*\* status → \`Approved\` ; event product.approved emitted ; ETag updated

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*detail / btn-approve\*\* — ผู้ใช้เปิด tab Tax/GL เพื่อทวนข้อมูล แล้วกด Approve    
   \- Trigger: POST /erp/master/products/{id}:approve    
   \- map\_in: optional { comment?, approver\_id? } ; Headers: If-Match: \`\<etag\>\`, X-Idempotency-Key: ui:{user.id}:{product.id}    
   \- assert: client asserts user role Approver, status \== "In Review" ; visible only when status matches    
   \- System: Server validates GL/tax presence (may return 422 if missing), authorizes user (403 if not), on success sets status="Approved", returns {id, status:"Approved", approved\_at} and new ETag    
   \- map\_out: { id, status:"Approved", approved\_at } \+ ETag → update UI    
   \- UI Feedback: Confirm modal "ยืนยันการอนุมัติสินค้า?" ; on success toast "อนุมัติเรียบร้อย" ; disable Approve button after success    
   \- Navigation/State: remain on Detail; invalidate list caches; show status badge change    
   \- Field & Copy Checklist:  
     \- Fields to show in Tax/GL tab: tax\_code\_id | รหัสภาษี | read-only/masked if non-finance | source: api    
     \- gl\_inventory\_acct\_id | GL สต็อก | read-only/masked | source: api    
     \- data-test-id: tab-tax-gl, btn-approve-product, modal-approve-confirm, toast-approve-success  
     \- a11y: Approve modal focus order, aria-label on confirm button  
2\) … (end happy path)

\#\#\#\# Variants & Exceptions  
\- Approve → 403\_FORBIDDEN: show toast "คุณไม่มีสิทธิ์อนุมัติ" and redirect to List; telemetry: approval.actioned.forbidden    
\- Approve → 422\_INVALID\_STATE: show inline error listing missing GL/tax fields; focus first missing field; action: allow user to edit (if permitted) or reject with reason    
\- Approve → 412\_PRECONDITION\_FAILED (ETag mismatch): show merge dialog; refetch; retry with same idempotency key    
\- Approve → CONFLICT (business): 409 if another approver already changed status → fetch latest and show toast

\#\#\#\# Telemetry & Audit  
\- Events:  
  \- product.approval.actioned { id, actor\_id, action: "approve", comment?, correlation\_id }    
  \- product.approved { id, approver\_id, timestamp }    
\- Audit Fields: actor\_id, role, correlation\_id, idempotency\_key, reason/comment

\#\#\#\# Test Hooks  
\- data-test-id: btn-approve-product, modal-approve-confirm, api-approve-call, toast-approve-success, tab-tax-gl

\#\#\#\# Acceptance (Gherkin)  
\- Given สินค้าอยู่ในสถานะ In Review และผู้ใช้เป็น Approver    
\- When ผู้ใช้กด อนุมัติ แล้วยืนยัน    
\- Then สถานะเปลี่ยนเป็น Approved และมี audit entry

\#\#\#\# Assumptions & Confidence  
\- สมมติ: ETag ถูกส่งใน GET ล่าสุดก่อนการ Approve (Confidence: High)

\---

\#\#\# Journey: ปฏิเสธการอนุมัติสินค้า (Reject) (Actor: Approver / Finance)  
\*\*Entry:\*\* จาก Detail \`/erp/master/products/{id}\` (status \= In Review) → ปุ่ม Reject    
\*\*Preconditions:\*\* status \== \`In Review\`; user role Approver; client holds ETag    
\*\*Exit / Postconditions:\*\* status → \`Draft\`; server logs reason in audit; returns new ETag

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*detail / btn-reject\*\* — ผู้อนุมัติกด Reject    
   \- Trigger: POST /erp/master/products/{id}:reject    
   \- map\_in: { reason: string (required), comment?: string } ; Headers: If-Match: \`\<etag\>\`, X-Audit-Reason required (per API) ; X-Idempotency-Key recommended \= ui:{user.id}:{product.id}    
   \- assert: client validates presence of reason before calling    
   \- System: Server sets status="Draft", records audit entry with reason, returns { id, status:"Draft", reverted\_at } \+ new ETag    
   \- map\_out: update product status UI, display revert reason in Audit tab    
   \- UI Feedback: Show modal with textarea reason (required) ; on success toast "ส่งกลับให้ผู้ขอแก้ไข" and focus top of Detail    
   \- Navigation/State: remain on Detail; invalidate caches    
   \- Field & Copy Checklist:  
     \- Modal fields: input-reject-reason | ข้อความเหตุผล | required | error "เหตุผลต้องไม่ว่าง"    
     \- data-test-id: btn-reject-product, modal-reject-reason, btn-reject-confirm, toast-reject-success  
     \- a11y: textarea labelled, focus in textarea on open  
2\) … (end happy path)

\#\#\#\# Variants & Exceptions  
\- Step 1 → 400\_VALIDATION\_FAILED (missing reason) → client prevents call; server returns 400/422 if missing; show inline error "กรุณาระบุเหตุผลการปฏิเสธ"    
\- Step 1 → 403\_FORBIDDEN (user not authorized) → show toast \+ redirect to List    
\- Step 1 → 412\_PRECONDITION\_FAILED (ETag mismatch) → show merge dialog; refetch; retry with same idempotency key

\#\#\#\# Telemetry & Audit  
\- Events:  
  \- product.rejected { id, actor\_id, reason, correlation\_id }    
\- Audit Fields: actor\_id, reason, diff, idempotency\_key

\#\#\#\# Test Hooks  
\- data-test-id: btn-reject-product, modal-reject-reason, btn-reject-confirm, api-reject-call, toast-reject-success

\#\#\#\# Acceptance (Gherkin)  
\- Given สินค้ากำลัง In Review    
\- When Approver ปฏิเสธด้วยเหตุผล    
\- Then สถานะเปลี่ยนเป็น Draft และบันทึกเหตุผลใน Audit

\#\#\#\# Assumptions & Confidence  
\- API \`:reject\` มีอยู่ตาม API List (Confidence: High)

\---

\#\#\# Journey: สรุป/เปิดใช้งานสินค้า (Finalize / Activate) (Actor: Admin / Approver)  
\*\*Entry:\*\* จาก Detail \`/erp/master/products/{id}\` (status \= Approved) → ปุ่ม Activate    
\*\*Preconditions:\*\* status \== \`Approved\`; user role Approver or Admin; no open references (PR/PO/GRN) per precondition (server checks) ; client holds If-Match ETag    
\*\*Exit / Postconditions:\*\* status → \`Active\` ; event product.activated emitted

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*detail / btn-activate\*\* — ผู้ใช้กด Activate    
   \- Trigger: POST /erp/master/products/{id}:activate    
   \- map\_in: { comment?: string } ; Headers: If-Match: \`\<etag\>\`, X-Idempotency-Key: ui:{user.id}:{product.id}    
   \- assert: client ensures status \== "Approved" and user role; optionally client can call a lightweight pre-check endpoint (not provided) — rely on server for final check    
   \- System: Server validates no open references; if passes, set status="Active", return {id, status:"Active", activated\_at} \+ new ETag ; emit product.activated    
   \- map\_out: new status, activated\_at, new ETag; update UI badge to Active    
   \- UI Feedback: Confirmation modal "เปิดใช้งานสินค้านี้?" ; on success toast "เปิดใช้สินค้าแล้ว"    
   \- Navigation/State: remain on Detail; invalidate list cache so PR/PO pickers can select product    
   \- Field & Copy Checklist:  
     \- Confirm modal copy: "ยืนยันการเปิดใช้งานสินค้า" ; data-test-id: modal-activate-confirm, btn-activate-product, toast-activate-success  
     \- a11y: focus on confirm button; Alt+C shortcuts not applicable here  
2\) … (end happy path)

\#\#\#\# Variants & Exceptions  
\- Activate → 409\_CONFLICT (open PR exists)    
  \- Server returns details: { field: "references", message: "PR-00045" }    
  \- UX: show error modal with "ไม่สามารถเปิดใช้งาน: มีเอกสารอ้างอิงเปิดอยู่ PR-00045" and CTA "ดู PR" or "บันทึก override (ถ้ามีสิทธิ์)"    
  \- If controller override feature exists (not specified), show override flow; otherwise instruct user to close PR first    
\- Activate → 403\_FORBIDDEN if user lacks role    
\- Activate → 412\_PRECONDITION\_FAILED (ETag mismatch) → fetch latest and retry using same X-Idempotency-Key

\#\#\#\# Telemetry & Audit  
\- Events:  
  \- product.activate.requested { id, actor\_id, correlation\_id }    
  \- product.activated { id, actor\_id, timestamp }    
\- Audit Fields: idempotency\_key, actor\_id, reason/comment

\#\#\#\# Test Hooks  
\- data-test-id: btn-activate-product, modal-activate-confirm, api-activate-call, toast-activate-success

\#\#\#\# Acceptance (Gherkin)  
\- Given สินค้าอยู่ในสถานะ Approved    
\- When ผู้ใช้กด เปิดใช้งาน และยืนยัน    
\- Then สถานะเปลี่ยนเป็น Active และเหตุการณ์ product.activated ถูกปล่อย

\#\#\#\# Assumptions & Confidence  
\- สมมติไม่มี "controller override" ระบุไว้ใน API — หากต้องการ override ต้องเพิ่ม flag \+ RBAC (TODO) (Confidence: Medium)

\---

\#\#\# Journey: ดูรายละเอียดสินค้า (Actor: Viewer / Any role with read)  
\*\*Entry:\*\* จาก List \`/erp/master/products\` → คลิก row code หรือ deeplink \`/erp/master/products/{id}\`    
\*\*Preconditions:\*\* ผู้ใช้มีสิทธิ์อ่าน (Authorization header token valid)    
\*\*Exit / Postconditions:\*\* หน้าแสดงรายละเอียด พร้อม ETag header สำหรับ subsequent edits

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*list row / link-code\*\* — ผู้ใช้คลิกรหัสสินค้าในตาราง    
   \- Trigger: NAV → GET /erp/master/products/{id}    
   \- map\_in: none (just path param id)    
   \- assert: client must send Authorization header    
   \- System: Server returns Product full payload \+ ETag header    
   \- map\_out: product object with child arrays (product\_barcode\[\], product\_uom\_conv\[\], product\_vendor\[\], product\_image\[\], product\_doc\[\]) \+ ETag    
   \- UI Feedback: show skeleton while loading; on success render Overview tab; set focus to main heading; aria-live region for load failure    
   \- Navigation/State: route \`/erp/master/products/{id}\` ; store etag for edits    
   \- Field & Copy Checklist:  
     \- Fields to display: id, code, name, type, category\_id (render name), status, base\_uom, purchase\_uom, tracking, weight/length/width/height, tax\_code\_id (masked if role non-Finance), gl\_inventory\_acct\_id (masked), product\_barcode\[\], product\_uom\_conv\[\], product\_vendor\[\], product\_image\[\], product\_doc\[\]    
     \- data-test-id: page-product-detail, hdr-product-code, badge-status, tab-overview, tab-uom, tab-vendors, tab-tax-gl, tab-images, tab-audit  
     \- a11y: badges include aria-label="สถานะ: {status}", heading h1 has id for skiplinks  
2\) … (end happy path)

\#\#\#\# Variants & Exceptions  
\- GET → 404\_NOT\_FOUND: show page-level 404 with CTA "กลับไปหน้ารายการ" data-test-id: btn-back-to-list    
\- GET → 401/403: redirect to login or show 403 toast \+ redirect to list    
\- Large payload images/docs network timeout: show partial content with message "โหลดไฟล์ไม่สำเร็จ" and retry button data-test-id: btn-retry-load-docs

\#\#\#\# Telemetry & Audit  
\- Events:  
  \- product.view.detail { id, actor\_id, timestamp, correlation\_id }    
\- Audit: view not stored as audit\_entry by default (depends on policy)

\#\#\#\# Test Hooks  
\- data-test-id: page-product-detail, api-get-product, hdr-product-code, badge-status, tab-overview

\#\#\#\# Acceptance (Gherkin)  
\- Given มีสินค้าที่ id=1002    
\- When ผู้ใช้เปิด /erp/master/products/1002    
\- Then ระบบแสดงข้อมูลสินค้าเต็มรูปแบบพร้อม ETag

\#\#\#\# Assumptions & Confidence  
\- Response includes ETag header per API docs (Confidence: High)

\---

\#\#\# Journey: ดู/ดาวน์โหลดเอกสาร & พรีวิวฉลาก PDF (Document Viewer & Download) (Actor: Viewer / Warehouse)  
\*\*Entry:\*\* จาก Detail tab Images/Docs หรือ Print Label modal (จาก List/Detail)    
\*\*Preconditions:\*\* Authorization valid; file\_url (for docs) or label template exists; if label generation returns 202 job \=\> client must poll (poll endpoint not provided — see TODO)    
\*\*Exit / Postconditions:\*\* ผู้ใช้ดูเอกสารใน iframe/modal และมีปุ่ม fallback “Open original link” (\`btn-open-original\`)

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*detail tab images / doc row / btn-view-doc\*\* — ผู้ใช้คลิกดาวน์โหลด/ดูเอกสาร (PDF)    
   \- Trigger: direct GET to file\_url (file service) OR call GET /erp/master/products/{id}:label?template={template\_id} for label    
   \- map\_in: for label \-\> query param template (optional) ; for product doc \-\> file\_url known from product\_doc\[\]    
   \- assert: client ensures Authorization for API label request; for file\_url (external) ensure CORS or direct download link    
   \- System:  
     \- If GET /:label returns application/pdf (200) → open embedded PDF preview (iframe)    
     \- If returns 202 with job\_id → show job pending UI and schedule poll (job polling endpoint missing in API list → TODO)    
   \- map\_out: PDF binary or { job\_id, status:"accepted" }    
   \- UI Feedback: show modal PDF preview with spinner; always include fallback button \`btn-open-original\` that opens file\_url in new tab; provide data-test-id pdf-preview-iframe and btn-open-original    
   \- Navigation/State: modal open; focus trap inside modal; Esc closes modal    
   \- Field & Copy Checklist:  
     \- Buttons: btn-download-pdf, btn-open-original (links to original), btn-close-preview    
     \- Messages: if 422 from server "Template does not support symbology" show specific message and suggest alternative template  
     \- a11y: iframe has title "Preview เอกสารสินค้า {code}" ; fallback link has aria-label  
2\) … (end happy path)

\#\#\#\# Variants & Exceptions  
\- GET /:label → 422\_INVALID\_STATE: show message "เทมเพลตไม่รองรับ symbology นี้" with CTA choose another template (data-test-id: msg-label-invalid)    
\- GET /:label → 202 accepted (async): show job tracking UI with message "กำลังสร้าง PDF" and button "ดาวน์โหลดเมื่อพร้อม" ; since job poll endpoint is not in API list, instruct user to retry "รีเฟรช" or check notification when ready — (TODO: add job polling or webhook)    
\- File CDN/network error → fallback open-original still available; else show "ไม่สามารถโหลดไฟล์" with retry

\#\#\#\# Telemetry & Audit  
\- Events:  
  \- br.document\_viewed { id, doc\_id?, actor\_id, template\_id? } — use dot-case \`br.document\_viewed\` as telemetry naming convention in constraints    
  \- br.document\_downloaded { id, doc\_id?, actor\_id }    
\- Audit Fields: actor\_id, resource id, doc\_id, template

\#\#\#\# Test Hooks  
\- data-test-id: btn-view-doc, pdf-preview-iframe, btn-open-original, btn-download-pdf, pdf-job-polling

\#\#\#\# Acceptance (Gherkin)  
\- Given มีไฟล์ spec-1.pdf ใน product\_doc    
\- When ผู้ใช้กด ดูเอกสาร    
\- Then ระบบเปิด modal แสดง PDF และมีปุ่ม Open original ถ้า iframe ล้มเหลว

\#\#\#\# Assumptions & Confidence  
\- สมมติ file\_url เป็นลิงก์ตรงที่เข้าถึงได้ (Confidence: Medium); job polling endpoint missing (TODO)

\---

\#\#\# Journey: ส่งออกรายการสินค้า (Export List) (Actor: Viewer/Admin)  
\*\*Entry:\*\* จากหน้า List \`/erp/master/products\` → ปุ่ม ส่งออก (Export)    
\*\*Preconditions:\*\* ผู้ใช้มีสิทธิ์ส่งออก (scope product.export) ; filters/pagination applied as required; server may return sync CSV for small set or 202 job for async large export    
\*\*Exit / Postconditions:\*\* หากเล็กส่งคืน CSV (200) ให้ดาวน์โหลดทันที; หากใหญ่ server คืน {job\_id, status:"accepted"} → client shows job pending UI

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*list / btn-export\*\* — ผู้ใช้กด Export (with current filters)    
   \- Trigger: GET /erp/master/products:export?{filters}\&format=csv    
   \- map\_in: query filters same as list filters (q,status\[\],type,category\_id,vendor\_id,tracking,updated\_from,updated\_to,sort) ; do not send server-derived fields    
   \- assert: client ensures Authorization; show confirm for large export if client pre-check shows \> threshold (client-side guess)    
   \- System: Server responds:  
     \- Case small result: 200 Content-Type: text/csv (binary) → initiate download    
     \- Case large: 202 { job\_id, status:"accepted" } → client shows pending and polling (poll endpoint missing in API list → TODO)    
   \- map\_out: CSV binary or job\_id    
   \- UI Feedback: show spinner; on 200 start file download and toast "ดาวน์โหลดสำเร็จ"; on 202 show banner "การส่งออกกำลังดำเนินการ" with job id and CTA "ตรวจสอบงาน"    
   \- Navigation/State: remain on List; telemetry product.export emitted    
   \- Field & Copy Checklist:  
     \- data-test-id: btn-export, export-format-select, toast-export-success, export-job-banner, btn-download-export  
     \- messages: 429 rate-limit message "เกินโควตาการส่งออก โปรดลองอีกครั้งภายหลัง" with Retry-After handling  
     \- a11y: export dropdown labelled "เลือกรูปแบบไฟล์"  
2\) … (end happy path)

\#\#\#\# Variants & Exceptions  
\- GET → 429\_TOO\_MANY\_REQUESTS: show banner with Retry-After seconds ; client exponential backoff (retry defaults: read=2)    
\- GET → 202 accepted: show job banner, enable polling (TODO: job polling endpoint) or provide download\_url when job completes via webhook/notification    
\- GET → 403\_FORBIDDEN: show toast "คุณไม่มีสิทธิ์ส่งออก"

\#\#\#\# Telemetry & Audit  
\- Events:  
  \- product.export.requested { actor\_id, filters, export\_format, correlation\_id }    
  \- product.export.completed { job\_id?, download\_url? }    
\- Audit Fields: actor\_id, filters, job\_id

\#\#\#\# Test Hooks  
\- data-test-id: btn-export, export-format-select, api-export-call, export-job-banner, toast-export-success

\#\#\#\# Acceptance (Gherkin)  
\- Given มีรายการสินค้ามากกว่า 0    
\- When ผู้ใช้กด ส่งออก และระบบตอบด้วย CSV    
\- Then ไฟล์ถูกดาวน์โหลด หรือ job\_id คืนมาเมื่อเป็นงานใหญ่

\#\#\#\# Assumptions & Confidence  
\- Polling endpoint or webhook for exports not provided in API list — TODO to add (Confidence: Medium)

\---

\#\#\# Journey: Bulk Deactivate สินค้าหลายรายการ (Actor: Admin)  
\*\*Entry:\*\* จาก List \`/erp/master/products\` → ผู้ดูแลเลือกหลายแถว → Bulk Actions → Deactivate    
\*\*Preconditions:\*\* ผู้ใช้มี role Admin; selected ids\[\] non-empty; X-Idempotency-Key required    
\*\*Exit / Postconditions:\*\* Server returns per-id result array with success/failed and message; events product.deactivated per successful id

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*list / bulk-checkbox \+ btn-bulk-deactivate\*\* — ผู้ใช้เลือกหลายแถวและเลือก Bulk Deactivate    
   \- Trigger: POST /erp/master/products:bulk    
   \- map\_in: { action: "deactivate", ids: \["1003","1004"\], params: { reason: "seasonal", override: false } } ; Headers: X-Idempotency-Key: ui:{user.id}:bulk\_deactivate:{hash(ids|params)}    
   \- assert: client ensures role Admin and non-empty ids    
   \- System: Server processes each id and returns results per id with status success/failed and messages (may be 200\)    
   \- map\_out: { action, results\[\] } ; for successes, server may emit product.deactivated events    
   \- UI Feedback: show progress modal with per-id status rows; on completion show summary toast "2 สำเร็จ / 1 ล้มเหลว" and show details; provide retry failed button using same idempotency key    
   \- Navigation/State: refresh list rows to reflect statuses changed; invalidate cache    
   \- Field & Copy Checklist:  
     \- data-test-id: bulk-select-checkbox, btn-bulk-deactivate, modal-bulk-progress, bulk-result-row-{id}, btn-retry-failed  
     \- messages: "ผลการดำเนินการ: {success}/{total}" ; per-failure show reason (e.g., "open PR PR-00050")  
2\) … (end happy path)

\#\#\#\# Variants & Exceptions  
\- Bulk → 403\_FORBIDDEN: show error "สิทธิ์ไม่เพียงพอสำหรับ Bulk deactivate"    
\- Bulk → per-id failure because of open refs \-\> result for id shows message and guidance "ดู PR-00050"    
\- Bulk → idempotency CONFLICT: reuse same X-Idempotency-Key for retry; server dedupes

\#\#\#\# Telemetry & Audit  
\- Events:  
  \- product.bulk.actioned { action:"deactivate", actor\_id, ids\[\], correlation\_id }    
\- Audit Fields: actor\_id, idempotency\_key, ids

\#\#\#\# Test Hooks  
\- data-test-id: bulk-select-checkbox, btn-bulk-deactivate, api-bulk-call, modal-bulk-progress, bulk-result-row-1003

\#\#\#\# Acceptance (Gherkin)  
\- Given ผู้ใช้เป็น Admin และเลือกรายการสินค้า 2 รายการ    
\- When ผู้ใช้เรียก Bulk Deactivate    
\- Then ระบบคืนผล per-id และอัพเดตสถานะสำหรับรายการที่สำเร็จ

\#\#\#\# Assumptions & Confidence  
\- Bulk API supports action "deactivate" per API list (Confidence: High)

\---

\#\#\# Journey: Retry การสร้างเอกสาร (Label) ที่เป็น Async (Actor: Warehouse / Viewer)  
\*\*Entry:\*\* ผู้ใช้ขอพิมพ์ฉลาก → server คืน 202 job\_id → ผู้ใช้ยังไม่ได้รับ PDF → กด Retry Generate    
\*\*Preconditions:\*\* original job returned 202 with job\_id; client saved idempotency key used for doc-gen    
\*\*Exit / Postconditions:\*\* เมื่อสำเร็จ serverคืน PDF หรือ download\_url; event br.document\_created emitted

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*label modal / btn-generate-label\*\* — ผู้ใช้ขอ Generate label และได้รับ 202 job\_id    
   \- Trigger: GET /erp/master/products/{id}:label?template={template\_id} → 202 { job\_id }    
   \- map\_in: template param ; Headers Authorization    
   \- assert: client stores job\_id and idempotency key used for doc-gen: X-Idempotency-Key \= ui:{user.id}:{product.id}:doc    
   \- System: server processes async job; on completion either provides download\_url or the client must poll job endpoint (not provided)    
   \- map\_out: { job\_id, status }    
   \- UI Feedback: show banner "กำลังสร้างฉลาก (job-{id})" with Retry button (data-test-id: btn-retry-label-gen) ; when user retries use same idempotency key    
   \- Navigation/State: remain in modal; show link to "Open original" as fallback (btn-open-original)    
   \- Field & Copy Checklist:  
     \- data-test-id: btn-generate-label, label-job-banner, btn-retry-label-gen, pdf-download-link  
     \- confirm copy: "กำลังสร้าง PDF หากใช้เวลานาน โปรดใช้ปุ่ม Retry"    
2\) \*\*retry\*\* — ผู้ใช้กด Retry    
   \- Trigger: GET /erp/master/products/{id}:label with same X-Idempotency-Key (ui:{user.id}:{product.id}:doc)    
   \- map\_in: same template param    
   \- assert: reuse idempotency key per constraint (Hard Constraint §5)    
   \- System: Server dedupes and either returns existing PDF (200) or same job accepted (202) — client must handle both    
   \- map\_out: PDF binary or job\_id    
   \- UI Feedback: if PDF returned start download; on 202 update banner  
3\) … (end happy path)

\#\#\#\# Variants & Exceptions  
\- Retry with different idempotency key → server treats as new job; risk duplicate processing — client should reuse same key    
\- Retry → 422\_INVALID\_STATE (template not supporting symbology) → show message with alternative templates list    
\- Missing job polling endpoint → client may provide manual Retry UI (TODO)

\#\#\#\# Telemetry & Audit  
\- Events:  
  \- br.document\_generation.requested { id, job\_id?, actor\_id, idempotency\_key }    
  \- br.document\_created { id, doc\_id?, actor\_id }    
\- Audit Fields: idempotency\_key, job\_id, actor\_id

\#\#\#\# Test Hooks  
\- data-test-id: label-job-banner, btn-retry-label-gen, btn-open-original, api-label-call

\#\#\#\# Acceptance (Gherkin)  
\- Given ผู้ใช้เรียกสร้างฉลากและได้ job\_id    
\- When ผู้ใช้กด Retry ด้วย idempotency key เดิม    
\- Then ระบบคืนไฟล์ PDF หรือ job accepted และไม่สร้างงานซ้ำ

\#\#\#\# Assumptions & Confidence  
\- Polling endpoint for async label jobs is missing — TODO to add; idempotency key pattern for doc-gen per Hard Constraints (Confidence: Medium)

\---

\#\#\# Journey: เปิดจากการแจ้งเตือน (Deeplink to Detail) (Actor: Any role)  
\*\*Entry:\*\* ผู้ใช้คลิก Notification ที่ชี้ไปยัง \`/erp/master/products/{id}\` (ตัวอย่าง: product.submitted notification)    
\*\*Preconditions:\*\* Notification payload contains product id and route \`/erp/master/products/{id}\` ; user session active (or redirect to login)    
\*\*Exit / Postconditions:\*\* เปิด Detail page with context (highlight relevant action) and prefetch of latest ETag

\#\#\#\# Happy Path — ขั้นตอนละเอียด  
1\) \*\*notification click\*\* — ผู้ใช้คลิกลิงก์ใน notification    
   \- Trigger: NAV → route \`/erp/master/products/{id}\` with query param \`src=notification\&event=product.submitted\&corr={cid}\`    
   \- map\_in: id from route ; optional query params for context    
   \- assert: client authenticates user (redirect to login if not)    
   \- System: client calls GET /erp/master/products/{id} to hydrate page and obtains ETag; optionally call audit GET /.../audit to show related event    
   \- map\_out: product object \+ ETag ; audit entries for event context    
   \- UI Feedback: show highlight banner "เปิดจากการแจ้งเตือน: product.submitted" with CTA "ดูเหตุผล/ดูประวัติ" ; focus main heading    
   \- Navigation/State: landing on Detail; mark notification as read via Notification service (outside scope)    
   \- Field & Copy Checklist:  
     \- data-test-id: notif-deeplink, page-product-detail, banner-notification-context, btn-view-audit  
     \- a11y: banner has role="status" aria-live  
2\) … (end happy path)

\#\#\#\# Variants & Exceptions  
\- Notification points to nonexistent id → GET returns 404 → show 404 page with CTA "กลับไปหน้ารายการ" and data-test-id btn-back-to-list    
\- Notification opens but ETag mismatch later when user attempts mutation → handle 412 per merge flow

\#\#\#\# Telemetry & Audit  
\- Events:  
  \- product.notification.opened { id, actor\_id, correlation\_id, event }    
\- Audit: reading not necessarily stored

\#\#\#\# Test Hooks  
\- data-test-id: notif-deeplink, page-product-detail, banner-notification-context

\#\#\#\# Acceptance (Gherkin)  
\- Given มีการแจ้งเตือน product.submitted ที่มีลิงก์    
\- When ผู้ใช้คลิกลิงก์    
\- Then ระบบเปิด /erp/master/products/{id} และแสดงบริบทของการแจ้งเตือน

\#\#\#\# Assumptions & Confidence  
\- Notification service and mark-as-read flows exist out-of-scope (Confidence: Medium)

\---

\#\# Self-Validation Summary (Automated Checks performed)  
\- Status labels: ใช้ status ตาม API responses (Draft, In Review, Approved, Active, Inactive, Obsolete). ทุกที่ที่กล่าวถึง state ใช้ค่าเหล่านี้เท่านั้น.    
\- Map-In Audit: ทุกการเรียก POST/PATCH/Action ได้ระบุเฉพาะ field ที่ API ยอมรับ (identifier \+ user inputs) — หลีกเลี่ยงการส่งค่า server-owned เช่น on\_hand, totals.    
\- Row Action Guards: ระบุ visibility rules (e.g., Submit visible when status==Draft; Approve visible when status==In Review; Activate visible when status==Approved). Server still re-asserts.    
\- Idempotency Audit: ระบุรูปแบบ idempotency keysสำหรับแต่ละ action (create, submit, approve, activate, doc-gen, bulk) ตาม Hard Constraints (ตัวอย่าง: ui:{user.id}:{product.id}:{hash(...)}).    
\- Telemetry Case: ทุกเหตุการณ์ใช้ dot-case เช่น product.create, product.submitted, product.approved, product.activated, product.bulk.actioned, br.document\_viewed.    
\- Document Viewer Fallback: ทุก flow ที่มี PDF preview มีปุ่ม \`btn-open-original\` สำหรับ fallback.    
\- Test Hooks: สำหรับทุก actionable step ระบุ data-test-id (see above). หาก Page Definition ไม่ได้ให้ test-ids แบบเฉพาะ เราเพิ่มชื่อตาม convention (ตัวอย่างข้างต้น) — รายการที่เพิ่มเหล่านี้ถูกใส่ใน TODOs ด้านล่างเพื่อให้ทีม frontend เพิ่มเข้าไปใน page templates.    
\- Routes: ใช้ base\_path \`/erp/master/products\` และ routes ตาม Page Definitions (leading slash present).    
\- Per-step Field/COPY Coverage: ทุกขั้นตอนใน Happy Path ประกอบด้วย Field & Copy Checklist (ฟิลด์ที่ต้องกรอก/แสดง \+ helper/confirm/validation copy \+ data-test-id \+ a11y).    
\- Schema Echo Check: ทุก field ที่อ้างถึงมีอยู่ใน API Request/Response examples; ถ้าฟิลด์ไม่มีใน schema จะขึ้น TODO รายการด้านล่าง.    
\- Page Binding Consistency: ทุก action ผูกกับ API endpoint ที่ปรากฎใน API List.

\---

\#\# TODOs (รายการสิ่งที่ขาด / ต้องยืนยัน / ต้องเพิ่มในสเปค)  
1\) Add job polling / job status endpoint for async exports & label generation (e.g., GET /jobs/{job\_id}) — เพื่อให้ client สามารถ poll download\_url. (required for Export J6 & Label async)    
2\) Clarify "controller override" RBAC and API flag for Activate/Deactivate when open references exist (e.g., allow override=true \+ approver signature) — currently unspecified; UI presents override option but API does not define override parameter. (must define role & API)    
3\) Confirm file upload API (file service endpoint) and contract for ProductImage/ProductDoc upload → client currently assumes external file upload returns \`file\_url\` to include in product payload. (missing in API list)    
4\) Provide explicit list of "critical fields" that trigger revision flow when edited while status=Active (page warnings mention base\_uom, tax/GL, tracking; please confirm full list). (required for revision flow correctness)    
5\) Provide rate-limit / retry headers semantics for export & label job (Retry-After header format already noted for 429\) — clarify for long-running jobs.    
6\) Job polling webhook or callback details for asynchronous label/export jobs (download\_url vs job\_id lifecycle). (needed for Retry Document Generation & Export)    
7\) Confirm masking rules for GL/tax fields per role in API responses (server-side masking) — current UI assumes GL masked for non-Finance. (specify masking logic)    
8\) Add data-test-id entries to Page Definitions templates (packingList.v1, createDrawer.v2, viewDrawer.v1, importDrawer.v1, deleteConfirm.v1) for each control referenced above (list items):    
   \- btn-open-create, drawer-create-product, input-code, input-name, select-base\_uom, table-barcode, btn-save-draft, btn-create-submit, btn-submit-product, confirm-submit-product, btn-approve-product, modal-approve-confirm, btn-reject-product, modal-reject-reason, btn-activate-product, modal-activate-confirm, btn-export, export-job-banner, btn-bulk-deactivate, modal-bulk-progress, btn-retry-label-gen, btn-open-original, pdf-preview-iframe, page-product-detail, hdr-product-code, badge-status, tab-tax-gl, tab-uom, tab-vendors, tab-images, tab-audit, api-\* call hooks. (Please add these to templates)    
9\) Confirm behavior for Import \`mode=upsert\` — how to handle existing active products (create revision? update directly?) and whether import can create Approved/Active items or only Draft. (clarify import policy)    
10\) Confirm whether product.approved event should auto-trigger downstream consumers (PR/PO/GRN) or only notify; define contract for event payload (snapshot\_id or full minimal snapshot). (events payload spec missing)    
11\) Provide polling or webhook endpoint for import/report download\_url (import returns report\_url but for async operations we need consistent job model).    
12\) Clarify role mapping for "Editor" vs "Admin" for Create access — Page Definitions states "Create Drawer visible only to Admin" but other sections reference Editor creating drafts. Confirm RBAC table.    
13\) Add explicit data model for barcode uniqueness check across products (to allow client-side duplicate detection) — currently server will return 400 on duplicate but client UX may prefer pre-check endpoint.    
14\) Confirm decimal precision/validation rules in UI components (e.g., factor decimal(18,6), price\_hint decimal(18,4)) — UI must enforce same precision. (partially provided in API notes but formalize)

\---

\#\# Confidence & Notes  
\- Confidence (overall): Medium–High for API mappings and page flows because API List and Page Definitions cover the majority of endpoints and fields. Gaps are primarily around async job polling, file upload contract, controller override semantics, and RBAC nuance for Create. These have been listed in TODOs.    
\- If any TODOs are resolved, journeys can be updated to include polling endpoints, explicit override parameters, and exact test-id placements in templates.

\#\# 10.0 Data Schema

\#\#\# 10.0.1 ภาพรวมเอนทิตี (Entity Overview)  
\- products — สินค้า (master) เก็บข้อมูลโค้ด/ชนิด/UOM/GL/Tax/สถานะ \+ ความสัมพันธ์กับ barcodes, uom\_conversions, vendors, images, docs, audit    
\- product\_uom\_convs — กราฟการแปลงหน่วยของสินค้า (จาก→ถึง, factor) (N:1 → products)    
\- product\_vendors — รายการ vendor ของสินค้า (N:1 → products) พร้อม flag preferred (unique per product+currency)    
\- product\_barcodes — บาร์โค้ดของสินค้า (N:1 → products) พร้อม flag is\_primary (unique per symbology+value)    
\- product\_images — รูปภาพสินค้า (N:1 → products)    
\- product\_docs — เอกสาร/ไฟล์สินค้า (N:1 → products)    
\- categories — หมวดหมู่สินค้า (hierarchy: parent\_id → categories)    
\- product\_audits — บันทึกการกระทำ/สถานะของสินค้า (N:1 → products) — เก็บ audit (actor, role, action, reason, diff)

\#\#\# 10.0.2 สคีมาตามตาราง

\#\#\# ตาราง products — Product master record  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`PRD-{SEQ}\`) — UNIQUE    
\- UK: \`uq\_products\_code (code)\`    
\- FK: \`category\_row\_id → categories.row\_id (ON UPDATE CASCADE ON DELETE RESTRICT)\`    
\- Parent-of: product\_barcodes / product\_uom\_convs / product\_vendors / product\_images / product\_docs / product\_audits    
\- Child-of: category (optional)

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---|---|---|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | pk | คีย์ภายใน (ไม่เปิดเผยผ่าน API) |  
| id | varchar(14) | UNIQUE | NO | trigger | CHECK (id \~ '^PRD-\\d{10}$') | uq\_products\_code? | รหัสสั้นอ่านง่าย |  
| code | varchar(32) | \- | NO | \- | UNIQUE, immutable when status='Active' (trigger) | idx\_products\_code | รหัสธุรกิจ (ไม่แก้ไขเมื่อ Active) |  
| name | varchar(200) | \- | NO | \- | \- | idx\_products\_name | ชื่อสินค้า |  
| type | text | \- | NO | 'Stock' | CHECK (type IN ('Stock','NonStock','Service')) | idx\_products\_type | ประเภทสินค้า |  
| category\_row\_id | uuid | FK | YES | NULL | \- | idx\_products\_category\_row\_id | FK → categories.row\_id |  
| status | text | \- | NO | 'Draft' | CHECK (status IN ('Draft','In Review','Approved','Active','Inactive','Obsolete')) | idx\_products\_status\_updated\_at | สถานะตาม workflow |  
| base\_uom | varchar(32) | \- | NO | \- | \- | idx\_products\_base\_uom | หน่วยฐาน (บังคับ) |  
| purchase\_uom | varchar(32) | \- | YES | NULL | \- | \- | UOM สำหรับซื้อ |  
| tracking | text | \- | NO | 'None' | CHECK (tracking IN ('None','Lot','Serial')) | idx\_products\_tracking | การติดตาม lot/serial |  
| weight | decimal(18,3) | \- | YES | NULL | \>=0 | \- | น้ำหนัก |  
| length | decimal(18,2) | \- | YES | NULL | \>=0 | \- | ขนาดความยาว |  
| width | decimal(18,2) | \- | YES | NULL | \>=0 | \- | ความกว้าง |  
| height | decimal(18,2) | \- | YES | NULL | \>=0 | \- | ความสูง |  
| weight\_uom | varchar(8) | \- | YES | NULL | \- | \- | หน่วยน้ำหนัก |  
| volume\_uom | varchar(8) | \- | YES | NULL | \- | \- | หน่วยปริมาตร |  
| tax\_code\_id | varchar(64) | \- | YES | NULL | \- | idx\_products\_tax\_code\_id | อ้างอิง Tax master (external id/string) |  
| gl\_inventory\_acct\_id | varchar(64) | \- | YES | NULL | \- | idx\_products\_gl\_inventory\_acct\_id | รหัสบัญชีสินค้าคงคลัง (external) |  
| gl\_expense\_acct\_id | varchar(64) | \- | YES | NULL | \- | idx\_products\_gl\_expense\_acct\_id | รหัสบัญชีค่าใช้จ่าย (external) |  
| cost\_method | text | \- | NO | 'Standard' | CHECK (cost\_method IN ('Standard','MovingAvg')) | \- | วิธีคำนวณต้นทุน |  
| standard\_cost | decimal(18,4) | \- | YES | NULL | \>=0 | idx\_products\_standard\_cost | ต้นทุนมาตรฐาน |  
| hazardous | boolean | \- | NO | false | \- | idx\_products\_hazardous | วัตถุอันตราย |  
| shelf\_life\_days | integer | \- | YES | NULL | CHECK (shelf\_life\_days \>= 0\) | \- | วันหมดอายุ (ถ้ามี) |  
| remarks | text | \- | YES | NULL | \- | \- | บันทึก/หมายเหตุ |  
| created\_at | timestamptz | \- | NO | now() | \- | idx\_products\_created\_at | วันที่สร้าง (UTC) |  
| updated\_at | timestamptz | \- | NO | now() | \- | idx\_products\_status\_updated\_at | วันที่แก้ไขล่าสุด (UTC) |  
| version | integer | \- | NO | 1 | CHECK (version \> 0\) | \- | optimistic locking |  
| deleted\_at | timestamptz | \- | YES | NULL | \- | \- | soft delete (เมื่อจำเป็น) |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- API field \`id\` ↔ DB \`id\` (public short id PRD-0000000001). API may provide public id or (legacy) numeric; mapping layer must resolve to row\_id.    
\- API \`category\_id\` (public id like CAT-0000000001) → mapped to \`category\_row\_id\` (uuid) before DB operations.    
\- GL/Tax fields passed as string ids in API → stored in respective text columns; validation of existence done by integration layer (404 if missing).

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- row:  
  \- row\_id: 3f1b9a1e-8c4d-4a2f-9c3a-1f2b3c4d5e6f  
  \- id: PRD-0000000001  
  \- code: PROD-0002  
  \- name: สารเคมีทดสอบ  
  \- type: Stock  
  \- category\_row\_id: 9a7b6c5d-1e2f-3a4b-5c6d-7e8f9a0b1c2d  
  \- status: Draft  
  \- base\_uom: L  
  \- tracking: Lot  
  \- standard\_cost: 12.3456  
  \- hazardous: false  
  \- created\_at: 2025-11-05T08:30:00Z  
  \- updated\_at: 2025-11-05T08:30:00Z

\---

\#\#\# ตาราง product\_uom\_convs — ProductUomConv (unit conversions)  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`PUC-{SEQ}\`) — UNIQUE    
\- UK: \`uq\_product\_uom\_convs\_product\_from\_to (product\_row\_id, from\_uom, to\_uom)\`    
\- FK: \`product\_row\_id → products.row\_id (ON UPDATE CASCADE ON DELETE CASCADE)\`    
\- Parent-of: — / Child-of: products

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---|---|---|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | pk | |  
| id | varchar(14) | UNIQUE | NO | trigger | CHECK (id \~ '^PUC-\\d{10}$') | \- | |  
| product\_row\_id | uuid | FK | NO | \- | \- | idx\_product\_uom\_convs\_product\_row\_id | FK → products.row\_id |  
| from\_uom | varchar(32) | \- | NO | \- | \- | idx\_product\_uom\_convs\_from\_uom | หน่วยต้นทาง |  
| to\_uom | varchar(32) | \- | NO | \- | \- | idx\_product\_uom\_convs\_to\_uom | หน่วยปลายทาง |  
| factor | decimal(18,6) | \- | NO | \- | CHECK (factor \> 0\) | \- | ค่าสเกลการแปลง |  
| created\_at | timestamptz | \- | NO | now() | \- | \- | |  
| updated\_at | timestamptz | \- | NO | now() | \- | \- | |  
| version | integer | \- | NO | 1 | CHECK (version \> 0\) | \- | |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- API arrays \`product\_uom\_conv\[\]\` map fields \`from\_uom\`, \`to\_uom\`, \`factor\` → stored here; API \`product\_id\` resolved to \`product\_row\_id\` (uuid).

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- row:  
  \- row\_id: a1b2c3d4-e5f6-4a7b-9c8d-0e1f2a3b4c5d  
  \- id: PUC-0000000001  
  \- product\_row\_id: 3f1b9a1e-8c4d-4a2f-9c3a-1f2b3c4d5e6f  
  \- from\_uom: L  
  \- to\_uom: ML  
  \- factor: 1000.000000  
  \- created\_at: 2025-11-05T08:30:00Z

\---

\#\#\# ตาราง product\_vendors — ProductVendor  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`PVN-{SEQ}\`) — UNIQUE    
\- UK: \`uq\_product\_vendor\_product\_vendor\_currency\_preferred\` (unique where preferred \= true) enforced via UNIQUE INDEX (product\_row\_id, currency) WHERE preferred \= true    
\- FK: \`product\_row\_id → products.row\_id (ON UPDATE CASCADE ON DELETE CASCADE)\`    
\- Parent-of: — / Child-of: products

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---|---|---|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | pk | |  
| id | varchar(14) | UNIQUE | NO | trigger | CHECK (id \~ '^PVN-\\d{10}$') | \- | |  
| product\_row\_id | uuid | FK | NO | \- | \- | idx\_product\_vendors\_product\_row\_id | FK → products.row\_id |  
| vendor\_id | varchar(64) | \- | NO | \- | \- | idx\_product\_vendors\_vendor\_id | รหัส vendor (external id/string); validated by integration |  
| vendor\_sku | varchar(64) | \- | YES | NULL | \- | \- | รหัสสินค้า vendor |  
| preferred | boolean | \- | NO | false | \- | idx\_product\_vendors\_preferred | ธง preferred |  
| moq | integer | \- | YES | NULL | CHECK (moq \>= 0\) | \- | minimum order quantity |  
| lead\_time\_days | integer | \- | YES | NULL | CHECK (lead\_time\_days \>= 0\) | \- | เวลานำเข้า |  
| price\_hint | decimal(18,4) | \- | YES | NULL | \>=0 | idx\_product\_vendors\_price\_hint | ราคาประมาณ |  
| currency | varchar(8) | \- | YES | NULL | \- | idx\_product\_vendors\_currency | สกุลเงิน (ISO code) |  
| created\_at | timestamptz | \- | NO | now() | \- | \- | |  
| updated\_at | timestamptz | \- | NO | now() | \- | \- | |  
| version | integer | \- | NO | 1 | CHECK (version \> 0\) | \- | |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- API \`vendor\_id\` passed as external id (e.g., VND-01) → stored in \`vendor\_id\`. Integration validates existence (404 if missing). FK to vendor master is handled at service layer (no DB FK to external table).

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- row:  
  \- row\_id: b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e  
  \- id: PVN-0000000001  
  \- product\_row\_id: 3f1b9a1e-8c4d-4a2f-9c3a-1f2b3c4d5e6f  
  \- vendor\_id: VND-01  
  \- vendor\_sku: SKU-123  
  \- preferred: true  
  \- moq: 10  
  \- lead\_time\_days: 7  
  \- price\_hint: 12.3456  
  \- currency: THB  
  \- created\_at: 2025-11-05T08:30:00Z

\---

\#\#\# ตาราง product\_barcodes — ProductBarcode  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`PBC-{SEQ}\`) — UNIQUE    
\- UK: \`uq\_product\_barcodes\_symbology\_value (symbology, value)\`    
\- FK: \`product\_row\_id → products.row\_id (ON UPDATE CASCADE ON DELETE CASCADE)\`    
\- Parent-of: — / Child-of: products

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---|---|---|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | pk | |  
| id | varchar(14) | UNIQUE | NO | trigger | CHECK (id \~ '^PBC-\\d{10}$') | \- | |  
| product\_row\_id | uuid | FK | NO | \- | \- | idx\_product\_barcodes\_product\_row\_id | FK → products.row\_id |  
| symbology | text | \- | NO | \- | CHECK (symbology IN ('EAN13','UPC','QR','Code128')) | idx\_product\_barcodes\_symbology | ประเภทบาร์โค้ด |  
| value | varchar(64) | \- | NO | \- | \<=64 | idx\_product\_barcodes\_value | ค่า/รหัสบาร์โค้ด |  
| is\_primary | boolean | \- | NO | false | \- | idx\_product\_barcodes\_is\_primary | ธง primary |  
| created\_at | timestamptz | \- | NO | now() | \- | \- | |  
| updated\_at | timestamptz | \- | NO | now() | \- | \- | |  
| version | integer | \- | NO | 1 | CHECK (version \> 0\) | \- | |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- API \`product\_barcode\[\]\` maps to this table. API \`symbology\` strings follow canonical set. API \`id\` (if provided) resolves to this table's \`id\` or \`row\_id\`.

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- row:  
  \- row\_id: c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f  
  \- id: PBC-0000000001  
  \- product\_row\_id: 3f1b9a1e-8c4d-4a2f-9c3a-1f2b3c4d5e6f  
  \- symbology: EAN13  
  \- value: 1234567890123  
  \- is\_primary: true  
  \- created\_at: 2025-11-05T08:30:00Z

\---

\#\#\# ตาราง product\_images — ProductImage  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`PIM-{SEQ}\`) — UNIQUE    
\- FK: \`product\_row\_id → products.row\_id (ON UPDATE CASCADE ON DELETE CASCADE)\`    
\- Parent-of: — / Child-of: products

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---|---|---|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | pk | |  
| id | varchar(14) | UNIQUE | NO | trigger | CHECK (id \~ '^PIM-\\d{10}$') | \- | |  
| product\_row\_id | uuid | FK | NO | \- | \- | idx\_product\_images\_product\_row\_id | FK → products.row\_id |  
| url | text | \- | NO | \- | \- | \- | ที่อยู่ไฟล์ (public URL) |  
| alt\_text | varchar(200) | \- | YES | NULL | \- | \- | ข้อความสำรอง |  
| is\_primary | boolean | \- | NO | false | \- | idx\_product\_images\_is\_primary | ธง primary |  
| created\_at | timestamptz | \- | NO | now() | \- | \- | |  
| updated\_at | timestamptz | \- | NO | now() | \- | \- | |  
| version | integer | \- | NO | 1 | CHECK (version \> 0\) | \- | |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- API \`product\_image\[\]\` → map to this table. \`url\` stored as text; files hosted externally.

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- row:  
  \- row\_id: d4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f8a  
  \- id: PIM-0000000001  
  \- product\_row\_id: 3f1b9a1e-8c4d-4a2f-9c3a-1f2b3c4d5e6f  
  \- url: https://files.example.com/img-1.jpg  
  \- alt\_text: รูปสินค้า  
  \- is\_primary: true  
  \- created\_at: 2025-11-05T08:30:00Z

\---

\#\#\# ตาราง product\_docs — ProductDoc  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`PDC-{SEQ}\`) — UNIQUE    
\- FK: \`product\_row\_id → products.row\_id (ON UPDATE CASCADE ON DELETE CASCADE)\`    
\- Parent-of: — / Child-of: products

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---|---|---|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | pk | |  
| id | varchar(14) | UNIQUE | NO | trigger | CHECK (id \~ '^PDC-\\d{10}$') | \- | |  
| product\_row\_id | uuid | FK | NO | \- | \- | idx\_product\_docs\_product\_row\_id | FK → products.row\_id |  
| file\_url | text | \- | NO | \- | \- | \- | ที่อยู่ไฟล์เอกสาร |  
| doc\_type | text | \- | NO | 'Other' | CHECK (doc\_type IN ('Spec','MSDS','Cert','Other')) | idx\_product\_docs\_doc\_type | ประเภทเอกสาร |  
| created\_at | timestamptz | \- | NO | now() | \- | \- | |  
| updated\_at | timestamptz | \- | NO | now() | \- | \- | |  
| version | integer | \- | NO | 1 | CHECK (version \> 0\) | \- | |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- API \`product\_doc\[\]\` → map to this table.

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- row:  
  \- row\_id: e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8a9b  
  \- id: PDC-0000000001  
  \- product\_row\_id: 3f1b9a1e-8c4d-4a2f-9c3a-1f2b3c4d5e6f  
  \- file\_url: https://files.example.com/spec-1.pdf  
  \- doc\_type: Spec  
  \- created\_at: 2025-11-05T08:30:00Z

\---

\#\#\# ตาราง categories — Category (hierarchy)  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`CAT-{SEQ}\`) — UNIQUE    
\- UK: \`uq\_categories\_code (code)\`    
\- FK: \`parent\_row\_id → categories.row\_id (ON UPDATE CASCADE ON DELETE RESTRICT)\` (nullable)    
\- Parent-of: products / categories (children) / Child-of: categories (parent)

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---|---|---|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | pk | |  
| id | varchar(14) | UNIQUE | NO | trigger | CHECK (id \~ '^CAT-\\d{10}$') | \- | |  
| code | varchar(32) | \- | NO | \- | UNIQUE | idx\_categories\_code | รหัสหมวดหมู่ |  
| name | varchar(200) | \- | NO | \- | \- | idx\_categories\_name | ชื่อหมวดหมู่ |  
| parent\_row\_id | uuid | FK | YES | NULL | \- | idx\_categories\_parent\_row\_id | FK → categories.row\_id |  
| created\_at | timestamptz | \- | NO | now() | \- | \- | |  
| updated\_at | timestamptz | \- | NO | now() | \- | \- | |  
| version | integer | \- | NO | 1 | CHECK (version \> 0\) | \- | |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- API \`category\_id\` ↔ DB \`id\` public; service maps to \`row\_id\` for FK usage.

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- row:  
  \- row\_id: 9a7b6c5d-1e2f-3a4b-5c6d-7e8f9a0b1c2d  
  \- id: CAT-0000000012  
  \- code: CAT-12  
  \- name: สารเคมี  
  \- parent\_row\_id: NULL  
  \- created\_at: 2025-01-01T00:00:00Z

\---

\#\#\# ตาราง product\_audits — ProductAudit (activity log)  
\*\*คีย์ & ความสัมพันธ์\*\*    
\- PK (internal): \`row\_id\`    
\- Public ID: \`id\` (\`PAD-{SEQ}\`) — UNIQUE    
\- FK: \`product\_row\_id → products.row\_id (ON UPDATE CASCADE ON DELETE CASCADE)\`    
\- Parent-of: — / Child-of: products

\*\*สคีมา\*\*  
| คอลัมน์ | ชนิดข้อมูล | คีย์ | Null | ค่าเริ่มต้น | ข้อจำกัด | ดัชนี | คำอธิบาย |  
|---|---|---|---|---|---|---|---|  
| row\_id | uuid | PK | NO | gen\_random\_uuid() | \- | pk | |  
| id | varchar(14) | UNIQUE | NO | trigger | CHECK (id \~ '^PAD-\\d{10}$') | \- | |  
| product\_row\_id | uuid | FK | NO | \- | \- | idx\_product\_audits\_product\_row\_id | FK → products.row\_id |  
| timestamp | timestamptz | \- | NO | now() | \- | idx\_product\_audits\_timestamp | เวลาเหตุการณ์ |  
| actor | varchar(200) | \- | NO | \- | \- | \- | ผู้กระทำ (identifier/email) |  
| role | text | \- | NO | \- | CHECK (role IN ('Master Data Admin','Procurement','Warehouse','Finance')) | \- | บทบาท |  
| action | text | \- | NO | \- | \- | \- | action name (create,submit,approve,activate,update,...) |  
| reason | text | \- | YES | NULL | \- | \- | เหตุผลที่ระบุ |  
| diff | jsonb | \- | YES | NULL | \- | \- | snapshot diff (optional) |  
| created\_at | timestamptz | \- | NO | now() | \- | \- | |

\*\*การแมประหว่าง API ↔ DB (ถ้ามี)\*\*  
\- GET /{id}/audit → queries this table; API returns actor, role, action, timestamp, reason, diff.

\*\*ตัวอย่างค่าข้อมูล (สมจริง)\*\*  
\- row:  
  \- row\_id: f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8a9b0c  
  \- id: PAD-0000000001  
  \- product\_row\_id: 3f1b9a1e-8c4d-4a2f-9c3a-1f2b3c4d5e6f  
  \- timestamp: 2025-11-07T14:22:00Z  
  \- actor: finance@org  
  \- role: Finance  
  \- action: approve  
  \- reason: Approved by finance  
  \- diff: {}

\---

\#\#\#\#= 10.0.3 แนวทางการตั้งดัชนี (Indexing Hints)  
\- ดัชนี FK: ทุกตาราง child มี index บน \`\<table\>\_product\_row\_id\` / \`category\_row\_id\` เป็นต้น (ชื่อ: idx\_\<table\>\_\<fk\>).    
\- Lookups: idx\_products\_code (exact lookup), idx\_product\_barcodes\_symbology (symbology), idx\_product\_barcodes\_value (value), idx\_product\_vendors\_vendor\_id, idx\_products\_status\_updated\_at (สถานะ+updated\_at), idx\_products\_base\_uom.    
\- Composite/default sort: idx\_products\_status\_updated\_at ON (status, updated\_at DESC).    
\- Unique/partial: unikues: uq\_products\_code; unique (symbology,value) on product\_barcodes; unique partial idx for preferred vendor: CREATE UNIQUE INDEX uq\_product\_vendors\_product\_currency\_preferred ON product\_vendors (product\_row\_id, currency) WHERE preferred \= true;    
\- Fulltext/search: implement application-level q search across code/name/barcode via materialized view or dedicated search index (not persisted here).

\#\# 10.1 ERD  
\`\`\`mermaid  
erDiagram  
  CATEGORIES ||--o{ PRODUCTS : has  
  CATEGORIES ||--o{ CATEGORIES : parent\_of  
  PRODUCTS ||--o{ PRODUCT\_BAR\_CODES : has  
  PRODUCTS ||--o{ PRODUCT\_UOM\_CONVS : has  
  PRODUCTS ||--o{ PRODUCT\_VENDORS : has  
  PRODUCTS ||--o{ PRODUCT\_IMAGES : has  
  PRODUCTS ||--o{ PRODUCT\_DOCS : has  
  PRODUCTS ||--o{ PRODUCT\_AUDITS : logs  
\`\`\`  
(ความสัมพันธ์อ้างอิงโดย FK → parent.row\_id; 1:N ใช้ ||--o{ ; self-parent ใช้ ||--o{)

\#\# 10.2 ไฮไลท์ DDL & นโยบายคีย์  
\- Prerequisite: CREATE EXTENSION IF NOT EXISTS pgcrypto;    
\- PK: \`row\_id UUID PRIMARY KEY DEFAULT gen\_random\_uuid()\`    
\- Public ID: ทุกโต๊ะมี \`id VARCHAR(\<len\>) NOT NULL UNIQUE\` \+ \`CHECK (id \~ '^\<PREFIX\>-\\d{10}$')\` \+ sequence \+ BEFORE INSERT trigger fn\_\<table\>\_make\_public\_id() และ seq\_\<table\>\_public\_id    
  \- ตัวอย่าง prefix mapping: products → PRD, product\_uom\_convs → PUC, product\_vendors → PVN, product\_barcodes → PBC, product\_images → PIM, product\_docs → PDC, categories → CAT, product\_audits → PAD    
\- created\_at / updated\_at default now(); version integer default 1 CHECK (version\>0)    
\- Foreign Keys: ทุก FK อ้างอิง parent.row\_id; default: ON UPDATE CASCADE ON DELETE RESTRICT; ยกเว้น child tables (\`\*\_uom\_convs\`, \`\*\_vendors\`, \`\*\_barcodes\`, \`\*\_images\`, \`\*\_docs\`, \`\*\_audits\`) → ON DELETE CASCADE    
\- Constraints:  
  \- CHECK enums as TEXT \+ CHECK (...) ตาม canonical (status, type, tracking, cost\_method, symbology, doc\_type)    
  \- UNIQUE products.code (uq\_products\_code)    
  \- UNIQUE product\_barcodes (symbology, value) (uq\_product\_barcodes\_symbology\_value)    
  \- UNIQUE PARTIAL preferred vendor: CREATE UNIQUE INDEX uq\_product\_vendors\_product\_currency\_preferred ON product\_vendors(product\_row\_id, currency) WHERE preferred \= true    
\- Business rules enforced in DB where feasible:  
  \- Prevent update of products.code when status \= 'Active' via BEFORE UPDATE trigger (raises exception).    
  \- Prevent type=Service with non-null gl\_inventory\_acct\_id via CHECK or trigger: CHECK NOT (type='Service' AND gl\_inventory\_acct\_id IS NOT NULL). Also CHECK (type='Service' \=\> tracking \= 'None').    
  \- Prevent preferred vendors \>1 per product+currency via unique partial index (see above).    
\- Rules enforced at application/integration layer (documented): UOM conversion acyclic graph; open PR/PO/GRN checks before deactivate/obsolete; GL/Tax existence validated against external masters before Activate. These require cross-system queries; DB cannot enforce alone.    
\- Sequence/Trigger template (per table):  
  \- CREATE SEQUENCE IF NOT EXISTS seq\_\<table\>\_public\_id;  
  \- CREATE OR REPLACE FUNCTION fn\_\<table\>\_make\_public\_id() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.id IS NULL OR NEW.id \= '' THEN NEW.id := '\<PREFIX\>-' || lpad(nextval('seq\_\<table\>\_public\_id')::text, 10, '0'); END IF; RETURN NEW; END; $$;    
  \- CREATE TRIGGER trg\_\<table\>\_public\_id BEFORE INSERT ON \<table\> FOR EACH ROW EXECUTE FUNCTION fn\_\<table\>\_make\_public\_id();  
\- Concurrency & optimistic locking: use version \+ updated\_at \+ ETag layer; application must increment version on update and check If-Match.

\#\# 10.3 พจนานุกรมข้อมูล (Field Dictionary แบบเต็ม)  
(ตัวอย่างรวบรัด: ตาราง products และ product\_vendors ตัวอย่างฟิลด์สำคัญ; ตารางอื่นมีรูปแบบคล้ายกันตามสคีมา)

\- ตาราง: products  
  \- row\_id: uuid; \-; NOT NULL; gen\_random\_uuid(); internal PK; ตัวอย่าง: "3f1b9a1e-8c4d-4a2f-9c3a-1f2b3c4d5e6f"; PII: no  
  \- id: varchar(14); length 14; NOT NULL; trigger; CHECK '^PRD-\\d{10}$'; public id; ตัวอย่าง: "PRD-0000000001"; PII: no  
  \- code: varchar(32); length 32; NOT NULL; \-; business code; ตัวอย่าง: "PROD-0002"; PII: no; Note: immutable when status='Active'  
  \- name: varchar(200); length 200; NOT NULL; \-; display name; ตัวอย่าง: "สารเคมีทดสอบ"; PII: no  
  \- type: text; \-; NOT NULL; 'Stock'; enum; e.g., "Stock"; PII: no  
  \- category\_row\_id: uuid; \-; NULLABLE; NULL; FK → categories.row\_id; ตัวอย่าง: 9a7b...; PII: no  
  \- base\_uom: varchar(32); length 32; NOT NULL; \-; เช่น "PCS","L"; PII: no  
  \- tracking: text; \-; NOT NULL; 'None'; enum; e.g., "Lot"; PII: no  
  \- gl\_inventory\_acct\_id: varchar(64); length 64; YES; NULL; account code string; ตัวอย่าง: "1100"; PII: mask for non-Finance in API  
  \- standard\_cost: decimal(18,4); precision 18 scale 4; YES; NULL; monetary; ตัวอย่าง: 12.3456; PII: no  
  \- hazardous: boolean; \-; NOT NULL; false; \-; ตัวอย่าง: false; PII: no  
  \- shelf\_life\_days: integer; \-; YES; NULL; \>=0; ตัวอย่าง: 365; PII: no  
  \- created\_at / updated\_at: timestamptz; NOT NULL; now(); ตัวอย่าง: "2025-11-05T08:30:00Z"; PII: no  
  \- version: integer; NOT NULL; 1; \>0; ตัวอย่าง: 1; PII: no

\- ตาราง: product\_vendors  
  \- row\_id: uuid; PK; gen\_random\_uuid(); ตัวอย่าง: b2c3...  
  \- id: varchar(14); CHECK '^PVN-\\d{10}$'; ตัวอย่าง: PVN-0000000001  
  \- product\_row\_id: uuid; FK → products.row\_id; ตัวอย่าง: 3f1b...  
  \- vendor\_id: varchar(64); length 64; NOT NULL; external vendor id; ตัวอย่าง: VND-01; PII: vendor identifiers not PII  
  \- vendor\_sku: varchar(64); length 64; NULLABLE; ตัวอย่าง: SKU-123  
  \- preferred: boolean; NOT NULL; false; ตัวอย่าง: true  
  \- price\_hint: decimal(18,4); precision 18 scale 4; NULLABLE; ตัวอย่าง: 12.3456  
  \- currency: varchar(8); length 8; NULLABLE; ตัวอย่าง: THB

(ตารางอื่น ๆ อ้างจากสคีมา ข้อมูลตัวอย่างในส่วน 10.0.2)

PII / Masking:    
\- PII ชัดเจน: national\_id, tax\_id, email, phone — ไม่มีฟิลด์เหล่านี้ใน schema นี้.    
\- Sensitive: gl\_inventory\_acct\_id / gl\_expense\_acct\_id / tax\_code\_id — ต้องถูก masked ใน API responses สำหรับผู้ใช้ที่ไม่ใช่ Finance (masking applied at API layer based on RBAC).

\#\# 10.4 Enums & Patterns  
\- status: TEXT \+ CHECK IN ('Draft','In Review','Approved','Active','Inactive','Obsolete')    
\- type: TEXT \+ CHECK IN ('Stock','NonStock','Service')    
\- tracking: TEXT \+ CHECK IN ('None','Lot','Serial')    
\- cost\_method: TEXT \+ CHECK IN ('Standard','MovingAvg')    
\- symbology: TEXT \+ CHECK IN ('EAN13','UPC','QR','Code128')    
\- doc\_type: TEXT \+ CHECK IN ('Spec','MSDS','Cert','Other')    
\- Public ID regex per table:  
  \- products: ^PRD-\\d{10}$    
  \- product\_uom\_convs: ^PUC-\\d{10}$    
  \- product\_vendors: ^PVN-\\d{10}$    
  \- product\_barcodes: ^PBC-\\d{10}$    
  \- product\_images: ^PIM-\\d{10}$    
  \- product\_docs: ^PDC-\\d{10}$    
  \- categories: ^CAT-\\d{10}$    
  \- product\_audits: ^PAD-\\d{10}$    
\- Field patterns:  
  \- code: ^.{1,32}$ (max length 32\)    
  \- barcode.value: max 64 chars; additional pattern validations (EAN13 numeric length 13\) performed at application level per symbology.

\#\# 10.5 Conflict Log & Candidate Fields  
\- Conflict: API examples show numeric/simple ids ("1002","2001") without prefixes. Decision: follow Canonical short-id policy and use prefixed IDs (PRD-, PBC-, etc.). Documented mapping: service accepts legacy numeric id in API but resolves to \`row\_id\` (see mapping below). Rationale: canonical short-id required.    
\- Conflict: API returns \`preferred\_vendor\` field in product list item (single id). We DO NOT persist duplicate preferred\_vendor on products table; instead compute at read-time from product\_vendors where preferred=true per currency. Rationale: avoid duplicated business facts.    
\- Candidate fields from API (not in Canonical): API list response includes \`preferred\_vendor\` top-level; handled as computed field (candidate for materialized view). Logged here.    
\- Assumptions made due to missing/ambiguous inputs:  
  \- digits\_len default \= 10 for all public IDs (consistent across tables).    
  \- vendor master / GL master / Tax master are external systems; DB stores external id strings (varchar) and integration validates existence. Rationale: do not create cross-system FK in DB.    
  \- UOM conversion acyclicity enforced by application/service (not DB). Rationale: cycle detection across graph is complex in DB; trigger would be expensive.    
  \- Audit table added (product\_audits) though not listed in Entities; required by API / Status Model audit requirement.    
  \- product.code immutability after Active enforced via DB trigger to prevent accidental changes.    
\- API↔DB representation mapping differences:  
  \- API public id may be given as legacy numeric (e.g., "1002") — service accepts it and treats it as legacy id mapping to \`row\_id\`; canonical DB uses prefixed public id (PRD-...). Mapping must be enforced in service layer.    
  \- API uses snake/lowercase names (product\_barcode). DB uses singular tables; mapping layer translates arrays to child table operations.    
  \- FK accepted at API: either public id (PREFIX-...) or row\_id (UUID). Service resolves to row\_id for FK operations. Documented as compatibility.

\#\# 10.6 Data Lineage & Integration Notes  
\- External masters & validations:  
  \- Vendor master: product\_vendors.vendor\_id validated by Vendor service (source of truth). Stored as external id in product\_vendors.vendor\_id. No DB FK.    
  \- GL master: gl\_inventory\_acct\_id / gl\_expense\_acct\_id validated by Finance system on submit/approve/activate. Stored as text. Masked in API for non-Finance.    
  \- Tax master: tax\_code\_id validated by Tax service. Stored as text.    
\- Single source decisions:  
  \- Product master data authoritative in this service for product attributes (code, name, type, UOM, tracking, hazardous, shelf\_life). Preferred vendor list stored here (single source of truth for product→vendor links).    
  \- Inventory on-hand, PR/PO/GRN references are maintained by downstream systems (WMS/Procurement/GRN). Before deactivate/obsolete, service queries those systems (no duplication of on-hand in products table).    
\- Views/Materialized Views:  
  \- Recommend read-view to expose computed \`preferred\_vendor\` per product (materialized for performance).    
  \- Search view combining code/name/barcodes for q search to support API list filter \`q\`.    
\- Events:  
  \- Emit product.created, product.submitted, product.approved, product.activated, product.deactivated, product.obsoleted, product.updated with payload { id (public), row\_id, actor, timestamp, snapshot\_id }. Consumers: PR/PO/GRN, Inventory, Search index.    
\- Audit:  
  \- All state transitions and critical-field edits must create an entry in product\_audits (actor, role, action, reason, diff). This is authoritative audit log for product lifecycle.

\-- End of Data Schema document.

\# 11\. Business Rules

\#\#\# 11.1 Rules Inventory (merged)  
| Rule ID | Type (validation/domain) | Context (entity/endpoint) | State/Trigger | Condition | Expected | Error Code | Ref(A5/A6/A3) | Notes |  
|---|---|---|---|---|---|---|---|---|  
| R1 | validation | POST \`/erp/master/products\` | Create → Draft | code duplicate exists | reject | 409\_CONFLICT | A6 §10.0.2; A5 §8.2 | UNIQUE \`uq\_products\_code\` enforced |  
| R2 | domain | PATCH \`/erp/master/products/{id}\` | Update (Active) | code change when status='Active' | reject | 409\_CONFLICT | A6 §10.0.2; A3 §5.2 | immutable code trigger on DB |  
| R3 | validation | POST \`/erp/master/products\` | Create → Draft | supplied id not match \`^PRD-\\d{10}$\` | reject | 400\_VALIDATION\_FAILED | A6 §10.4; A5 §9.1 | public id regex \`^PRD-\\d{10}$\` |  
| R4 | validation | POST \`/erp/master/products/{id}:submit\` | Draft→In Review | missing base\_uom or no primary barcode | reject | 422\_INVALID\_STATE | A3 §5.2; A5 §8.5 | submit requires base\_uom \+ primary barcode |  
| R5 | validation | product\_barcodes insert | any write | duplicate (symbology,value) exists | reject | 409\_CONFLICT | A6 §10.0.2; A5 §9.2 | UK \`uq\_product\_barcodes\_symbology\_value\` |  
| R6 | validation | product\_uom\_convs insert/update | any write | factor \<= 0 or wrong precision | reject | 400\_VALIDATION\_FAILED | A6 §10.0.2; A5 §9.6 | factor decimal(18,6) and \>0 |  
| R7 | validation | product\_uom\_convs insert/update | any write | conversion graph cyclic (application) | reject | 400\_VALIDATION\_FAILED | A6 §10.0.2; A3 §5.2.1 | acyclic enforced at service layer |  
| R8 | domain | POST \`/erp/master/products/{id}:approve\` | In Review→Approved | gl or tax id not found in masters | reject | 404\_NOT\_FOUND | A5 §9.6; A6 §10.6 | external FK validation required |  
| R9 | domain | POST \`/erp/master/products/{id}:activate\` | Approved→Active | open PR/PO/GRN exist | reject | 409\_CONFLICT | A3 §5.2; A5 §8.8 | business guard: query downstream systems |  
| R10 | domain | POST \`/erp/master/products/{id}:obsolete\` | Active/Inactive→Obsolete | on\_hand \> 0 OR open docs exist | reject | 409\_CONFLICT | A3 §5.2; A5 §8.10 | irreversible; final guard |  
| R11 | validation | product\_vendors insert/update | vendor rows change | preferred duplicate per product+currency | reject | 409\_CONFLICT | A6 §10.0.2; A5 §9.6 | UNIQUE PARTIAL index enforced |  
| R12 | validation | PATCH \`/erp/master/products/{id}\` | Update | If-Match missing or ETag mismatch | reject | 412\_PRECONDITION\_FAILED | A5 §8.4; A3 §5.2.2 | optimistic concurrency check |  
| R13 | validation | POST \`/erp/master/products\` | Create | X-Idempotency-Key duplicate request | accept | — | A5 §8.2; A5 §9.4 | idempotent create via X-Idempotency-Key |  
| R14 | validation | GET \`/erp/master/products\` | List | invalid filter shape (updated\_from not ISO-8601) | reject | 400\_VALIDATION\_FAILED | A5 §8.1; A5 §9.2 | query params validated server-side |  
| R15 | domain | any state-change endpoint | state-change | action attempted by unauthorized role | reject | 403\_FORBIDDEN | A3 §5.2; A5 §9.1 | RBAC enforced per role/DOA |  
| R16 | domain | PATCH \`/erp/master/products/{id}\` | Active critical-field edit | changing critical field → requires revision/submit | reject | 409\_CONFLICT | A3 §5.2; A6 §10.2 | critical fields trigger re-approval flow |  
| R17 | validation | POST \`/erp/master/products/import\` | Import commit | missing required columns / parse fail | reject | 400\_VALIDATION\_FAILED | A5 §8.12; A5 §9.2 | preview/commit validation applies |  
| R18 | validation | numeric fields (standard\_cost, price\_hint) | any write | precision/scale exceeded | reject | 400\_VALIDATION\_FAILED | A6 §10.6; A5 §9.6 | decimals: money/price rules apply |  
| R19 | domain | GET \`/erp/master/products/{id}\` | Detail | product not found OR deleted\_at set (soft) | reject | 404\_NOT\_FOUND | A6 §10.0.2; A5 §8.3 | default hides soft-deleted rows |  
| R20 | domain | POST \`/erp/master/products/{id}:deactivate\` | Active→Inactive | open PR/PO/GRN exist and override=false | reject | 409\_CONFLICT | A3 §5.2; A5 §8.9 | controller override flag exceptional |

\#\#\# 11.2 State→Action Guard Matrix (compact)  
State | Allowed | Blocked | Preconditions | Error Code  
\---|---|---|---|---  
Draft | create\<br\>update\<br\>submit | approve\<br\>activate | code/name/base\_uom present\<br\>primary barcode present | 400\_VALIDATION\_FAILED / 422\_INVALID\_STATE  
In Review | approve\<br\>reject | submit\<br\>activate | approver role per DOA\<br\>If-Match recommended | 403\_FORBIDDEN / 412\_PRECONDITION\_FAILED  
Approved | activate\<br\>edit (non-critical) | approve\<br\>submit | GL/Tax valid\<br\>no open refs for activate | 404\_NOT\_FOUND / 409\_CONFLICT  
Active | deactivate\<br\>edit (non-critical)\<br\>revision submit | submit→In Review (direct) blocked | no open PR/PO/GRN for deactivate\<br\>critical-field edits require revision | 409\_CONFLICT / 400\_VALIDATION\_FAILED  
Inactive | reactivate (activate) | deactivate (again) | no open refs for obsolete | 409\_CONFLICT  
Obsolete | none (terminal) | any state-change | irreversible; on\_hand==0 AND no open docs | 409\_CONFLICT  
Any editable state | update (PATCH) | update without If-Match | If-Match required for PATCH/state-change | 412\_PRECONDITION\_FAILED

\#\#\# 11.3 Soft-Delete & Retention (concise)  
\- Default list/detail visibility: exclude rows where \`deleted\_at\` IS NOT NULL; status='Obsolete' shown only when explicitly filtered.    
\- Restore behavior: restore allowed if not purged; client must supply \`If-Match\` and may use \`X-Idempotency-Key\`; restore sets status back to prior non-terminal state.    
\- \[Default\] หากเอกสารเงียบเกี่ยวกับ retention → exclude by default; restorable if not purged (no numeric retention invented).

\#\#\# 11.4 Compensation & Recovery (P0 only)  
Scenario | Preconditions | Action | Resulting State/Data | Idempotency/ETag | Observability  
\---|---|---|---|---|---  
Approve fails due external GL/Taх | Approver invoked\<br\>GL/TAX service unavailable | rollback approve\<br\>return error | status remains In Review | X-Idempotency-Key recommended | audit entry with failure reason  
ETag mismatch on PATCH/action | Client If-Match stale | return 412\_PRECONDITION\_FAILED | no state change | client must retry with fresh ETag | no audit write for failed attempt  
Duplicate POST create retry | Same X-Idempotency-Key resent | dedupe and return original resource | single Draft created / same id | X-Idempotency-Key used to dedupe | audit: single create entry  
Bulk action partial failures | bulk request with multiple ids | apply per-id commit; return per-id results | some success / some failed | X-Idempotency-Key for whole bulk | bulk results in response; audits per id  
Event/webhook delivery failure | outbound event delivery fails | retry with backoff; DLQ on repeated failure | product state unchanged | idempotent event payloads recommended | event publish logs and DLQ alerts

\#\#\# 11.5 Findings & Follow-ups  
\- API examples use numeric ids (e.g., "1002") but A6 mandates prefixed ids (\`PRD-...\`) — Owner: API/Integration; Ref: A6 §10.0.2 / A5 §8.2    
\- Validation code name mismatch: spec uses \`400\_VALIDATION\_FAILED\` but normalization referenced \`VALIDATION\_ERROR\` — Owner: API team; Ref: A5 §9.2    
\- \`INVALID\_QUERY\` code referenced in rules normalization is not present in A5 error list — Owner: API team; Ref: A5 §9.2    
\- Obsolete final-authority role not specified (who can \`obsolete\`) — Owner: Product Governance; Ref: A3 §5.2 Warnings    
\- Controller override semantics (role/flag/param) undefined — Owner: Security/Policy; Ref: A3 §5.2 Warnings    
\- Webhook/event payload schemas not defined for product.\* events — Owner: Integration; Ref: A5 §9.6 / A3 §5.2 Warnings    
\- UOM acyclic enforcement delegated to service (DB cannot enforce) — Owner: Platform/Dev; Ref: A6 §10.0.2 / A3 §5.2.3    
\- Restore endpoint and purge retention period not specified → default applied (restorable if not purged) — Owner: Data Retention; Ref: A6 §10.0.2 / A5 §8.x

