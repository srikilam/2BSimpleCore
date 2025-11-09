# 🧱 Naming Rules (2BSimpleCore)

## 🎯 Purpose
กำหนดมาตรฐานการตั้งชื่อสำหรับทุกเลเยอร์ของระบบ  
เพื่อให้ Claude Agents และทีมพัฒนาใช้โครงสร้างชื่อที่เหมือนกันทุกโมดูล  
ลดความสับสน และทำให้ระบบตรวจสอบอัตโนมัติ (QA, Manifest, AI Reasoning) ได้ถูกต้อง

---

## 🧩 Database Naming

| รายการ | รูปแบบ | ตัวอย่าง |
|----------|----------|----------|
| ตาราง | snake_case | `purchase_order`, `product_category` |
| คอลัมน์ | snake_case | `created_at`, `category_id` |
| Primary Key | id | `id` |
| Foreign Key | {table}_id | `employee_id`, `unit_id` |
| Enum | lowercase + underscore | `approval_status`, `leave_type` |
| View / Function | snake_case | `vw_product_summary`, `fn_calculate_stock` |

### ✅ คำแนะนำเพิ่มเติม
- ชื่อตารางควรเป็น **คำนามพหูพจน์** เช่น `products`, `orders`
- หลีกเลี่ยงชื่อซ้ำกับ reserved words ของ DB เช่น `user`, `group`, `order`

---

## ⚙️ API Naming

| รายการ | รูปแบบ | ตัวอย่าง |
|----------|----------|----------|
| Base Path | plural noun | `/api/products`, `/api/orders` |
| ID Path | :id | `/api/products/:id` |
| Verb Path | lowercase dash-case | `/api/products/:id/approve` |
| Query Param | snake_case | `?status=pending&limit=10` |
| Version Prefix | /api/v1/ | `/api/v1/products` |

### ✅ คำแนะนำเพิ่มเติม
- Endpoint ต้องเป็นชื่อ plural เสมอ (`/api/products` ไม่ใช่ `/api/product`)
- ใช้ HTTP Verb แทน action เช่น  
  - `GET /api/products`  
  - `POST /api/products`  
  - `PATCH /api/products/:id`  
  - `DELETE /api/products/:id`

---

## 🧠 Golang Naming

| Entity | รูปแบบ | ตัวอย่าง |
|---------|---------|----------|
| Struct | PascalCase | `Product`, `PurchaseOrder` |
| Interface | PascalCase + “er” suffix | `ProductRepository`, `OrderService` |
| Variable | camelCase | `productRepo`, `totalAmount` |
| Function | PascalCase | `CreateProduct`, `UpdateOrderStatus` |
| File | snake_case | `product_service.go`, `order_repository.go` |
| Package | lowercase | `repository`, `service` |
| Test | snake_case + `_test.go` | `product_service_test.go` |

### ✅ กฎเพิ่มเติม
- ใช้ **PascalCase** สำหรับ public symbol (exported)
- ใช้ **camelCase** สำหรับ private variable
- อย่าตั้งชื่อสั้นหรือย่อ เช่น `p`, `o`, `s` — ให้ใช้ชื่อเต็มที่สื่อความหมาย
- ค่าคงที่ (constant) ให้ตั้งชื่อเต็ม เช่น:
  ```go
  const DefaultTimeoutSeconds = 30
