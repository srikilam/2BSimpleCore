--think-hard
Phase: 07 Enhance & Optimize  
Agent Role: Claude Backend / Architect Agent  
System: ERP Backend (Golang + PostgreSQL, Clean Architecture)

Feature: {{FEATURE_NAME}}  
Feature Code: {{FEATURE_CODE}}  
Module: {{MODULE}}  
Base Import Path: {{BASE_IMPORT}}

---

## 🎯 Goal
ปรับปรุงประสิทธิภาพ / เพิ่ม feature ย่อย / refactor code ของ feature ที่มีอยู่  
ให้มีความเร็ว เสถียร และอ่านง่าย โดยไม่เปลี่ยน behavior เดิม  

---

## 🧩 Tasks
1. วิเคราะห์ bottleneck หรือ โค้ดที่ซ้ำซ้อนจาก Phase 06 หรือ QA Report  
2. ปรับปรุง query / algorithm / structure เพื่อให้ performance ดีขึ้น  
3. แยก function / service ให้ modular และ testable  
4. ปรับโค้ดให้ตรงกับ coding-style.md และ api-guidelines.md  
5. เพิ่ม unit test กรณีใหม่หรือ edge case ที่ยังไม่ครอบคลุม  
6. อัปเดต manifest:  
   - `"phase": "enhance_completed"`  
   - `"enhancement_notes"`  
7. บันทึกผลลง logbook ใน `projects/erp/logbook/sprint-{{SPRINT}}/feature-{{FEATURE_CODE}}-enhance.md`

---

## ⚙️ Input Artifacts
- Feature Card → `projects/erp/features/FC-{{FEATURE_CODE}}-{{FEATURE_NAME}}.json`
- Manifest → `projects/erp/manifest/{{FEATURE_CODE}}.json`
- Source Code → `projects/erp/backend/go_api/internal/**/*`
- QA Report / Fix Report จาก Phase 06

---

## 🧾 Output Files
1. Updated .go files พร้อม comment ระบุ refactor หรือ optimization  
2. Updated tests (เพิ่มกรณีใหม่)  
3. Updated manifest (phase + enhancement_notes)  
4. Logbook entry (รายละเอียดสิ่งที่ปรับปรุง)

---

## 🧱 Review Comment Format
```go
/*
REVIEW COMMENT START
Reviewer: {{REVIEWER}}
Date: {{DATE}}
Enhancement: (อธิบายสิ่งที่ปรับปรุง)
Result: (ผลลัพธ์ที่ดีขึ้น)
REVIEW COMMENT END
*/
