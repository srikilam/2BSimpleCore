# 🧩 Backend Lifecycle (2BSimpleCore)

## 🎯 Purpose
Workflow นี้คือกระบวนการพัฒนา backend feature ตามหลัก Clean Architecture
โดยแบ่งเป็น 5 Phase ที่ Claude Agents และทีม dev ทำงานร่วมกันได้อย่างตรวจสอบได้

---

## 🧱 PHASE STRUCTURE

| Phase | Objective | Output | Responsible |
|--------|------------|---------|--------------|
| **01. Define & Analyze** | วิเคราะห์ FRD → สร้าง Feature Card | feature-<code>.json | Architect Agent |
| **02. Design & Schema** | ออกแบบ ERD + SQL Schema + API Spec | .mmd, .sql, .yaml | Architect Agent |
| **03. Build & Integrate** | พัฒนา Model, Repository, Service, Handler | .go files | Backend Agent |
| **04. QA & Validation** | ตรวจ schema, logic, naming, integration | QA Report | QA Agent |
| **05. Log & Learn** | สรุปผล reasoning และ QA | Logbook | Architect + QA |

---

## ⚙️ DATABASE SUBFLOW
อยู่ใน `backend-database-subflow.md`  
ใช้สำหรับงานที่เกี่ยวกับ schema, migration, data integrity

## ⚙️ API SUBFLOW
อยู่ใน `backend-api-subflow.md`  
ใช้สำหรับงานที่เกี่ยวกับ service, endpoint, middleware

---

## ✅ TRACEABILITY
ทุก Phase ต้องอัปเดตผลลงใน:
- `projects/erp/manifest/<feature>.json`
- `projects/erp/logbook/sprint-YYYY-MM/<feature>.md`
