# ⚙️ 2BSimpleCore — Script Usage Guide

## 🎯 Purpose
โฟลเดอร์ `core/scripts/` ใช้เก็บสคริปต์ที่ช่วยให้ทีมพัฒนาและ Claude Agents  
สามารถรันแต่ละ Phase ของ Workflow ได้อย่างเป็นระบบ โดยไม่ต้องพิมพ์ Prompt เองทุกครั้ง

---

## 🧩 Script Overview

| Script | Phase | Description |
|--------|--------|-------------|
| `run_phase01.sh` | **Define & Analyze** | แปลง FRD → Feature Card |
| `run_phase02.sh` | **Design & Schema** | ออกแบบ ERD, SQL Schema, และ API Spec |
| `run_phase03.sh` | **Build & Integrate** | พัฒนา Golang Code (Model, Service, Handler) |
| `run_phase04.sh` | **QA & Validation** | ตรวจ logic, schema consistency, และ naming |
| `run_phase05.sh` | **Log & Learn** | บันทึก reasoning, QA Result, และ Lesson Learned |

---

## 📦 Folder Structure

---

## 🧠 ขั้นตอนการใช้งาน Script (Phase Workflow)

### 1️⃣ เตรียมข้อมูล FRD
- วางไฟล์ FRD ที่ทีม Business Analyst จัดทำไว้ใน: projects/erp/docs/frd/


---

### 2️⃣ เริ่ม Phase 01 — สร้าง Feature Card

รันคำสั่ง:
```bash
./core/scripts/run_phase01.sh "Product Management" "PROD001" "Inventory"

ตัวอย่าง Workflow การทำงานจริง
# 1. วิเคราะห์ FRD → สร้าง Feature Card
./core/scripts/run_phase01.sh "Product Management" "PROD001" "Inventory"

# 2. ออกแบบ ERD + SQL + API Spec
./core/scripts/run_phase02.sh "Product Management" "PROD001"

# 3. พัฒนาโค้ด backend
./core/scripts/run_phase03.sh "PROD001"

# 4. ตรวจคุณภาพโค้ด
./core/scripts/run_phase04.sh "PROD001"

# 5. บันทึกผล QA และสรุปลง logbook
./core/scripts/run_phase05.sh "PROD001"

