--think-hard
Phase: 01 Define & Analyze  
Agent Role: Claude Architect Agent  
System: ERP Backend (Golang)  

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

📘 Reference Standards:
- Follow `naming-rules.md` when defining entity names and feature codes.
