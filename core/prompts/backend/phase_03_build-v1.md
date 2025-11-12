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
  #### ขั้นตอนที่ 1: อ่าน SQL Schema (บังคับ)
    📘 **MANDATORY:** อ่านไฟล์ SQL schema ที่สร้างใน Phase 01 ก่อนเขียน models

    ```bash
    # อ่าน schema file
    projects/erp/backend/go_api/migrations/*_create_{{FEATURE_CODE}}_schema.sql

  ขั้นตอนที่ 2: สร้าง Type Mapping
     ⚠️ กฎสำคัญ:
    - SQL UUID → Go uuid.UUID (ห้ามใช้ int64)
    - SQL BOOLEAN → Go bool (ห้ามเติม Is prefix ใน Go field)
    - SQL snake_case → Go PascalCase (แต่ JSON/DB tag ต้องเป็น snake_case)
    - SQL FK *_row_id → Go *RowID (ไม่ใช่ *ID)
    - SQL TIMESTAMPTZ → Go time.Time
    - SQL DECIMAL → Go decimal.Decimal (จาก shopspring/decimal)
   - สร้าง struct ตาม feature card
   - ใช้ naming convention ตาม `core/conventions/naming-rules.md`
   - ใส่ `json` tag, `db` tag (snake_case), และ field ที่สัมพันธ์กับ FK  
   - ใส่ timestamp fields (`CreatedAt`, `UpdatedAt`, `DeletedAt *time.Time`)  

2. **Repositories (internal/repositories/)**  
   - Interface สำหรับ CRUD (Create, GetByID, List, Update, Delete)  
   - ใช้ context (`context.Context`)  
   - ใช้ `database/sql` หรือ `sqlx` (ไม่ใช้ ORM หนัก)  
   - สร้าง implementation stub ใน `internal/repositories/sql/`  
   - สร้าง SQL implementation ครบทุก repository interface

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
   - ฟังก์ชันสำหรับ register routes ของแต่ละ feature  
   - ใช้ **Gin Framework** (`github.com/gin-gonic/gin`)  
   - ทุก feature ต้องมีฟังก์ชันในรูปแบบ:
     ```go
     func Register<Product>Routes(router *gin.RouterGroup, handler *handlers.<Product>Handler)
     ```
     ตัวอย่างเช่น:
     ```go
     // FILE: internal/routes/product_routes.go
     package routes

     import (
       "github.com/gin-gonic/gin"
       "{{BASE_IMPORT}}/internal/handlers"
     )

     func RegisterProductRoutes(r *gin.RouterGroup, h *handlers.ProductHandler) {
       products := r.Group("/products")
       {
         products.GET("", h.GetAllProducts)
         products.GET("/:id", h.GetProductByID)
         products.POST("", h.CreateProduct)
         products.PATCH("/:id", h.UpdateProduct)
         products.DELETE("/:id", h.DeleteProduct)
       }
     }
     ```
   - ต้องเรียกใช้ภายใต้ root group เช่น `/api/v1` ตามมาตรฐาน versioning ของระบบ ERP  
   - หาก feature มี module เฉพาะ เช่น `inventory`, ให้ใช้ route prefix เช่น `/api/v1/inventory/products`  
   - หาก feature มีการใช้ middleware เฉพาะ ให้ inject middleware ผ่าน RouterGroup เช่น:
     ```go
     auth := r.Group("/products", middleware.RequireAuth())
     auth.POST("", h.CreateProduct)
     ```
   - Gin router จะเป็น default router ของระบบแทน `mux` และ `net/http`  
   - Route registration จะถูกรวมใน `cmd/api/main.go` เช่น:
     ```go
     func setupRouter() *gin.Engine {
       r := gin.Default()
       api := r.Group("/api/v1")

       routes.RegisterProductRoutes(api, productHandler)
       routes.RegisterCategoryRoutes(api, categoryHandler)

       return r
     }
     ```

6. **Wire Dependencies (cmd/api/main.go)**  
   - ทำหน้าที่เชื่อมโยง (Dependency Injection) ระหว่าง Layer ต่าง ๆ:  
     - Repository → Service → Handler → Routes  
   - ใช้ Manual wiring (ไม่ต้องใช้ fx หรือ wire library)  
   - ต้องแยก logic ของการเชื่อมโยงออกจาก business logic ทั้งหมด  
   - ใช้ Gin เป็น web framework หลัก  
   - ต้องสร้าง router พร้อม register routes ของทุก feature  
   - ต้องอ่านค่าการตั้งค่าพื้นฐานจากไฟล์ `.env` หรือ config (เช่น DB_URL)  

   ตัวอย่างเช่น:
   ```go
   // FILE: cmd/api/main.go
   package main

   import (
     "database/sql"
     "log"
     "os"

     "github.com/gin-gonic/gin"
     _ "github.com/lib/pq"

     "{{BASE_IMPORT}}/internal/handlers"
     "{{BASE_IMPORT}}/internal/repositories/sqlrepo"
     "{{BASE_IMPORT}}/internal/services"
     "{{BASE_IMPORT}}/internal/routes"
   )

   func main() {
     // Load config (example)
     dbURL := os.Getenv("DATABASE_URL")
     db, err := sql.Open("postgres", dbURL)
     if err != nil {
       log.Fatalf("❌ Failed to connect DB: %v", err)
     }
     defer db.Close()

     // Wire dependencies
     productRepo := sqlrepo.NewProductRepository(db)
     productService := services.NewProductService(productRepo)
     productHandler := handlers.NewProductHandler(productService)

     // Setup router
     r := gin.Default()
     api := r.Group("/api/v1")

     // Register feature routes
     routes.RegisterProductRoutes(api, productHandler)

     // Start server
     if err := r.Run(":8080"); err != nil {
       log.Fatalf("❌ Failed to start server: %v", err)
     }
   }

7. **Middleware (internal/middleware/)**  
   - ถ้ามี auth/logging/recovery ให้เพิ่ม placeholder พร้อม TODO comment  

8. **Tests (internal/tests/)**  
   - สร้าง test stub เช่น `product_service_test.go`  
   - ใช้ interface mock แทน repository  
   - ใช้ testify/assert  

9. **Manifest Update**  
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
  - Function naming
  - Error handling (`fmt.Errorf("context: %w", err)`)
  - Avoid unnecessary comments
- Follow `api-guidelines.md` for:
  - Route pattern: `/api/v1/<module>/<entity>`
  - HTTP status: `200 OK`, `201 Created`, `204 No Content`, `400 Bad Request`, `404 Not Found`
  - JSON response format:
    ```json
    { "data": ..., "message": "..." }
    ```
- Follow `db-schema-standards.md` for DB field consistency

### สิ่งที่ต้องทำ
- **Always verify go.mod first before generating imports
- **Use Gin Framework (`github.com/gin-gonic/gin`)** for routing and middleware