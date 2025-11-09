# ⚙️ API Guidelines (2BSimpleCore)

## 🎯 Objective
กำหนดมาตรฐานกลางของ API สำหรับระบบ ERP ทั้งหมด  
เพื่อให้ Claude Agents และทีมพัฒนาทำงานร่วมกันได้อย่างสอดคล้อง  
รองรับทั้ง RESTful Design, Security, และการตรวจสอบอัตโนมัติในทุก Phase

---

## 🧱 Versioning
- ทุก API ต้องมี version prefix เสมอ เช่น `/api/v1/`
- หากมีการเปลี่ยน breaking change ให้สร้าง version ใหม่ เช่น `/api/v2/`
- สามารถระบุ version ผ่าน Header ได้ด้วย:


---

## 🔗 Base URL & Path Structure
| ประเภท | รูปแบบ | ตัวอย่าง |
|----------|----------|-----------|
| Base Path | plural noun | `/api/products`, `/api/orders` |
| ID Path | :id | `/api/products/:id` |
| Verb Path | lowercase-dash-case | `/api/products/:id/approve` |
| Query Parameters | snake_case | `/api/products?status=pending&limit=20` |

---

## ⚙️ HTTP Methods & Meaning
| Method | ใช้สำหรับ | ตัวอย่าง |
|----------|------------|-----------|
| **GET** | ดึงข้อมูล | `/api/products` |
| **POST** | สร้างข้อมูลใหม่ | `/api/products` |
| **PATCH** | อัปเดตข้อมูลบางส่วน | `/api/products/:id` |
| **PUT** | แทนที่ข้อมูลทั้งหมด | `/api/products/:id` |
| **DELETE** | ลบข้อมูล | `/api/products/:id` |

---

## 📦 Request Body Format
- ใช้ JSON เสมอ
- ทุก endpoint ต้องมีการ validate ข้อมูลก่อน insert/update
- ห้ามใช้ `form-data` หรือ `x-www-form-urlencoded` เว้นแต่สำหรับ upload ไฟล์

- ตัวอย่าง:

  {
  "name": "Product A",
  "category_id": 1,
  "unit_id": 2,
  "price": 150.50
  }

📤 Response Format
 - ทุก API ต้องตอบกลับในรูปแบบ JSON เดียวกันทั้งระบบ
  {
    "data": {...},
    "meta": {
      "page": 1,
      "limit": 20,
      "total": 135
    },
    "error": null
  }

❌ Error Format
- รูปแบบการตอบกลับเมื่อเกิดข้อผิดพลาดต้องเป็นโครงสร้างเดียวกันทุก endpoint
  {
    "error": {
      "message": "invalid product id",
      "code": "INVALID_ID",
      "detail": "The product ID must be numeric."
    }
  }

✅ กฎเพิ่มเติม
- ต้องระบุ message ที่อ่านเข้าใจง่าย
- code ต้องเป็น UPPER_CASE และสื่อถึงประเภทของ error
- detail ใช้อธิบายเทคนิคเพิ่มเติม (optional)

🧾 Pagination & Filtering
- ใช้ parameter: page, limit, sort, filter
- Response ต้องมี meta พร้อมจำนวน total เสมอ

🔒 Authentication & Authorization
- ทุก request ต้องมี Header:
  Authorization: Bearer <token>
- Token ใช้ JWT (JSON Web Token)
- Role-based Access Control (RBAC):
  - Admin → CRUD ทั้งหมด
  - User → Read-only หรือเฉพาะสิทธิ์ที่กำหนด

🚨 Error Code Table
| Code            | HTTP | ความหมาย             |
| --------------- | ---- | -------------------- |
| INVALID_ID      | 400  | รหัสข้อมูลไม่ถูกต้อง |
| MISSING_FIELD   | 400  | ข้อมูลไม่ครบ         |
| UNAUTHORIZED    | 401  | ไม่มีสิทธิ์เข้าถึง   |
| NOT_FOUND       | 404  | ไม่พบข้อมูล          |
| DUPLICATE_ENTRY | 409  | ข้อมูลซ้ำ            |
| INTERNAL_ERROR  | 500  | ระบบผิดพลาดภายใน     |

Naming Convention
- Resource ใช้ชื่อ พหูพจน์ เสมอ (/api/products ✅)
- ห้ามมีคำกริยาใน path เช่น /api/createProduct ❌
- ใช้ HTTP method แทน เช่น POST /api/products ✅
- ใช้ snake_case สำหรับ query parameter
- ใช้ kebab-case สำหรับ path parameter ที่เป็น verb เช่น /api/products/:id/approve

🧩 Response Status Code Guideline
| สถานะ                     | คำอธิบาย                             | ตัวอย่าง                   |
| ------------------------- | ------------------------------------ | -------------------------- |
| 200 OK                    | การดำเนินการสำเร็จ                   | GET `/api/products`        |
| 201 Created               | สร้างข้อมูลสำเร็จ                    | POST `/api/products`       |
| 204 No Content            | ลบข้อมูลสำเร็จ (ไม่มี response body) | DELETE `/api/products/:id` |
| 400 Bad Request           | ข้อมูลไม่ถูกต้อง                     | Missing required field     |
| 401 Unauthorized          | ไม่มี token หรือ token ไม่ถูกต้อง    | Header missing             |
| 403 Forbidden             | ไม่มีสิทธิ์เข้าถึง                   | User role ไม่ตรง           |
| 404 Not Found             | ไม่พบข้อมูล                          | Product ID ไม่ถูกต้อง      |
| 409 Conflict              | ข้อมูลซ้ำ                            | Email ซ้ำ                  |
| 500 Internal Server Error | ระบบมีปัญหาภายใน                     | DB connection fail         |

🧠 Example Endpoint (Product)
  - GET    /api/products
  - GET    /api/products/:id
  - POST   /api/products
  - PATCH  /api/products/:id
  - DELETE /api/products/:id

- ตัวอย่างโครงสร้าง API Spec (OpenAPI):
    paths:
      /api/products:
        get:
          summary: Get list of products
          responses:
            '200':
              description: Success
        post:
          summary: Create product
          responses:
            '201':
              description: Created

🧩 Rate Limiting (ถ้ามี)
- ให้กำหนดไว้ที่ layer middleware
- Response เมื่อเกิน limit:
  {
    "error": {
      "message": "too many requests",
      "code": "RATE_LIMIT_EXCEEDED"
    }
  }
- Header:
  X-RateLimit-Limit: 100
  X-RateLimit-Remaining: 0
  Retry-After: 60

✅ API Review Checklist
| หมวด          | ตรวจสอบ                         |
| ------------- | ------------------------------- |
| 🧩 Naming     | Path เป็น plural noun           |
| 🧠 Versioning | มี `/api/v1/`                   |
| ⚙️ Response   | ใช้โครงสร้าง data/meta/error    |
| 🚨 Error      | ใช้ error format มาตรฐาน        |
| 🔒 Security   | มี Authorization header         |
| 🧾 Pagination | meta ครบทุกครั้ง                |
| 📘 OpenAPI    | ระบุ status code ครบ            |
| ⚙️ Manifest   | อัปเดต endpoint ใน feature card |

📘 Reference Context
- ใช้ร่วมกับ:
  - core/conventions/naming-rules.md
  - core/conventions/db-schema-standards.md
  - core/conventions/coding-style.md