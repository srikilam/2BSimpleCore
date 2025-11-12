--think-hard
Phase: 05 Log & Learn

FEATURE_NAME: Product Management
FEATURE_CODE: PROD001
MODULE: Inventory
SPRINT: 01

Feature: {{FEATURE_NAME}} ({{FEATURE_CODE}})
Sprint: {{SPRINT}}
System: ERP Backend (Golang)
Goal:
- บันทึกผล reasoning + QA result + design decision
- สรุป lesson learned เพื่อปรับปรุง workflow

Task:
1. สรุป Design Decisions:
   - Schema / API / Logic ที่ใช้จริง
2. บันทึก Issues & Fixes:
   - ปัญหาที่เจอและแนวทางแก้ไข
3. บันทึก QA Result จาก Phase 04
4. สรุป Lesson Learned:
   - ข้อปรับปรุงใน sprint ถัดไป
5. บันทึกลงไฟล์:
   `/projects/erp/logbook/sprint-{{SPRINT}}/feature-{{FEATURE_CODE}}.md`
6. อัปเดต Manifest:
   `"phase": "log_completed"`
