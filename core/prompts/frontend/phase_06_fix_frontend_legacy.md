--think-hard
Phase: 06 Fix & Patch (Frontend Legacy Bridge Mode)
Agent Role: Claude Frontend Agent
System: External Frontend (React / Vue / Strapi UI / Next.js)

Feature: {{FEATURE_NAME}}
Feature Code: {{FEATURE_CODE}}
Module: {{MODULE}}
System Origin: {{SYSTEM_ORIGIN}}
Fix Type: UI Bug / Logic Bug / Integration Bug / Data Binding Error

---

## 🎯 Goal
วิเคราะห์และแก้ไขปัญหาที่เกิดขึ้นในระบบ frontend legacy  
โดยคงโครงสร้างเดิมไว้มากที่สุด แต่จัดทำรายงานผลและ manifest ในรูปแบบ 2BSimpleCore  
เพื่อรองรับการ migrate หรือ integrate เข้ากับระบบใหม่ในอนาคต

---

## 🧩 Tasks
1. วิเคราะห์สาเหตุของ bug จาก source code (เช่น React component, Vue file, หรือ HTML template)
2. เสนอ patch หรือแก้ไขเฉพาะจุด (ไม่ rewrite ทั้ง component)
3. อธิบายผลกระทบ (impact) ที่อาจเกิดขึ้น
4. แนะนำแนวทางปรับปรุง UX/UI หรือ migration เข้าระบบใหม่ (optional)
5. สร้างรายงาน `legacy_frontend_patch.md`
6. อัปเดต manifest และ logbook

---

## ⚙️ Input Files
- Legacy Source (ตัวอย่าง)
  - React: `/legacy/frontend/src/pages/product/EditProduct.jsx`
  - Vue: `/legacy/frontend/components/LeaveForm.vue`
- Feature Card (Legacy): `projects/erp/features/legacy/FC-{{FEATURE_CODE}}-{{FEATURE_NAME}}.json`
- Logbook: `projects/erp/logbook/sprint-{{SPRINT}}/legacy-frontend-{{FEATURE_CODE}}-issues.md`

---

## 🧾 Output Files
1. รายงานการแก้ไข (markdown):  
   `projects/erp/logbook/sprint-{{SPRINT}}/legacy-frontend-{{FEATURE_CODE}}-patch.md`
2. Updated source code (เฉพาะไฟล์ที่แก้)
3. Updated manifest:
   - `"system_origin"`
   - `"phase": "fix_completed"`
   - `"fix_strategy"`
   - `"qa_status": "pending"`

---

## 🧱 Example Patch Report
```markdown
# 🩹 Legacy Frontend Patch — Feature: Product Form (LEG301)
System Origin: Strapi UI v4.6
Date: 2025-11-10
Reviewer: Claude Frontend Agent

## 🔍 Root Cause
ในไฟล์ `EditProduct.jsx` ไม่มี validation สำหรับ input `price` ก่อน submit  
ทำให้ผู้ใช้สามารถส่งค่า `0` ได้โดยไม่แจ้ง error

## 🧩 Patch Suggestion
```jsx
// PATCH
if (!form.price || form.price <= 0) {
  setError('Price must be greater than 0');
  return;
}
