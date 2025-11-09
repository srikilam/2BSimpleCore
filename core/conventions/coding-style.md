# 🧠 Coding Style Guide (2BSimpleCore - Backend)

## 🎯 Objective
กำหนดมาตรฐานการเขียนโค้ด Golang ให้สอดคล้องกับหลักการ Clean Architecture  
เพื่อให้ Claude Agents และทีมพัฒนาเขียนโค้ดที่มีคุณภาพ สม่ำเสมอ และตรวจสอบได้อัตโนมัติในทุก Feature

---

## ⚙️ General Rules

- ใช้ **Golang 1.21+**  
- ยึดหลัก **Clean Architecture Pattern**
- ทุกฟังก์ชันต้องมีคำอธิบายแบบ **GoDoc** (เริ่มด้วยชื่อฟังก์ชัน)
- ห้าม import โดยไม่ใช้
- ใช้ `context.Context` สำหรับทุกฟังก์ชันที่มี external I/O
- Error ต้องถูกห่อด้วย `fmt.Errorf` หรือใช้ custom error type
- ห้ามใช้ magic number — ทุกค่าคงที่ต้องเป็น constant ที่มีชื่อสื่อความหมาย
- ห้ามใช้ global variable ยกเว้น constant ที่ไม่เปลี่ยนค่า

---

## 🧱 Project Structure (ตาม go_api)

internal/
 ├── config/           # โหลด environment variables
 ├── models/           # Struct สำหรับ database entities
 ├── repositories/     # Data access layer
 ├── services/         # Business logic
 ├── handlers/         # API endpoint layer
 ├── middleware/       # Auth, Logging, Panic Recovery
 ├── cache/            # Redis / In-memory cache
 └── monitoring/       # Prometheus / Tracing

🧩 Package & File Naming
| ประเภท    | รูปแบบ                  | ตัวอย่าง                                   |
| --------- | ----------------------- | ------------------------------------------ |
| package   | lowercase               | `repository`, `service`, `handler`         |
| file      | snake_case              | `product_service.go`, `user_repository.go` |
| test file | snake_case + `_test.go` | `product_service_test.go`                  |

✅ Best Practice
- ไฟล์ควรมีหน้าที่เดียว เช่น product_handler.go ไม่ควรเก็บหลาย entity
- Package name ต้องสื่อถึง domain เช่น purchase, inventory, auth

🧠 Code Formatting
- ใช้ gofmt หรือ goimports ตรวจทุกครั้งก่อน commit
- ห้ามมีบรรทัดว่างเกิน 1 บรรทัดระหว่าง logic
- import ต้องจัดกลุ่มดังนี้:
  import (
      "context"
      "fmt"

      "github.com/jmoiron/sqlx"

      "2bsimple/core/pkg/logger"
  )

⚙️ Function & Variable Naming
| ประเภท              | รูปแบบ            | ตัวอย่าง                        |
| ------------------- | ----------------- | ------------------------------- |
| Function (Exported) | PascalCase        | `CreateProduct()`               |
| Function (Private)  | camelCase         | `createProduct()`               |
| Variable            | camelCase         | `productRepo`, `totalAmount`    |
| Constant            | UPPER_CASE        | `MAX_RETRY_COUNT = 3`           |
| Struct              | PascalCase        | `Product`, `PurchaseOrder`      |
| Interface           | PascalCase + “er” | `ProductRepository`, `Notifier` |

❌ ห้าม
- ใช้ชื่อย่อที่ไม่สื่อความหมาย เช่น pd, svc, repo
- ตั้งชื่อฟังก์ชันยาวเกินจำเป็น เช่น HandleRequestForProductService
- ใช้ตัวแปรเดียวกันกับชื่อ struct เช่น Product Product

🧱 Error Handling
✅ หลักการ
  - ห้ามใช้ panic (ยกเว้นใน main)
  - ทุก error ต้อง handle และ return พร้อม context ที่ชัดเจน
  - ใช้ error wrapping สำหรับ stack trace
  - Handler ต้อง return JSON error format เดียวกัน

🧩 Logging Guideline
- ใช้ pkg/logger (custom logger ของระบบ)
- Log ทั้งระดับ info, warn, error
- Log format ต้องเป็น JSON เสมอ
- ทุก log ต้องมี trace_id สำหรับ correlation
- Example: 
  logger.Info("Create product success",
    "trace_id", traceID,
    "product_id", product.ID,
  )

🧪 Testing Standard
- ใช้ testing ของ Go
- ไฟล์ test ต้องลงท้าย _test.go
- ฟังก์ชันทดสอบต้องขึ้นต้นด้วย Test
- ใช้ table-driven test สำหรับ test case หลายแบบ
- Coverage ต้อง ≥ 80%

📦 Dependency Injection
- ใช้รูปแบบ constructor-based dependency injection
- ห้ามใช้ global หรือ service locator

🧠 Middleware Standard
- ทุก API ต้องมี middleware สำหรับ:
  - Logging
  - Authentication
  - Panic Recovery
- Middleware ต้องอยู่ใน internal/middleware/
- ห้ามใช้ recover() โดยตรงใน handler

🔒 Security Standard
- ห้าม log sensitive data เช่น password, token, personal info
- ทุก handler ต้องตรวจสิทธิ์ (JWT / Role)
- ต้อง sanitize input ก่อน insert/update DB
- ใช้ prepared statement หรือ ORM เท่านั้น
- ใช้ HTTPS ใน production

✅ Code Review Checklist
| หมวด              | ตรวจสอบ                         |
| ----------------- | ------------------------------- |
| 🔹 Naming         | ถูกต้องตามมาตรฐาน               |
| 🔹 Format         | ผ่าน `gofmt`                    |
| 🔹 Error Handling | ครบทุก path                     |
| 🔹 Logging        | มี trace_id ทุก log สำคัญ       |
| 🔹 Testing        | ครอบคลุม ≥ 80%                  |
| 🔹 Security       | ไม่มีข้อมูลสำคัญใน log          |
| 🔹 Manifest       | อัปเดต phase และ output ถูกต้อง |

📘 Reference Context
ใช้ร่วมกับ:
  - core/conventions/naming-rules.md
  - core/conventions/db-schema-standards.md
  - core/conventions/api-guidelines.md