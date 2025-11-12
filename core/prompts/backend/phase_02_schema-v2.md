--think-hard
Phase: 02 Design & Schema
Agent Role: Claude Architect Agent
System: ERP Backend (Golang + PostgreSQL)

# Feature context (replace variables before sending)
FEATURE_NAME: Area Permission
FEATURE_CODE: ARPE001
MODULE: AGM
DATE: {{DATE}}            # e.g. 2025-11-11
SPRINT: {{SPRINT}}        # optional

Feature: {{FEATURE_NAME}}
Feature Code: {{FEATURE_CODE}}
Module: {{MODULE}}
Input: Feature Card → projects/erp/features/FC-{{FEATURE_CODE}}-{{FEATURE_NAME}}.json

---

## 🎯 Goal
อ่านข้อมูลจาก Feature Card (Phase 01) แล้วออกแบบ:
1. โครงสร้างฐานข้อมูล (Database Schema / SQL)
2. ERD Diagram (Mermaid)
3. OpenAPI 3.0 Spec (YAML)
4. **Postman Collection (v2.1) JSON** พร้อมตัวอย่าง request และ sample body/response ที่ frontend สามารถนำไปใช้งานได้ทันที

ผลลัพธ์ต้องสามารถนำไปใช้ใน Phase 03 (Build & Integrate) และให้ frontend เริ่มพัฒนา/ทดสอบได้จาก Postman collection โดยตรง

---

## 🧩 Tasks
1. อ่าน Feature Card JSON ที่แนบด้านล่าง (projects/erp/features/FC-{{FEATURE_CODE}}-{{FEATURE_NAME}}.json)
2. ระบุ `data_entity` และความสัมพันธ์ (linked_features) จาก Feature Card
3. สร้าง ERD Diagram (Mermaid format) สำหรับทุก entity ที่เกี่ยวข้อง
4. เขียน SQL Schema (PostgreSQL compatible) สำหรับสร้างตาราง, PK, FK, index, constraints
   - บังคับฟิลด์มาตรฐาน: `id`, `created_at`, `updated_at`, `deleted_at`
   - ใช้ `SERIAL`/`BIGSERIAL` ตามความเหมาะสม
   - ไว้จุดที่ต้องการ `CHECK` constraint หรือ `UNIQUE` index
5. สร้าง OpenAPI Spec (YAML, OpenAPI 3.0.3) สำหรับ CRUD และ Search/Filter (ถ้ามี)
   - เพิ่มตัวอย่าง `requestBody` และ `responses` (200 / 201 / 400 / 404 / 500)
   - ระบุ security scheme (Bearer Auth) หากเป็น endpoint ที่ต้องการ auth
6. **สร้าง Postman Collection (v2.1) JSON** ที่ประกอบด้วย:
   - Folder group `/api/v1/{{module_lower}}/{{entity_plural}}` หรือ `/api/v1/{{module_lower}}`
   - Requests สำหรับ: List (GET), GetByID (GET /{id}), Create (POST), Update (PATCH), Delete (DELETE), Search (GET /search) ถ้าจำเป็น
   - ทุก request ต้องมี:
     - URL placeholder: `{{base_url}}/api/v1/<path>` (ให้ใช้ variable `base_url`)
     - Authorization: Bearer token placeholder (`{{auth_token}}`) ถ้า endpoint ต้อง auth
     - Headers: `Content-Type: application/json`
     - Example request body (JSON) for POST / PATCH
     - Example success response body (JSON)
   - Include `README` style description at collection level with quick-start usage for frontend
7. ตรวจ naming & conventions ตาม `core/conventions/*`:
   - `db-schema-standards.md`, `naming-rules.md`, `api-guidelines.md`, `coding-style.md`
8. บันทึกผลในไฟล์ตาม convention:
   - ERD: `projects/erp/docs/erd/{{FEATURE_CODE}}-{{MODULE}}.mmd`
   - SQL: `projects/erp/backend/go_api/migrations/{{DATE}}_create_{{FEATURE_CODE}}_schema.sql`
   - OpenAPI: `projects/erp/docs/api/{{FEATURE_CODE}}-{{MODULE}}-openapi.yaml`
   - Postman collection: `projects/erp/docs/postman/{{FEATURE_CODE}}-{{MODULE}}-postman.json`

---

## 🧾 Output Format (only these sections — NO extra text)
> ให้ตอบเฉพาะ 4 ส่วนเท่านั้น (เรียงตามนี้): ERD / SQL Schema / OpenAPI Spec / Postman Collection JSON  
> แต่ละส่วนต้องอยู่ใน fenced code block และเริ่มด้วย comment ที่ระบุ PATH TARGET ตามตัวอย่าง

**Order & exact headers required:**

Important rules:
 - ห้ามใส่คำอธิบายเพิ่มเติมนอกเหนือจาก code blocks ที่กำหนดข้างต้น
 - ทุกชื่อ table/column/route ต้องเป็นไปตาม naming-rules.md (snake_case สำหรับ DB, plural for routes)
 - ใช้ /api/v1/<module_lower>/<entity_plural> เป็น pattern ของ routes (module_lower = lowercased module name)
 - Postman collection ต้องเป็น Postman v2.1 compatible JSON และมีตัวแปร base_url และ auth_token
 - OpenAPI ตัวอย่าง response ต้องสอดคล้องกับ sample bodies ใน Postman

 📘 Reference Standards:
  - Follow `db-schema-standards.md`
  - Follow `api-guidelines.md`
  - Follow `naming-rules.md`