### Phase 01 sample
  --think-hard
  Phase: 01 Define & Analyze  
  Agent Role: Claude Architect Agent  
  System: ERP Backend (Golang)  

  FEATURE_NAME: Product Management
  FEATURE_CODE: PROD001
  MODULE: Inventory
  FRD_PATH: projects/erp/docs/frd/FRD-Product-Management.md

  Feature: {{FEATURE_NAME}}  
  Feature Code: {{FEATURE_CODE}}  
  Module: {{MODULE}}  
  FRD Path: {{FRD_PATH}}  

  ---

  ## 🎯 Goal  
  อ่านและวิเคราะห์เอกสาร FRD เพื่อสกัด Business Logic, Entity, Flow ของระบบ  
  จากนั้นสร้าง **Feature Card (JSON)** ที่ใช้เป็น input ใน Phase ถัดไป (Design & Schema)

  ---

  ## 🧩 Tasks  
  1. อ่านและสรุป **Business Context** จาก FRD  
  2. สร้าง **User Stories** ตามมุมมองของผู้ใช้จริง  
  3. ระบุ **Acceptance Criteria** สำหรับแต่ละ story  
  4. แยก **Data Entities** และความสัมพันธ์หลัก  
  5. ระบุ **API Endpoints** ที่ต้องใช้ในระบบ  
  6. เชื่อมโยง Feature อื่น ๆ (linked_features)  
  7. สร้างไฟล์ Feature Card:  
    `projects/erp/features/FC-{{FEATURE_CODE}}-{{FEATURE_NAME}}.json`

  ---

  ## 🧾 Output Format (JSON only)
    ```json
      {
        "feature_code": "{{FEATURE_CODE}}",
        "feature_name": "{{FEATURE_NAME}}",
        "module": "{{MODULE}}",
        "business_context": "...",
        "user_story": ["..."],
        "acceptance_criteria": ["..."],
        "data_entities": ["..."],
        "api_endpoints": ["..."],
        "linked_features": [],
        "dev_status": "in_progress",
        "assigned_to": "{{DEV_ID}}",
        "reviewer": "{{REVIEWER}}"
      }

---


### Phase 02 sample

--think-hard
Phase: 02 Design & Schema  
Agent Role: Claude Architect Agent  
System: ERP Backend (Golang + PostgreSQL)

FEATURE_NAME: Product Management
FEATURE_CODE: PROD001
MODULE: Inventory

Feature: {{FEATURE_NAME}}  
Feature Code: {{FEATURE_CODE}}  
Module: {{MODULE}}  
Input: Feature Card → projects/erp/features/FC-{{FEATURE_CODE}}-{{FEATURE_NAME}}.json  

---

## 🎯 Goal  
อ่านข้อมูลจาก Feature Card (ที่ได้จาก Phase 01)  
เพื่อออกแบบ **โครงสร้างฐานข้อมูล (Database Schema)**, **ERD Diagram**, และ **API Specification (OpenAPI 3.0)**  
ที่พร้อมสำหรับการพัฒนาใน Phase 03 (Build & Integrate)

---

## 🧩 Tasks  
1. วิเคราะห์ข้อมูลใน Feature Card ที่แนบด้านล่าง  
2. สร้าง ERD Diagram (Mermaid format) สำหรับทุก `data_entity`  
3. เขียน SQL Schema (PostgreSQL compatible) สำหรับสร้างตารางและ Foreign Key ที่สัมพันธ์กัน  
   - ต้องมีฟิลด์มาตรฐาน: `id`, `created_at`, `updated_at`, `deleted_at`  
   - กำหนด data type ที่เหมาะสม (INT, VARCHAR, BOOLEAN, TIMESTAMPTZ ฯลฯ)  
4. ออกแบบ OpenAPI Spec (YAML, version 3.0.3) สำหรับ CRUD (Create, Read, Update, Delete)  
   - ถ้า Feature มีการค้นหา (Search/Filter) ให้เพิ่ม endpoint `GET /search`  
   - ถ้ามี `linked_features` ให้สร้าง endpoint ที่อ้างถึง feature เหล่านั้น (Foreign Key)  
5. ตรวจสอบ naming ให้เป็นไปตามมาตรฐาน 2BSimpleCore (`db-schema-standards.md`)  
6. บันทึกผลในรูปแบบ:
   - `/projects/erp/docs/erd/{{FEATURE_CODE}}-{{MODULE}}.mmd`
   - `/projects/erp/backend/go_api/migrations/{{DATE}}_create_{{FEATURE_CODE}}_schema.sql`
   - `/projects/erp/docs/api/{{FEATURE_CODE}}-{{MODULE}}-openapi.yaml`

---

## 🧾 Output Format  
> **ให้ตอบเฉพาะเนื้อหาใน 3 หัวข้อด้านล่าง (ไม่มีคำอธิบายเพิ่มเติม)**  
> หาก entity มีหลายตาราง ให้รวมทั้งหมดในแต่ละหัวข้อ

### 🧱 ERD
  - mermaid
  - erDiagram

📘 Reference Standards:
  - Follow `db-schema-standards.md`
  - Follow `api-guidelines.md`
  - Follow `naming-rules.md`


### Phase 3 
--think-hard
Phase: 03 Build & Integrate  
Agent Role: Claude Backend Agent  
System: ERP Backend (Golang + PostgreSQL, Clean Architecture)

FEATURE_NAME: Product Management
FEATURE_CODE: PROD001
MODULE: Inventory
BASE_IMPORT: github.com/2b-simple/cube_bot_md

Feature: {{FEATURE_NAME}}  
Feature Code: {{FEATURE_CODE}}  
Module: {{MODULE}}  
Base Import Path: {{BASE_IMPORT}}  
Input Artifacts:  
- ERD Diagram: `projects/erp/docs/erd/{{FEATURE_CODE}}-{{MODULE}}.mmd`  
  (หรือ ERD SQL equivalent: `projects/erp/backend/go_api/migrations/{{DATE}}_create_{{FEATURE_CODE}}_schema.sql`)
- SQL Schema: `projects/erp/backend/go_api/migrations/{{DATE}}_create_{{FEATURE_CODE}}_schema.sql`  
- OpenAPI Spec: `projects/erp/docs/api/{{FEATURE_CODE}}-{{MODULE}}-openapi.yaml`  
- Feature Card JSON: `projects/erp/features/FC-{{FEATURE_CODE}}-{{FEATURE_NAME}}.json`  

---

## 🎯 Goal  
พัฒนา backend feature แบบ **Clean Architecture** ครบโครงสร้าง  
จากข้อมูล ERD, SQL Schema และ OpenAPI Spec ที่ได้จาก Phase 02  
โดยโค้ดที่สร้างต้องพร้อมสำหรับ build จริงในระบบ ERP ขององค์กร  

---

## 🧩 Tasks  
1. **Models (internal/models/)**  
   - สร้าง struct สำหรับแต่ละ entity ตาม ERD  
   - ใส่ `json` tag, `db` tag (snake_case), และ field ที่สัมพันธ์กับ FK  
   - ใส่ timestamp fields (`CreatedAt`, `UpdatedAt`, `DeletedAt *time.Time`)  

2. **Repositories (internal/repositories/)**  
   - Interface สำหรับ CRUD (Create, GetByID, List, Update, Delete)  
   - ใช้ context (`context.Context`)  
   - ใช้ `database/sql` หรือ `sqlx` (ไม่ใช้ ORM หนัก)  
   - สร้าง implementation stub ใน `internal/repositories/sql/`  

3. **Services (internal/services/)**  
   - Implement business logic layer  
   - ทำ validation ข้อมูลก่อนเรียก repository  
   - Handle business rule จาก Feature Card  

4. **Handlers (internal/handlers/)**  
   - Implement HTTP endpoints จาก OpenAPI Spec  
   - ใช้ `net/http`  
   - คืน response แบบ JSON  
   - ตั้งค่า HTTP status code ถูกต้อง  

5. **Routes (internal/routes/)**  
   - ฟังก์ชันสำหรับ register routes (เช่น `RegisterProductRoutes()`)  
   - ใช้ `mux.Router` หรือ `http.ServeMux`  

6. **Middleware (internal/middleware/)**  
   - ถ้ามี auth/logging/recovery ให้เพิ่ม placeholder พร้อม TODO comment  

7. **Tests (internal/tests/)**  
   - สร้าง test stub เช่น `product_service_test.go`  
   - ใช้ interface mock แทน repository  
   - ใช้ testify/assert  

8. **Manifest Update**  
   - phase: `"build_completed"`  
   - outputs: รวมไฟล์ทั้งหมดที่สร้าง  

---

## ⚙️ Conventions  
- Project follows `Clean Architecture`:  
  `handler → service → repository → model → database`  
- ใช้ `PascalCase` สำหรับ struct, `snake_case` สำหรับ database  
- `Repository` ใช้ interface เช่น  
  ```go
  type ProductRepository interface {
    Create(ctx context.Context, p *models.Product) error
    GetByID(ctx context.Context, id int) (*models.Product, error)
    List(ctx context.Context) ([]models.Product, error)
    Update(ctx context.Context, p *models.Product) error
    Delete(ctx context.Context, id int) error
  }

📘 Reference Standards:
- Follow `coding-style.md` for:
  - Function naming (PascalCase for exported)
  - Error handling (`fmt.Errorf("context: %w", err)`)
  - Avoid unnecessary comments
- Follow `api-guidelines.md` for handler route naming and HTTP status
- Follow `db-schema-standards.md` for DB field consistency


### Phase 4
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
  - table, column 
  - struct, function 
  - variable, receiver

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

