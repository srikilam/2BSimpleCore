--think-hard
Phase: 06 Fix & Patch  
Agent Role: Claude Backend Agent  
System: ERP Backend (Golang + PostgreSQL, Clean Architecture)

Feature: {{FEATURE_NAME}}  
Feature Code: {{FEATURE_CODE}}  
Module: {{MODULE}}  
Base Import Path: {{BASE_IMPORT}}  

---

## 🎯 Goal  
ตรวจสอบและแก้ไขปัญหาที่รายงานใน Logbook หรือ Manifest ของ Feature นี้  
โดยไม่กระทบโครงสร้าง Clean Architecture เดิม  
และอัปเดต Manifest ให้ตรงกับสถานะล่าสุดหลังการแก้ไข

---

## 🧩 Tasks  
1. วิเคราะห์สาเหตุของปัญหา (Root Cause) จากโค้ดใน layer ที่เกี่ยวข้อง (Handler / Service / Repository)  
2. แก้ไข bug หรือ logic ที่ผิด  
3. เพิ่ม validation / error handling ถ้าจำเป็น  
4. อัปเดต unit test / integration test ที่เกี่ยวข้อง  
5. เพิ่ม review comment block อธิบายจุดที่แก้ไขในโค้ด  
6. อัปเดต Manifest:  
   - `"phase": "fix_completed"`  
   - `"qa_status": "pending"`  
   - เพิ่ม `"fix_notes"`  
7. เพิ่มบันทึกใน Logbook Sprint:  
   - Feature  
   - วันที่  
   - ปัญหา  
   - วิธีแก้  
   - Reviewer  

---

## ⚙️ Input Files  
- Feature Card: `projects/erp/features/FC-{{FEATURE_CODE}}-{{FEATURE_NAME}}.json`  
- Manifest: `projects/erp/manifest/{{FEATURE_CODE}}.json`  
- Source Code: `projects/erp/backend/go_api/internal/**/*`  
- QA Report (เดิม): `projects/erp/logbook/sprint-{{SPRINT}}/feature-{{FEATURE_CODE}}-qa.md`

---

## 🧾 Output Files  
1. Updated source code (.go) พร้อม review comment block  
2. Updated test files (.go)  
3. Updated manifest JSON (phase, qa_status, fix_notes)  
4. Logbook entry ใน `projects/erp/logbook/sprint-{{SPRINT}}/feature-{{FEATURE_CODE}}-issues.md`

---

## 🧱 Review Comment Format
ในโค้ดทุกจุดที่แก้ ให้เพิ่ม block ดังนี้:
```go
/*
REVIEW COMMENT START
Reviewer: {{REVIEWER}}
Date: {{DATE}}
Comment: (สรุปสาเหตุของ bug)
Fix: (อธิบายสิ่งที่แก้ไข)
REVIEW COMMENT END
*/
