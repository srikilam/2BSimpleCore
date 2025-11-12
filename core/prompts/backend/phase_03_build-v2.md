--think-hard
  Phase: 03 Build & Integrate
  Agent Role: Claude Backend Agent
  System: ERP Backend (Golang + PostgreSQL, Clean Architecture)

  FEATURE_NAME: Product Management
  FEATURE_CODE: PROD001
  MODULE: Inventory
  BASE_IMPORT: github.com/2b-simple/cube_bot_md

  FEATURE_NAME: {{FEATURE_NAME}}
  FEATURE_CODE: {{FEATURE_CODE}}
  MODULE: {{MODULE}}
  BASE_IMPORT: {{BASE_IMPORT}}

  ---

  ## 🎯 Goal
  พัฒนา backend feature แบบ **Clean Architecture** ที่ **build ผ่านและพร้อมใช้งานจริง**
  จากข้อมูล ERD, SQL Schema และ OpenAPI Spec ที่ได้จาก Phase 02

  **ข้อกำหนดสำคัญ**:
  - ✅ `go build ./...` ต้องผ่านโดยไม่มี error
  - ✅ โค้ดต้องตรงกับ database schema ทุก field
  - ✅ Repository implementations ต้องครบทุก interface
  - ✅ ไม่มีไฟล์ซ้ำในโปรเจค

  ---

  ## 📥 Input Artifacts (อ่านก่อนเริ่มงาน)

  ### 🔴 MANDATORY - ต้องอ่านทุกไฟล์ก่อนเขียนโค้ด:

  1. **`go.mod`** (อ่านก่อนอื่นเสมอ)
     - Path: `projects/erp/backend/go_api/go.mod`
     - **วัตถุประสงค์**: ดูว่า module path ที่ถูกต้องคืออะไร
     - **การใช้**: ทุก import ต้องขึ้นต้นด้วย module path จาก go.mod
     - **ตัวอย่าง**: ถ้า go.mod มี `module github.com/2b-simple/cube_bot_md`
       → ทุกไฟล์ต้อง import `github.com/2b-simple/cube_bot_md/internal/...`

  2. **SQL Schema Migration**
     - Path:
  `projects/erp/backend/go_api/migrations/{{DATE}}_create_{{FEATURE_CODE}}_schema.sql`
     - **วัตถุประสงค์**: เข้าใจโครงสร้างฐานข้อมูลที่แท้จริง
     - **สิ่งที่ต้องสังเกต**:
       - Primary key type (UUID, BIGSERIAL, INT, etc.)
       - มี dual-ID pattern หรือไม่ (row_id UUID + id VARCHAR)
       - Column names ทั้งหมด (ต้องตรงกับ db tag)
       - Data types (DECIMAL, VARCHAR, TIMESTAMPTZ, etc.)
       - Foreign key names (xxx_row_id, xxx_id)
       - NOT NULL constraints
       - CHECK constraints (enum values)
     - **กฎ**: Model struct ต้อง**ตรงทุก field** กับ SQL schema

  3. **OpenAPI Specification**
     - Path: `projects/erp/docs/api/{{FEATURE_CODE}}-{{MODULE}}-openapi.yaml`
     - **วัตถุประสงค์**: ดู endpoints, request/response schemas, HTTP methods
     - **สิ่งที่ต้องสังเกต**:
       - ทุก path และ method ที่ต้อง implement
       - Request body schemas (ProductCreate, ProductUpdate)
       - Response schemas (Product, ProductListItem)
       - Query parameters, path parameters
       - HTTP status codes

  4. **Feature Card**
     - Path: `projects/erp/features/FC-{{FEATURE_CODE}}-{{FEATURE_NAME}}.json`
     - **วัตถุประสงค์**: เข้าใจ business requirements
     - **สิ่งที่ต้องสังเกต**:
       - User stories (business rules ที่ต้อง implement)
       - Validation rules
       - Lifecycle/workflow requirements

  5. **ERD Diagram** (ถ้ามี)
     - Path: `projects/erp/docs/erd/{{FEATURE_CODE}}-{{MODULE}}.mmd`
     - **วัตถุประสงค์**: ภาพรวมความสัมพันธ์ระหว่าง entities

  ---

  ## 🧩 Tasks (เรียงลำดับตามความสำคัญ)

  ### 📌 Step 0: PRE-FLIGHT CHECKS (ทำก่อนเขียนโค้ดทุกครั้ง)

  ```bash
  # 1. อ่าน go.mod
  ✅ Read: projects/erp/backend/go_api/go.mod
  ✅ Extract: module path (e.g., github.com/2b-simple/cube_bot_md)
  ✅ Verify: BASE_IMPORT matches go.mod

  # 2. อ่าน SQL schema
  ✅ Read: migrations/*_create_{{FEATURE_CODE}}_schema.sql
  ✅ List all tables และ columns
  ✅ Note: Primary key types (UUID/BIGSERIAL/etc.)
  ✅ Note: Foreign key patterns (xxx_row_id vs xxx_id)
  ✅ Note: Enum values จาก CHECK constraints

  # 3. ตรวจสอบไฟล์ที่มีอยู่แล้ว
  ✅ Glob: internal/models/*.go
  ✅ Check: มีไฟล์ซ้ำหรือไม่
  ✅ If duplicate exists: ใช้ไฟล์ที่มี snake_case (product_audit.go, NOT productaudit.go)

  # 4. อ่าน OpenAPI
  ✅ Read: docs/api/{{FEATURE_CODE}}-{{MODULE}}-openapi.yaml
  ✅ List all paths และ operations
  ✅ Extract: schemas, parameters, responses

  ---
  📌 Task 1: Models (internal/models/)

  กฎเหล็ก:
  1. ชื่อไฟล์: ใช้ snake_case เท่านั้น (เช่น product_audit.go, NOT productaudit.go หรือ productAudit.go)
  2. Field mapping: ต้องตรงกับ SQL schema ทุกตัว
  3. Primary Key: ต้องตรงกับ SQL schema
    - ถ้า SQL ใช้ UUID row_id + VARCHAR id → Model ต้องมี RowID uuid.UUID และ ID string
    - ถ้า SQL ใช้ BIGSERIAL id → Model ใช้ ID int64
  4. Foreign Keys: ต้องตรงกับ SQL schema
    - ถ้า SQL ใช้ category_row_id UUID → Model ใช้ CategoryRowID *uuid.UUID
    - ถ้า SQL ใช้ category_id BIGINT → Model ใช้ CategoryID *int64
  5. db tags: ต้องตรงกับ column name ใน SQL

  Template:
  package models

  import (
      "time"
      "github.com/google/uuid"  // ถ้าใช้ UUID
  )

  // Product represents... (copy from SQL COMMENT if exists)
  type Product struct {
      // Primary Keys (ตรงกับ SQL)
      RowID uuid.UUID `json:"row_id" db:"row_id"`  // ถ้า SQL ใช้ UUID
      ID    string    `json:"id" db:"id"`          // ถ้า SQL มี public ID

      // Business Fields (ตรงกับ SQL ทุกตัว)
      Code   string  `json:"code" db:"code"`
      Name   string  `json:"name" db:"name"`
      // ... (ทุก field ตาม SQL)

      // Foreign Keys (ตรงกับ SQL naming)
      CategoryRowID *uuid.UUID `json:"category_row_id,omitempty" db:"category_row_id"`

      // Timestamps (ต้องมีเสมอ)
      CreatedAt time.Time  `json:"created_at" db:"created_at"`
      UpdatedAt time.Time  `json:"updated_at" db:"updated_at"`
      DeletedAt *time.Time `json:"deleted_at,omitempty" db:"deleted_at"`

      // Optimistic Locking (ถ้า SQL มี)
      Version int `json:"version" db:"version"`
  }

  // Constants (จาก SQL CHECK constraints)
  const (
      ProductStatusDraft    = "Draft"     // ตรงกับ CHECK constraint
      ProductStatusInReview = "In Review"
      // ...
  )

  Checklist หลังสร้าง model:
  - ไฟล์ชื่อเป็น snake_case
  - ทุก field มี db tag
  - Primary key type ตรงกับ SQL
  - Foreign key type และชื่อตรงกับ SQL
  - มี timestamps fields
  - มี constants สำหรับ enum values
  - Import path ตรงกับ go.mod

  ---
  📌 Task 2: Repository Interfaces (internal/repositories/)

  กฎเหล็ก:
  1. ชื่อไฟล์: <entity>_repository.go (snake_case)
  2. Interface name: <Entity>Repository (PascalCase)
  3. ทุก method ต้องมี context.Context เป็น parameter แรก
  4. Import: ใช้ module path จาก go.mod

  Template:
  package repositories

  import (
      "context"
      "{{MODULE_PATH_FROM_GO_MOD}}/internal/models"
  )

  type ProductRepository interface {
      Create(ctx context.Context, product *models.Product) error
      GetByID(ctx context.Context, id uuid.UUID) (*models.Product, error)  // ใช้ UUID ถ้า PK เป็น 
  UUID
      GetByPublicID(ctx context.Context, id string) (*models.Product, error)  // ถ้ามี dual-ID
      List(ctx context.Context, filters ProductFilters) ([]models.Product, int64, error)
      Update(ctx context.Context, product *models.Product) error
      Delete(ctx context.Context, id uuid.UUID) error
      // Add domain-specific methods (จาก business requirements)
  }

  // Filters struct สำหรับ query parameters
  type ProductFilters struct {
      Query    string
      Status   []string
      Page     int
      Limit    int
      Sort     string
  }

  ---
  📌 Task 3: Repository SQL Implementations (internal/repositories/sql/)

  🔴 CRITICAL: ต้องสร้าง implementation ให้ครบทุก repository interface

  กฎเหล็ก:
  1. ชื่อไฟล์: <entity>_repository.go (เหมือนกับ interface)
  2. ต้องสร้างครบทุกไฟล์ - ห้ามทิ้ง TODO stub
  3. SQL queries ต้องใช้ column names ที่ตรงกับ schema
  4. Primary key queries ต้องใช้ type ที่ถูกต้อง (UUID vs int64)
  5. Import path ต้องใช้จาก go.mod

  Template:
  package sql

  import (
      "context"
      "database/sql"
      "fmt"

      "github.com/jmoiron/sqlx"
      "github.com/google/uuid"  // ถ้าใช้ UUID

      "{{MODULE_PATH_FROM_GO_MOD}}/internal/models"
      "{{MODULE_PATH_FROM_GO_MOD}}/internal/repositories"
  )

  type ProductRepositorySQL struct {
      db *sqlx.DB
  }

  func NewProductRepository(db *sqlx.DB) repositories.ProductRepository {
      return &ProductRepositorySQL{db: db}
  }

  func (r *ProductRepositorySQL) Create(ctx context.Context, product *models.Product) error {
      query := `
          INSERT INTO products (
              code, name, type, category_row_id, status, base_uom
              -- ใช้ column names ตรงกับ SQL schema
          ) VALUES ($1, $2, $3, $4, $5, $6)
          RETURNING row_id, id, version, created_at, updated_at
          -- RETURNING ต้องตรงกับ SQL RETURNING clause
      `

      err := r.db.QueryRowContext(
          ctx, query,
          product.Code, product.Name, product.Type,
          product.CategoryRowID, product.Status, product.BaseUOM,
      ).Scan(
          &product.RowID,     // ต้องตรงกับ RETURNING
          &product.ID,
          &product.Version,
          &product.CreatedAt,
          &product.UpdatedAt,
      )

      if err != nil {
          return fmt.Errorf("failed to create product: %w", err)
      }

      return nil
  }

  func (r *ProductRepositorySQL) GetByID(ctx context.Context, id uuid.UUID) (*models.Product, 
  error) {
      query := `
          SELECT row_id, id, code, name, type, category_row_id, status, base_uom,
                 version, created_at, updated_at, deleted_at
          FROM products
          WHERE row_id = $1 AND deleted_at IS NULL
          -- ใช้ row_id ถ้า PK เป็น UUID
      `

      var product models.Product
      err := r.db.GetContext(ctx, &product, query, id)
      if err == sql.ErrNoRows {
          return nil, fmt.Errorf("product not found: %w", err)
      }
      if err != nil {
          return nil, fmt.Errorf("failed to get product: %w", err)
      }

      return &product, nil
  }

  // ... implement ALL interface methods

  Checklist:
  - สร้างไฟล์ครบทุก repository (ถ้ามี 8 interfaces ต้องมี 8 implementations)
  - ทุก method ใน interface ถูก implement
  - SQL column names ตรงกับ schema
  - Primary key queries ใช้ type ถูกต้อง (UUID vs int64)
  - Import path ตรงกับ go.mod
  - Error wrapping ใช้ fmt.Errorf("%w", err)

  ---
  📌 Task 4: Services (internal/services/)

  Template:
  package services

  import (
      "context"
      "fmt"

      "{{MODULE_PATH_FROM_GO_MOD}}/internal/models"
      "{{MODULE_PATH_FROM_GO_MOD}}/internal/repositories"
  )

  type ProductService struct {
      productRepo repositories.ProductRepository
      // inject ทุก dependency ที่จำเป็น
  }

  func NewProductService(
      productRepo repositories.ProductRepository,
      // รับทุก repository ที่ต้องใช้
  ) *ProductService {
      return &ProductService{
          productRepo: productRepo,
      }
  }

  func (s *ProductService) CreateProduct(ctx context.Context, req *models.ProductCreate) 
  (*models.Product, error) {
      // 1. Validate input
      if err := s.validateProductCreate(req); err != nil {
          return nil, fmt.Errorf("validation failed: %w", err)
      }

      // 2. Business logic
      product := &models.Product{
          Code:   req.Code,
          Name:   req.Name,
          Status: models.ProductStatusDraft,  // Business rule: initial status
      }

      // 3. Call repository
      if err := s.productRepo.Create(ctx, product); err != nil {
          return nil, fmt.Errorf("failed to create product: %w", err)
      }

      return product, nil
  }

  // Validation helper
  func (s *ProductService) validateProductCreate(req *models.ProductCreate) error {
      if req.Code == "" {
          return fmt.Errorf("code is required")
      }
      if req.Name == "" {
          return fmt.Errorf("name is required")
      }
      // Add all validation rules from Feature Card
      return nil
  }

  ---
  📌 Task 5: Handlers (internal/handlers/)

  กฎเหล็ก:
  1. ใช้ Gin Framework เท่านั้น (*gin.Context)
  2. ห้ามใช้ net/http handler (http.ResponseWriter, *http.Request)
  3. Response format: ต้องตรงกับ OpenAPI spec

  Template:
  package handlers

  import (
      "net/http"
      "strconv"

      "github.com/gin-gonic/gin"
      "github.com/google/uuid"

      "{{MODULE_PATH_FROM_GO_MOD}}/internal/models"
      "{{MODULE_PATH_FROM_GO_MOD}}/internal/services"
  )

  type ProductHandlerGin struct {  // ใช้ชื่อลงท้าย Gin
      productService *services.ProductService
  }

  func NewProductHandlerGin(svc *services.ProductService) *ProductHandlerGin {
      return &ProductHandlerGin{productService: svc}
  }

  func (h *ProductHandlerGin) CreateProduct(c *gin.Context) {
      var req models.ProductCreate

      // 1. Bind JSON
      if err := c.ShouldBindJSON(&req); err != nil {
          c.JSON(http.StatusBadRequest, gin.H{
              "data":  nil,
              "meta":  nil,
              "error": map[string]interface{}{
                  "message": "Invalid request body",
                  "code":    "INVALID_INPUT",
                  "detail":  err.Error(),
              },
          })
          return
      }

      // 2. Call service
      product, err := h.productService.CreateProduct(c.Request.Context(), &req)
      if err != nil {
          c.JSON(http.StatusInternalServerError, gin.H{
              "data":  nil,
              "meta":  nil,
              "error": map[string]interface{}{
                  "message": "Failed to create product",
                  "code":    "INTERNAL_ERROR",
                  "detail":  err.Error(),
              },
          })
          return
      }

      // 3. Return response (ตาม OpenAPI spec)
      c.JSON(http.StatusCreated, gin.H{
          "data":  product,
          "meta":  nil,
          "error": nil,
      })
  }

  func (h *ProductHandlerGin) GetProduct(c *gin.Context) {
      // Parse UUID from path parameter
      idStr := c.Param("id")
      id, err := uuid.Parse(idStr)  // ถ้า PK เป็น UUID
      if err != nil {
          c.JSON(http.StatusBadRequest, gin.H{
              "data":  nil,
              "meta":  nil,
              "error": map[string]interface{}{
                  "message": "Invalid product ID",
                  "code":    "INVALID_ID",
              },
          })
          return
      }

      product, err := h.productService.GetProduct(c.Request.Context(), id)
      if err != nil {
          c.JSON(http.StatusNotFound, gin.H{
              "data":  nil,
              "meta":  nil,
              "error": map[string]interface{}{
                  "message": "Product not found",
                  "code":    "NOT_FOUND",
              },
          })
          return
      }

      c.JSON(http.StatusOK, gin.H{
          "data":  product,
          "meta":  nil,
          "error": nil,
      })
  }

  ---
  📌 Task 6: Routes (internal/routes/)

  Template:
  package routes

  import (
      "github.com/gin-gonic/gin"
      "{{MODULE_PATH_FROM_GO_MOD}}/internal/handlers"
  )

  func RegisterProductRoutes(r *gin.RouterGroup, h *handlers.ProductHandlerGin) {
      products := r.Group("/products")
      {
          // CRUD endpoints
          products.GET("", h.ListProducts)
          products.POST("", h.CreateProduct)
          products.GET("/:id", h.GetProduct)
          products.PATCH("/:id", h.UpdateProduct)
          products.DELETE("/:id", h.DeleteProduct)

          // Custom endpoints (ตาม OpenAPI spec)
          products.POST("/:id/submit", h.SubmitProduct)
          products.POST("/:id/approve", h.ApproveProduct)
      }
  }

  ---
  📌 Task 7: Dependency Injection (cmd/api/main.go)

  🔴 CRITICAL: ต้อง wire dependencies ให้ครบ

  Template:
  // เพิ่มใน cmd/api/main.go ฟังก์ชัน setupRouter() หรือ main()

  // ===== Product Management ({{FEATURE_CODE}}) =====
  // 1. Initialize all repositories
  productRepo := sqlrepo.NewProductRepository(sqlDB)
  categoryRepo := sqlrepo.NewCategoryRepository(sqlDB)
  productBarcodeRepo := sqlrepo.NewProductBarcodeRepository(sqlDB)
  productAuditRepo := sqlrepo.NewProductAuditRepository(sqlDB)
  // ... create ALL repositories (ต้องครบทุกตัว)

  // 2. Initialize service with all dependencies
  productSvc := services.NewProductService(
      productRepo,
      categoryRepo,
      productBarcodeRepo,
      productAuditRepo,
      // ... inject ALL repositories
  )

  // 3. Initialize handler
  productHandler := handlers.NewProductHandlerGin(productSvc)

  // 4. Register routes
  api := router.Group("/api/v1")
  routes.RegisterProductRoutes(api, productHandler)

  log.Info("✅ {{FEATURE_NAME}} ({{FEATURE_CODE}}) initialized successfully")

  Checklist:
  - ทุก repository ถูกสร้าง (ต้องครบตาม interface ที่มี)
  - Service รับ dependencies ครบ
  - Handler ถูก wire
  - Routes ถูก register
  - มี log message แสดงว่า feature initialized สำเร็จ

  ---
  📌 Task 8: Tests (internal/tests/ หรือ internal/services/tests/)

  Template:
  package tests

  import (
      "context"
      "testing"

      "github.com/stretchr/testify/assert"
      "github.com/stretchr/testify/mock"

      "{{MODULE_PATH_FROM_GO_MOD}}/internal/models"
      "{{MODULE_PATH_FROM_GO_MOD}}/internal/services"
  )

  // Mock repository
  type MockProductRepository struct {
      mock.Mock
  }

  func (m *MockProductRepository) Create(ctx context.Context, p *models.Product) error {
      args := m.Called(ctx, p)
      return args.Error(0)
  }

  // Test case
  func TestCreateProduct(t *testing.T) {
      mockRepo := new(MockProductRepository)
      svc := services.NewProductService(mockRepo)

      // Setup mock
      mockRepo.On("Create", mock.Anything, mock.Anything).Return(nil)

      // Test
      req := &models.ProductCreate{
          Code: "PROD-001",
          Name: "Test Product",
      }

      product, err := svc.CreateProduct(context.Background(), req)

      // Assert
      assert.NoError(t, err)
      assert.NotNil(t, product)
      assert.Equal(t, "PROD-001", product.Code)

      mockRepo.AssertExpectations(t)
  }

  ---
  📌 Task 9: Final Verification (ก่อน Complete)

  🔴 MANDATORY CHECKS:

  # 1. ตรวจสอบ compilation
  ✅ go build ./...
     → ต้องผ่านโดยไม่มี error

  # 2. ตรวจสอบไฟล์ซ้ำ
  ✅ find internal/models -name "*.go" | sort
     → ต้องไม่มีไฟล์ซ้ำ (เช่น product_audit.go และ productaudit.go)

  # 3. ตรวจสอบ import paths
  ✅ grep -r "\"Inventory/" internal/
     → ต้องไม่มีผลลัพธ์ (ห้ามใช้ invalid import)

  ✅ grep -r "go-backend-api" internal/
     → ต้องไม่มีผลลัพธ์ (ห้ามใช้ old import path)

  # 4. ตรวจสอบ repository implementations
  ✅ ls internal/repositories/*.go | wc -l
  ✅ ls internal/repositories/sql/*.go | wc -l
     → จำนวนต้องเท่ากัน (interface และ implementation ต้องครบคู่)

  # 5. รัน tests (ถ้ามี)
  ✅ go test ./... -v
     → ต้องผ่านหรืออย่างน้อย compile ได้

  ถ้า checks ข้างบนผ่านทั้งหมด → พร้อม completeถ้าไม่ผ่าน → กลับไปแก้ไขก่อน

  ---
  📋 Manifest Update

  เมื่อทำครบทุก task และผ่าน verification แล้ว อัปเดต manifest:

  {
    "feature_code": "{{FEATURE_CODE}}",
    "phase": "build_completed",
    "checked_at": "{{TIMESTAMP}}",
    "outputs": {
      "models": ["product.go", "category.go", ...],
      "repositories": ["product_repository.go", ...],
      "repositories_sql": ["product_repository.go", "category_repository.go", ...],
      "services": ["product_service.go"],
      "handlers": ["product_handler_gin.go"],
      "routes": ["product_routes.go"],
      "tests": ["product_service_test.go"]
    },
    "files_created": {
      "models": 8,
      "repository_interfaces": 8,
      "repository_implementations_sql": 8,  // ต้องเท่ากับ interfaces
      "services": 1,
      "handlers": 1,
      "routes": 1,
      "tests": 1,
      "total": 36
    },
    "compilation_status": "success",  // ✅ ต้องเป็น success
    "build_command": "go build ./...",
    "build_result": "PASS"
  }

  ---
  ⚠️ สิ่งที่ต้องห้ามทำ

  1. ❌ ห้ามสร้างไฟล์ชื่อย่อ เช่น productdoc.go, productuomconv.go
    - ✅ ใช้: product_document.go, product_uom_conversion.go
  2. ❌ ห้ามใช้ import path ที่ไม่ตรงกับ go.mod
    - ✅ อ่าน go.mod ก่อนเสมอ
    - ✅ ใช้ module path จาก go.mod ทุกครั้ง
  3. ❌ ห้ามสร้าง repository stub อย่างเดียว
    - ✅ ต้องสร้าง SQL implementation ครบทุกไฟล์
  4. ❌ ห้ามใช้ http.ResponseWriter กับ *http.Request ใน handler
    - ✅ ใช้ *gin.Context เท่านั้น
  5. ❌ ห้ามสร้าง model โดยไม่อ่าน SQL schema
    - ✅ อ่าน schema ก่อน แล้วจับคู่ field ทุกตัว
  6. ❌ ห้ามใช้ int64 ID ถ้า SQL schema ใช้ UUID
    - ✅ ตรวจสอบ primary key type จาก SQL schema
  7. ❌ ห้ามลืมเพิ่ม dependency injection ใน main.go
    - ✅ Wire ทุก repository → service → handler → routes

  ---
  ✅ Definition of Done

  Feature ถือว่า Build & Integrate เสร็จสมบูรณ์ เมื่อ:

  - อ่าน go.mod และใช้ module path ถูกต้อง
  - อ่าน SQL schema และ model ตรงทุก field
  - สร้างไฟล์ครบทุก layer (models, repos, services, handlers, routes)
  - Repository implementations ครบทุก interface
  - ไม่มีไฟล์ซ้ำในโปรเจค
  - go build ./... ผ่านโดยไม่มี error
  - Handler ใช้ Gin framework
  - Routes ถูก register ใน main.go
  - Dependencies ถูก wire ครบ
  - มี tests อย่างน้อย 1 test case ต่อ service
  - Manifest ถูกอัปเดต

  ---
  🎓 เมื่อเจอปัญหา

  Problem: "no required module provides package X"

  Solution:
  1. อ่าน go.mod อีกครั้ง
  2. แก้ import path ให้ตรงกับ module path
  3. ใช้ {{MODULE_PATH}} จาก go.mod

  Problem: "redeclared in this package"

  Solution:
  1. ตรวจสอบไฟล์ซ้ำใน directory
  2. ลบไฟล์ที่ชื่อผิดรูปแบบ (ไม่ใช่ snake_case)
  3. เก็บแค่ไฟล์ที่ถูกต้อง

  Problem: "cannot use X (type int64) as type uuid.UUID"

  Solution:
  1. อ่าน SQL schema อีกครั้ง
  2. ตรวจสอบ primary key type
  3. แก้ model ให้ตรงกับ schema