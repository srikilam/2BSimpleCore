--think-hard
Phase: 04 QA & Validation  
Agent Role: Claude QA Agent  
System: ERP Backend (Golang + PostgreSQL, Clean Architecture)

FEATURE_NAME: Product Management
FEATURE_CODE: PROD001
MODULE: Inventory

Feature: {{FEATURE_NAME}}  
Feature Code: {{FEATURE_CODE}}  
Module: {{MODULE}}  

🧠 Input Artifacts
- Feature Card: projects/erp/features/FC-{{FEATURE_CODE}}-{{FEATURE_NAME}}.json
- SQL Schema: projects/erp/backend/go_api/migrations/{{DATE}}_create_{{FEATURE_CODE}}_schema.sql
- API Spec: projects/erp/docs/api/{{FEATURE_CODE}}-{{MODULE}}-openapi.yaml
- ERD: projects/erp/docs/erd/{{FEATURE_CODE}}-{{MODULE}}.mmd
- Go Source: projects/erp/backend/go_api/internal/**/*
- Manifest: projects/erp/manifest/{{FEATURE_CODE}}.json

---

## 🎯 Goal  
ตรวจสอบคุณภาพโค้ด Backend ทั้งหมดของ Feature นี้  
เพื่อยืนยันว่า Schema, Logic, API, และ Test มีความถูกต้อง สอดคล้องกับมาตรฐาน 2BSimpleCore  
และพร้อมสำหรับการปล่อยใช้งาน (Phase 05 - Log & Learn)

---

## 🧩 Tasks  

### 1️⃣ ตรวจ Schema Consistency  
- ตรวจสอบว่า field name / type ใน SQL Schema → Model → API Response ตรงกัน  
- ตรวจสอบ FK, constraint, และ data type ตาม ERD  
- ตรวจสอบว่า soft delete (`deleted_at`) และ timestamp fields (`created_at`, `updated_at`) ถูกต้อง  

### 2️⃣ ตรวจ Naming Convention  
- ตรวจตาม `core/conventions/naming-rules.md`  
  - table, column → `snake_case`  
  - struct, function → `PascalCase`  
  - variable, receiver → `camelCase`  

### 3️⃣ ตรวจ Logic & Error Handling  
- ตรวจ CRUD flow ว่าทำงานครบ (Create, Read, Update, Delete)  
- ตรวจ validation logic (เช่น input required, duplicate check)  
- ตรวจ error handling ว่าใช้ `fmt.Errorf("context: %w", err)` หรือ log ที่เหมาะสม  

### 4️⃣ ตรวจ API Consistency  
- ตรวจว่าทุก path ใน OpenAPI มี handler ในโค้ดจริง  
- ตรวจ HTTP method และ response code ถูกต้องตาม spec  
- ตรวจชื่อ field ใน JSON response ตรงกับ model  

### 5️⃣ ตรวจ Test Coverage  
- วิเคราะห์ผลจากคำสั่ง `go test ./internal/... -cover`  
- ต้องมี coverage ≥ 80%  
- แสดงตาราง coverage per package เช่น models, services, handlers  

### 6️⃣ ตรวจ Manifest Completeness  
- ตรวจว่า manifest ของ feature มี output ครบทุกไฟล์หลัก  
  (`models`, `repositories`, `services`, `handlers`, `routes`, `tests`)  
- ตรวจว่า `phase` ปัจจุบันคือ `"build_completed"`  
- ตรวจว่า field `"qa_status"` ยังเป็น `"pending"` ก่อนเริ่มตรวจ  

### 7️⃣ สร้างรายงาน QA  
บันทึกผลตรวจลงไฟล์:  
`projects/erp/logbook/sprint-{{SPRINT}}/feature-{{FEATURE_CODE}}-qa.md`  

รูปแบบรายงาน:
🧪 QA Report — Feature: {{FEATURE_NAME}} ({{FEATURE_CODE}})

Module: {{MODULE}}
Sprint: {{SPRINT}}
Reviewed by: Claude QA Agent

✅ Summary

(สรุปผลการตรวจทั้งหมด 2–3 บรรทัด)

🧱 Schema Check

(รายงานผลตรวจตาราง, field mismatch, missing FK)

⚙️ Logic & API Check

(รายงานจุดผิดพลาดใน service, handler, route, status code)

🧩 Test Result

(สรุป coverage table เช่น:)
| Package  | Coverage |
| -------- | -------- |
| models   | 100%     |
| services | 85%      |
| handlers | 78%      |


### 8️⃣ อัปเดต Manifest
หากผ่าน QA ให้แก้ไขไฟล์ manifest:  
`projects/erp/manifest/{{FEATURE_CODE}}.json`


{
  "feature": "{{FEATURE_CODE}}",
  "phase": "qa_completed",
  "checked_at": "<ISO8601 timestamp>",
  "qa_status": "passed",
  "qa_report": "projects/erp/logbook/sprint-{{SPRINT}}/feature-{{FEATURE_CODE}}-qa.md"
}

📘 Reference Standards
 - Naming: core/conventions/naming-rules.md
 - Database: core/conventions/db-schema-standards.md
 - Coding Style: core/conventions/coding-style.md
 - API: core/conventions/api-guidelines.md

🧾 Output Format
 - ให้ตอบเฉพาะ QA Report (Markdown) และ Manifest JSON ที่อัปเดตแล้วเท่านั้น
 - ห้ามมีคำอธิบายอื่นนอกเหนือจากนี้

