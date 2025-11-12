--think-hard
Phase: 08 Retest & Validate  
Agent Role: Claude QA Agent  
System: ERP Backend (Golang + PostgreSQL, Clean Architecture)

Feature: {{FEATURE_NAME}}  
Feature Code: {{FEATURE_CODE}}  
Module: {{MODULE}}

---

## 🎯 Goal
ทำ Regression Test และ Integration Test กับ feature ที่เพิ่ง fix หรือ enhance  
เพื่อยืนยันว่า ไม่มี side effect และ feature ยังคงทำงานถูกต้องครบทุก criteria  

---

## 🧩 Tasks
1. อ่าน QA Report และ Fix / Enhance Log จาก Phase 06–07  
2. รัน unit test และ integration test ของ feature นี้  
3. ตรวจสอบ schema / API / logic ให้ consistent กับ Feature Card  
4. ตรวจสอบ linked features (ถ้ามี) ว่าทำงานร่วมกันได้  
5. สรุป ผล retest เป็น QA Report ใหม่ (Regression Mode)  
6. อัปเดต manifest:  
   - `"phase": "qa_retest_completed"`  
   - `"qa_status": "passed"` หรือ `"failed"`  
7. ถ้า failed → สร้าง entry ใหม่ใน Phase 06 (Fix & Patch)  

---

## ⚙️ Input Artifacts
- QA Report ก่อนหน้า → `projects/erp/logbook/sprint-{{SPRINT}}/feature-{{FEATURE_CODE}}-qa.md`
- Manifest → `projects/erp/manifest/{{FEATURE_CODE}}.json`
- Source Code → `projects/erp/backend/go_api/internal/**/*`
- Test Logs จาก `go test ./internal/... -cover`

---

## 🧾 Output Files
1. QA Report ใหม่: `projects/erp/logbook/sprint-{{SPRINT}}/feature-{{FEATURE_CODE}}-retest.md`  
2. Updated manifest พร้อมผล retest  

---

## 🧱 QA Report Format
```markdown
# 🧪 Regression QA Report — Feature: {{FEATURE_NAME}} ({{FEATURE_CODE}})
Module: {{MODULE}}
Date: {{DATE}}
Reviewed by: Claude QA Agent

## ✅ Summary
(สรุปว่าทดสอบอะไร และ ผลลัพธ์รวม)

## 🧩 Retest Cases
| Case | Expected | Actual | Status |
|------|-----------|--------|--------|
| CreateProduct | 201 Created | 201 Created | ✅ |
| UpdateProduct (price = 0) | 400 Bad Request | 400 Bad Request | ✅ |
| ListProducts | 200 OK | 200 OK | ✅ |

## ⚙️ Integration Test
✅ Linked module PO001 returns expected inventory update.

## 🚦 Overall Result
**PASSED**