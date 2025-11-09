--think-hard
Phase: 02 Design & Schema  
Agent Role: Claude Architect Agent  
System: ERP Backend (Golang + PostgreSQL)

<!--
FEATURE_NAME: Product Management
FEATURE_CODE: PROD001
MODULE: Inventory
-->
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
