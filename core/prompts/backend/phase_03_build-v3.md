# 🔨 Phase 03: Build & Integration - ฉบับสมบูรณ์

**สำหรับ Feature:** `{FEATURE_CODE}`
**เป้าหมาย:** สร้าง Models, Services, Handlers ที่ตรงกับ SQL Schema จาก Phase 01 และทดสอบการทำงาน

---

## 🎯 เป้าหมายหลัก

1. ✅ **สร้าง Go Models ที่ตรงกับ SQL Schema 100%**
2. ✅ **สร้าง Repository Interfaces และ Mock Implementations**
3. ✅ **สร้าง Service Layer พร้อม Business Logic**
4. ✅ **สร้าง HTTP Handlers สำหรับ REST API**
5. ✅ **ทดสอบการ Compile ทั้งหมดผ่าน**
6. ✅ **อัปเดต Manifest ด้วยสถานะและไฟล์ที่สร้าง**

---

## ⚠️ กฎสำคัญที่สุด: SCHEMA-FIRST APPROACH

```
┌─────────────────────────────────────────────────────────┐
│  ❌ อย่าสร้าง Models จากความเข้าใจหรือ Best Practices    │
│  ✅ ให้อ่าน SQL Schema จาก Phase 01 ก่อนเสมอ             │
│                                                         │
│  SQL Schema = Source of Truth                          │
└─────────────────────────────────────────────────────────┘
```

### สาเหตุที่ต้องอ่าน SQL Schema ก่อน:

❌ **ถ้าไม่อ่าน Schema จะเกิดปัญหา:**
- Models ใช้ `int64` แต่ Database ใช้ `UUID` → Runtime Error
- Field name ไม่ตรงกัน (SQL: `hazardous` vs Go: `IsHazardous`) → Query Fail
- Foreign key name ผิด (SQL: `category_row_id` vs Go: `CategoryID`) → Relation Error

✅ **ถ้าอ่าน Schema ก่อน:**
- Type ตรงกัน 100%
- Field name ตรงกันทุกตัว
- Build ผ่านครั้งแรก
- Integration ทำงานได้ทันที

---

## 📋 ขั้นตอนการทำงาน (บังคับตามลำดับ)

### **ขั้นตอน 0: เตรียมความพร้อม** (MANDATORY)

```bash
# 1. อ่านไฟล์ Manifest เพื่อดูสถานะ Phase ก่อนหน้า
Read: /path/to/manifest/{FEATURE_CODE}.json

# 2. อ่าน SQL Schema ที่สร้างใน Phase 01 (บังคับ!)
Read: /path/to/migrations/{timestamp}_create_{FEATURE_CODE}_schema.sql

# 3. อ่าน OpenAPI Spec (ถ้ามี)
Read: /path/to/docs/api/{FEATURE_CODE}-*-openapi.yaml

# 4. อ่าน Feature Card
Read: /path/to/features/{FEATURE_CODE}.md
```

### **ขั้นตอน 1: สร้าง SQL → Go Type Mapping Table** (MANDATORY)

สร้างตารางแมป Type ระหว่าง SQL และ Go **ก่อนเขียน Code**

**ตัวอย่างตาราง Mapping:**

```markdown
| SQL Table | SQL Column Name | SQL Type | Go Struct | Go Field Name | Go Type | Tags |
|-----------|----------------|----------|-----------|---------------|---------|------|
| products | row_id | UUID | Product | RowID | uuid.UUID | `json:"row_id" db:"row_id"` |
| products | id | VARCHAR(14) | Product | ID | string | `json:"id" db:"id"` |
| products | category_row_id | UUID (FK) | Product | CategoryRowID | *uuid.UUID | `json:"category_row_id,omitempty" db:"category_row_id"` |
| products | name | VARCHAR(255) | Product | Name | string | `json:"name" db:"name"` |
| products | hazardous | BOOLEAN | Product | Hazardous | bool | `json:"hazardous" db:"hazardous"` |
| products | unit_cost | DECIMAL(15,4) | Product | UnitCost | decimal.Decimal | `json:"unit_cost" db:"unit_cost"` |
| products | metadata | JSONB | Product | Metadata | JSONBMap | `json:"metadata,omitempty" db:"metadata"` |
| products | created_at | TIMESTAMP | Product | CreatedAt | time.Time | `json:"created_at" db:"created_at"` |
| products | updated_at | TIMESTAMP | Product | UpdatedAt | time.Time | `json:"updated_at" db:"updated_at"` |
```

**📝 กฎการแปลง Type:**

| PostgreSQL Type | Go Type | Import Package | หมายเหตุ |
|----------------|---------|----------------|---------|
| `UUID` | `uuid.UUID` | `github.com/google/uuid` | ใช้สำหรับ Primary Key (row_id) |
| `UUID` (nullable) | `*uuid.UUID` | `github.com/google/uuid` | ใช้สำหรับ Foreign Key |
| `VARCHAR(n)` | `string` | - | |
| `TEXT` | `string` | - | |
| `INTEGER` | `int` | - | สำหรับค่าทั่วไป |
| `BIGINT` | `int64` | - | สำหรับค่าที่ใหญ่มาก |
| `DECIMAL(p,s)` | `decimal.Decimal` | `github.com/shopspring/decimal` | สำหรับเงิน/ตัวเลขที่ต้องแม่นยำ |
| `BOOLEAN` | `bool` | - | |
| `TIMESTAMP` | `time.Time` | `time` | |
| `JSONB` | `JSONBMap` | custom type | ต้องมี Scan/Value methods |
| `ENUM(...)` | `string` | - | ใช้ string + validation |

**🔍 กฎการตั้งชื่อ Field:**

```go
// ✅ ถูกต้อง - ตรงกับ SQL Schema
type Product struct {
    RowID         uuid.UUID  `json:"row_id" db:"row_id"`           // SQL: row_id
    CategoryRowID *uuid.UUID `json:"category_row_id" db:"category_row_id"` // SQL: category_row_id
    Hazardous     bool       `json:"hazardous" db:"hazardous"`     // SQL: hazardous
    Preferred     bool       `json:"preferred" db:"preferred"`     // SQL: preferred
}

// ❌ ผิด - ไม่ตรงกับ SQL
type Product struct {
    ID         int64  `json:"id"`              // SQL uses UUID for row_id
    CategoryID *int64 `json:"category_id"`     // SQL: category_row_id (UUID)
    IsHazardous bool  `json:"is_hazardous"`    // SQL: hazardous (no "is_")
    IsPreferred bool  `json:"is_preferred"`    // SQL: preferred (no "is_")
}
```

**📌 กฎ Foreign Key Naming:**

```
SQL Pattern:     {table_name}_row_id
Go Pattern:      {TableName}RowID *uuid.UUID

ตัวอย่าง:
SQL:  category_row_id  →  Go: CategoryRowID  *uuid.UUID
SQL:  supplier_row_id  →  Go: SupplierRowID  *uuid.UUID
SQL:  warehouse_row_id →  Go: WarehouseRowID *uuid.UUID
```

---

### **ขั้นตอน 2: สร้าง Models** (`internal/models/`)

สร้าง Go Structs ตามตาราง Mapping ที่สร้างในขั้นตอน 1

#### 2.1 สร้าง Main Model File

**ไฟล์:** `internal/models/{feature}.go` (เช่น `product.go`)

```go
package models

import (
    "time"
    "github.com/google/uuid"
    "github.com/shopspring/decimal"
)

// Product represents a product in the inventory system
type Product struct {
    // Primary Keys - ต้องตรงกับ SQL Schema
    RowID uuid.UUID `json:"row_id" db:"row_id"`                    // Internal UUID (PK)
    ID    string    `json:"id" db:"id"`                            // Public ID (PRD-0000000001)

    // Foreign Keys - ใช้ *uuid.UUID และตั้งชื่อตาม SQL pattern
    CategoryRowID *uuid.UUID `json:"category_row_id,omitempty" db:"category_row_id"`

    // Basic Fields - ชื่อต้องตรงกับ SQL column name (PascalCase)
    Name        string          `json:"name" db:"name"`
    Description string          `json:"description" db:"description"`
    Hazardous   bool            `json:"hazardous" db:"hazardous"`   // ไม่ใช่ IsHazardous!
    Preferred   bool            `json:"preferred" db:"preferred"`   // ไม่ใช่ IsPreferred!

    // Decimal Fields
    UnitCost   decimal.Decimal `json:"unit_cost" db:"unit_cost"`
    UnitPrice  decimal.Decimal `json:"unit_price" db:"unit_price"`

    // JSONB Fields
    Metadata   JSONBMap        `json:"metadata,omitempty" db:"metadata"`

    // Audit Fields
    Status     string          `json:"status" db:"status"`
    CreatedAt  time.Time       `json:"created_at" db:"created_at"`
    CreatedBy  string          `json:"created_by" db:"created_by"`
    UpdatedAt  time.Time       `json:"updated_at" db:"updated_at"`
    UpdatedBy  string          `json:"updated_by" db:"updated_by"`
}

// ProductCreate is used for creating new products
type ProductCreate struct {
    CategoryRowID *uuid.UUID      `json:"category_row_id"`
    Name          string          `json:"name" binding:"required"`
    Description   string          `json:"description"`
    Type          string          `json:"type" binding:"required,oneof=physical service"`
    Hazardous     bool            `json:"hazardous"`
    UnitCost      decimal.Decimal `json:"unit_cost"`
    UnitPrice     decimal.Decimal `json:"unit_price"`
}

// ProductUpdate is used for updating existing products
type ProductUpdate struct {
    Name        *string          `json:"name"`
    Description *string          `json:"description"`
    Hazardous   *bool            `json:"hazardous"`
    UnitCost    *decimal.Decimal `json:"unit_cost"`
    UnitPrice   *decimal.Decimal `json:"unit_price"`
}
```

#### 2.2 สร้าง Custom Types (ถ้าจำเป็น)

**ไฟล์:** `internal/models/types.go` หรือในไฟล์ที่เกี่ยวข้อง

```go
package models

import (
    "database/sql/driver"
    "encoding/json"
    "errors"
)

// JSONBMap represents a JSONB map field in PostgreSQL
type JSONBMap map[string]interface{}

// Scan implements sql.Scanner interface for reading from database
func (j *JSONBMap) Scan(value interface{}) error {
    if value == nil {
        *j = make(JSONBMap)
        return nil
    }

    bytes, ok := value.([]byte)
    if !ok {
        return errors.New("failed to scan JSONBMap: not a byte slice")
    }

    return json.Unmarshal(bytes, j)
}

// Value implements driver.Valuer interface for writing to database
func (j JSONBMap) Value() (driver.Value, error) {
    if j == nil {
        return nil, nil
    }
    return json.Marshal(j)
}
```

#### 2.3 เพิ่ม Type Aliases (ถ้าจำเป็น)

**ไฟล์:** `internal/models/common.go`

```go
package models

// PaginationMeta is an alias for Pagination (for backward compatibility)
type PaginationMeta = Pagination

// Pagination contains pagination information
type Pagination struct {
    Page       int   `json:"page"`
    Limit      int   `json:"limit"`
    Total      int64 `json:"total"`
    TotalPages int64 `json:"total_pages"`
}
```

---

### **ขั้นตอน 3: สร้าง Repository Interfaces** (`internal/repositories/`)

สร้าง Repository interfaces ที่ใช้ UUID และตรงกับ naming convention

**ไฟล์:** `internal/repositories/{feature}_repository.go`

```go
package repositories

import (
    "context"
    "github.com/google/uuid"
    "your-project/internal/models"
)

// ProductRepository defines the interface for product data access
type ProductRepository interface {
    // CRUD Operations - ใช้ uuid.UUID สำหรับ row_id
    Create(ctx context.Context, product *models.Product) error
    GetByRowID(ctx context.Context, rowID uuid.UUID) (*models.Product, error)  // ไม่ใช่ GetByID!
    GetByID(ctx context.Context, id string) (*models.Product, error)            // สำหรับ public ID
    Update(ctx context.Context, product *models.Product) error
    Delete(ctx context.Context, rowID uuid.UUID) error

    // Status Management
    UpdateStatus(ctx context.Context, rowID uuid.UUID, status string) error

    // Query Operations
    List(ctx context.Context, filters ProductFilters) ([]*models.Product, int64, error)
    Search(ctx context.Context, query string) ([]*models.Product, error)
}

// ProductFilters defines filter options for querying products
type ProductFilters struct {
    Query         string
    Type          string
    Tracking      string
    Status        []string
    CategoryRowID *uuid.UUID  // ไม่ใช่ CategoryID!
    Page          int
    Limit         int
    Sort          string
}

// Mock implementation for testing
type MockProductRepository struct {
    CreateFunc         func(ctx context.Context, product *models.Product) error
    GetByRowIDFunc     func(ctx context.Context, rowID uuid.UUID) (*models.Product, error)
    UpdateStatusFunc   func(ctx context.Context, rowID uuid.UUID, status string) error
    // ... other methods
}

func (m *MockProductRepository) GetByRowID(ctx context.Context, rowID uuid.UUID) (*models.Product, error) {
    if m.GetByRowIDFunc != nil {
        return m.GetByRowIDFunc(ctx, rowID)
    }
    return nil, nil
}
```

**🔍 Naming Convention สำหรับ Repository Methods:**

```
✅ GetByRowID(rowID uuid.UUID)  - สำหรับ internal UUID
✅ GetByID(id string)            - สำหรับ public ID (PRD-0000000001)

❌ GetByID(id int64)             - ผิด! ไม่ใช้ int64
❌ GetByProductID(...)           - สับสน, ใช้ GetByRowID แทน
```

---

### **ขั้นตอน 4: สร้าง Service Layer** (`internal/services/`)

สร้าง Business Logic Layer ที่ใช้ UUID และเรียก Repository ด้วยชื่อที่ถูกต้อง

**ไฟล์:** `internal/services/{feature}_service.go`

```go
package services

import (
    "context"
    "fmt"
    "github.com/google/uuid"
    "your-project/internal/models"
    "your-project/internal/repositories"
)

// ProductService handles product business logic
type ProductService struct {
    productRepo repositories.ProductRepository
    auditRepo   repositories.ProductAuditRepository
}

// NewProductService creates a new product service
func NewProductService(
    productRepo repositories.ProductRepository,
    auditRepo repositories.ProductAuditRepository,
) *ProductService {
    return &ProductService{
        productRepo: productRepo,
        auditRepo:   auditRepo,
    }
}

// GetProduct retrieves a product by its row_id (UUID)
func (s *ProductService) GetProduct(ctx context.Context, rowID uuid.UUID) (*models.Product, error) {
    // ✅ เรียก GetByRowID ไม่ใช่ GetByID
    return s.productRepo.GetByRowID(ctx, rowID)
}

// UpdateProduct updates a product
func (s *ProductService) UpdateProduct(
    ctx context.Context,
    rowID uuid.UUID,  // ✅ ใช้ uuid.UUID
    update *models.ProductUpdate,
    actor string,
) (*models.Product, error) {
    // Get existing product
    product, err := s.productRepo.GetByRowID(ctx, rowID)  // ✅ GetByRowID
    if err != nil {
        return nil, err
    }

    // Apply updates
    if update.Name != nil {
        product.Name = *update.Name
    }
    if update.Hazardous != nil {  // ✅ ใช้ Hazardous ไม่ใช่ IsHazardous
        product.Hazardous = *update.Hazardous
    }

    // Update in database
    if err := s.productRepo.Update(ctx, product); err != nil {
        return nil, err
    }

    return product, nil
}

// ListProducts lists products with filters
func (s *ProductService) ListProducts(
    ctx context.Context,
    filters repositories.ProductFilters,
) ([]*models.Product, int64, error) {
    // ตรวจสอบว่า filters.CategoryRowID เป็น *uuid.UUID
    return s.productRepo.List(ctx, filters)
}

// SubmitProduct changes product status to "pending_approval"
func (s *ProductService) SubmitProduct(
    ctx context.Context,
    rowID uuid.UUID,  // ✅ uuid.UUID
    actor string,
    comment string,
) error {
    // Validate current status
    product, err := s.productRepo.GetByRowID(ctx, rowID)
    if err != nil {
        return err
    }

    if product.Status != "draft" {
        return fmt.Errorf("can only submit products in draft status")
    }

    // Update status
    return s.productRepo.UpdateStatus(ctx, rowID, "pending_approval")
}
```

**⚠️ Common Mistakes to Avoid:**

```go
// ❌ ผิด - ใช้ int64
func (s *ProductService) GetProduct(ctx context.Context, id int64) (*models.Product, error) {
    return s.productRepo.GetByID(ctx, id)  // Method ไม่มีสำหรับ int64
}

// ❌ ผิด - ใช้ field name ผิด
product.IsHazardous = true  // Field นี้ไม่มี, ต้องใช้ product.Hazardous

// ❌ ผิด - เรียก method ผิด
s.productRepo.GetByID(ctx, rowID)  // GetByID รับ string, ไม่ใช่ UUID

// ✅ ถูกต้อง
func (s *ProductService) GetProduct(ctx context.Context, rowID uuid.UUID) (*models.Product, error) {
    return s.productRepo.GetByRowID(ctx, rowID)
}
```

---

### **ขั้นตอน 5: สร้าง HTTP Handlers** (`internal/handlers/`)

สร้าง Gin handlers ที่รับ UUID จาก URL parameters

**ไฟล์:** `internal/handlers/{feature}_handler.go`

```go
package handlers

import (
    "net/http"
    "strconv"

    "github.com/gin-gonic/gin"
    "github.com/google/uuid"

    "your-project/internal/models"
    "your-project/internal/repositories"
    "your-project/internal/services"
)

// ProductHandler handles HTTP requests for products
type ProductHandler struct {
    productService *services.ProductService
}

// NewProductHandler creates a new product handler
func NewProductHandler(productService *services.ProductService) *ProductHandler {
    return &ProductHandler{
        productService: productService,
    }
}

// GetProduct handles GET /api/v1/products/:id
func (h *ProductHandler) GetProduct(c *gin.Context) {
    // ✅ Parse UUID from URL parameter
    rowID, err := uuid.Parse(c.Param("id"))
    if err != nil {
        c.JSON(http.StatusBadRequest, APIResponse{
            Error: ErrorDetail{Code: "INVALID_ID", Message: "Invalid product ID"},
        })
        return
    }

    // ✅ เรียก service ด้วย uuid.UUID
    product, err := h.productService.GetProduct(c.Request.Context(), rowID)
    if err != nil {
        c.JSON(http.StatusNotFound, APIResponse{
            Error: ErrorDetail{Code: "NOT_FOUND", Message: "Product not found"},
        })
        return
    }

    c.JSON(http.StatusOK, APIResponse{
        Data: product,
    })
}

// ListProducts handles GET /api/v1/products
func (h *ProductHandler) ListProducts(c *gin.Context) {
    filters := repositories.ProductFilters{
        Query:    c.Query("q"),
        Type:     c.Query("type"),
        Status:   c.QueryArray("status"),
        Page:     1,
        Limit:    20,
        Sort:     c.DefaultQuery("sort", "-updated_at"),
    }

    // Parse pagination
    if page := c.Query("page"); page != "" {
        if p, err := strconv.Atoi(page); err == nil {
            filters.Page = p
        }
    }

    // ✅ Parse category_row_id as UUID
    if categoryID := c.Query("category_id"); categoryID != "" {
        if id, err := uuid.Parse(categoryID); err == nil {
            filters.CategoryRowID = &id  // ✅ CategoryRowID ไม่ใช่ CategoryID
        }
    }

    products, total, err := h.productService.ListProducts(c.Request.Context(), filters)
    if err != nil {
        c.JSON(http.StatusInternalServerError, APIResponse{
            Error: ErrorDetail{Code: "INTERNAL_ERROR", Message: err.Error()},
        })
        return
    }

    c.JSON(http.StatusOK, APIResponse{
        Data: products,
        Meta: PaginationMeta{
            Page:  filters.Page,
            Limit: filters.Limit,
            Total: total,
        },
    })
}

// UpdateProduct handles PATCH /api/v1/products/:id
func (h *ProductHandler) UpdateProduct(c *gin.Context) {
    // ✅ Parse UUID
    rowID, err := uuid.Parse(c.Param("id"))
    if err != nil {
        c.JSON(http.StatusBadRequest, APIResponse{
            Error: ErrorDetail{Code: "INVALID_ID", Message: "Invalid product ID"},
        })
        return
    }

    var update models.ProductUpdate
    if err := c.ShouldBindJSON(&update); err != nil {
        c.JSON(http.StatusBadRequest, APIResponse{
            Error: ErrorDetail{Code: "INVALID_REQUEST", Message: err.Error()},
        })
        return
    }

    actor := c.GetString("user_email")
    if actor == "" {
        actor = "system"
    }

    // ✅ เรียก service ด้วย UUID
    product, err := h.productService.UpdateProduct(c.Request.Context(), rowID, &update, actor)
    if err != nil {
        c.JSON(http.StatusBadRequest, APIResponse{
            Error: ErrorDetail{Code: "UPDATE_FAILED", Message: err.Error()},
        })
        return
    }

    c.JSON(http.StatusOK, APIResponse{
        Data: product,
    })
}

// APIResponse represents standard API response
type APIResponse struct {
    Data  interface{} `json:"data"`
    Meta  interface{} `json:"meta"`
    Error interface{} `json:"error"`
}

// ErrorDetail represents error details
type ErrorDetail struct {
    Message string `json:"message"`
    Code    string `json:"code"`
    Detail  string `json:"detail,omitempty"`
}

// PaginationMeta represents pagination metadata
type PaginationMeta struct {
    Page  int   `json:"page"`
    Limit int   `json:"limit"`
    Total int64 `json:"total"`
}
```

**⚠️ Handler Common Mistakes:**

```go
// ❌ ผิด - Parse เป็น int64
id, err := strconv.ParseInt(c.Param("id"), 10, 64)

// ❌ ผิด - ใช้ field name ผิด
filters.CategoryID = &id  // ต้องเป็น CategoryRowID

// ✅ ถูกต้อง - Parse UUID
rowID, err := uuid.Parse(c.Param("id"))
filters.CategoryRowID = &rowID
```

---

### **ขั้นตอน 6: ทดสอบการ Compile** (MANDATORY)

**ต้องทดสอบก่อนถือว่าเสร็จสิ้น Phase 03**

```bash
# Test 1: Build Models
go build ./internal/models
# ต้องผ่าน - ไม่มี error

# Test 2: Build Repositories
go build ./internal/repositories
# ต้องผ่าน - ไม่มี error

# Test 3: Build Services
go build ./internal/services
# ต้องผ่าน - ไม่มี error

# Test 4: Build Handlers
go build ./internal/handlers
# ต้องผ่าน - ไม่มี error

# Test 5: Build ทั้ง project
go build ./...
# ต้องผ่าน - ไม่มี error
```

**ถ้า Build ไม่ผ่าน:**
1. อ่าน error message ให้ละเอียด
2. ตรวจสอบว่าใช้ Type ถูกต้องตามตาราง Mapping หรือไม่
3. ตรวจสอบว่า Field name ตรงกับ SQL Schema หรือไม่
4. ตรวจสอบว่า Import packages ครบหรือไม่
5. แก้ไขและทดสอบใหม่จนกว่าจะผ่าน

---

### **ขั้นตอน 7: Validation Checklist** (MANDATORY)

ก่อนถือว่า Phase 03 เสร็จสิ้น ต้องตรวจสอบทุกข้อให้ผ่าน:

#### ✅ Models Validation

- [ ] ทุก Primary Key ใช้ `uuid.UUID` ตรงกับ SQL `UUID`
- [ ] ทุก Foreign Key ใช้ `*uuid.UUID` และตั้งชื่อ `{Table}RowID`
- [ ] Field name ตรงกับ SQL column name (PascalCase vs snake_case)
- [ ] ไม่มี prefix "Is" สำหรับ boolean fields (เช่น `Hazardous` ไม่ใช่ `IsHazardous`)
- [ ] DECIMAL fields ใช้ `decimal.Decimal` ไม่ใช่ `float64`
- [ ] JSONB fields มี Custom Type พร้อม Scan/Value methods
- [ ] ทุก struct มี json และ db tags ครบ
- [ ] Models มี Create และ Update DTOs

#### ✅ Repository Validation

- [ ] Interface มี method `GetByRowID(ctx, rowID uuid.UUID)` ไม่ใช่ `GetByID(ctx, id int64)`
- [ ] Interface มี method `GetByID(ctx, id string)` สำหรับ public ID
- [ ] Filter structs ใช้ `*uuid.UUID` สำหรับ foreign key filters
- [ ] Filter structs ตั้งชื่อ FK field เป็น `{Table}RowID`
- [ ] Mock implementation มีครบทุก method

#### ✅ Service Validation

- [ ] ทุก method signature ใช้ `uuid.UUID` สำหรับ row_id parameter
- [ ] เรียก repository ด้วย `GetByRowID()` ไม่ใช่ `GetByID()` สำหรับ UUID
- [ ] ใช้ field name ที่ถูกต้อง (เช่น `product.Hazardous` ไม่ใช่ `product.IsHazardous`)
- [ ] Business logic ครบตาม Feature Card
- [ ] Error handling ครบถ้วน

#### ✅ Handler Validation

- [ ] Parse UUID parameter ด้วย `uuid.Parse(c.Param("id"))`
- [ ] ไม่ใช้ `strconv.ParseInt()` สำหรับ row_id
- [ ] Query parameter `category_id` ถูก parse เป็น UUID
- [ ] Filter struct ใช้ `CategoryRowID` ไม่ใช่ `CategoryID`
- [ ] Response format ตาม API spec
- [ ] Error handling ครบทุก case

#### ✅ Build Validation

- [ ] `go build ./internal/models` - PASS
- [ ] `go build ./internal/repositories` - PASS
- [ ] `go build ./internal/services` - PASS
- [ ] `go build ./internal/handlers` - PASS
- [ ] `go build ./...` - PASS
- [ ] ไม่มี compilation errors
- [ ] ไม่มี import errors

---

### **ขั้นตอน 8: อัปเดต Manifest** (MANDATORY)

อัปเดตไฟล์ Manifest ด้วยผลลัพธ์จาก Phase 03

**ไฟล์:** `/path/to/manifest/{FEATURE_CODE}.json`

```json
{
  "feature_code": "PROD001",
  "phases": {
    "03_build": {
      "status": "completed",
      "started_at": "2025-11-09T10:00:00Z",
      "completed_at": "2025-11-09T12:00:00Z",
      "files_created": [
        "internal/models/product.go",
        "internal/models/product_barcode.go",
        "internal/models/product_audit.go",
        "internal/models/types.go",
        "internal/repositories/product_repository.go",
        "internal/repositories/mock_product_repository.go",
        "internal/services/product_service.go",
        "internal/handlers/product_handler.go"
      ],
      "build_tests": {
        "models": "PASS",
        "repositories": "PASS",
        "services": "PASS",
        "handlers": "PASS",
        "full_build": "PASS"
      },
      "validation_checklist": {
        "schema_mapping_created": true,
        "uuid_types_correct": true,
        "field_names_correct": true,
        "repository_methods_correct": true,
        "service_signatures_correct": true,
        "handler_parsing_correct": true,
        "all_builds_pass": true
      },
      "notes": [
        "Schema-first approach used - all types match SQL schema 100%",
        "UUID migration completed successfully",
        "All field names verified against SQL schema",
        "Repository methods use GetByRowID for UUID lookups",
        "All compilation tests passed"
      ]
    }
  }
}
```

---

## 🎯 Success Criteria

Phase 03 ถือว่าสำเร็จเมื่อ:

1. ✅ **Type Mapping Table สร้างเสร็จ** - แมป SQL → Go ครบทุก column
2. ✅ **Models ถูกต้อง 100%** - ตรงกับ SQL Schema ทุก field
3. ✅ **Repository Interfaces ถูกต้อง** - ใช้ UUID และ naming convention ที่ถูกต้อง
4. ✅ **Services ถูกต้อง** - เรียก repository methods ที่ถูกต้อง, ใช้ field names ที่ถูกต้อง
5. ✅ **Handlers ถูกต้อง** - Parse UUID จาก parameters, ใช้ filter fields ที่ถูกต้อง
6. ✅ **Build Tests ผ่านทั้งหมด** - ไม่มี compilation errors
7. ✅ **Validation Checklist ผ่านครบ** - ตรวจสอบทุกข้อแล้ว
8. ✅ **Manifest อัปเดตแล้ว** - บันทึกไฟล์ที่สร้างและสถานะ

---

## 📚 Reference Quick Guide

### Type Mapping Quick Reference

```
UUID (PK)        →  uuid.UUID
UUID (FK)        →  *uuid.UUID
VARCHAR(n)       →  string
DECIMAL(p,s)     →  decimal.Decimal
BOOLEAN          →  bool
TIMESTAMP        →  time.Time
JSONB            →  JSONBMap (custom type)
```

### Naming Convention Quick Reference

```
SQL Column           Go Field Name        Type
-------------------------------------------------
row_id               RowID                uuid.UUID
id                   ID                   string
category_row_id      CategoryRowID        *uuid.UUID
hazardous            Hazardous            bool (not IsHazardous)
preferred            Preferred            bool (not IsPreferred)
unit_cost            UnitCost             decimal.Decimal
metadata             Metadata             JSONBMap
```

### Repository Method Quick Reference

```
GetByRowID(rowID uuid.UUID)    - สำหรับ internal UUID lookup
GetByID(id string)              - สำหรับ public ID lookup (PRD-0000000001)
UpdateStatus(rowID uuid.UUID)   - ใช้ UUID
Delete(rowID uuid.UUID)         - ใช้ UUID
```

---

## 🚨 Common Errors และวิธีแก้

### Error 1: undefined: JSONBMap

**สาเหตุ:** ไม่ได้สร้าง custom type สำหรับ JSONB

**วิธีแก้:**
```go
// สร้างใน internal/models/types.go
type JSONBMap map[string]interface{}

func (j *JSONBMap) Scan(value interface{}) error { ... }
func (j JSONBMap) Value() (driver.Value, error) { ... }
```

### Error 2: cannot use rowID (variable of type uuid.UUID) as int64

**สาเหตุ:** Service/Handler ยังใช้ int64 แทน uuid.UUID

**วิธีแก้:**
```go
// ❌ Before
func (s *Service) GetProduct(ctx context.Context, id int64)

// ✅ After
func (s *Service) GetProduct(ctx context.Context, rowID uuid.UUID)
```

### Error 3: product.IsHazardous undefined

**สาเหตุ:** Field name ไม่ตรงกับ SQL Schema

**วิธีแก้:**
```go
// SQL: hazardous BOOLEAN
// ❌ Wrong: IsHazardous bool
// ✅ Correct: Hazardous bool
```

### Error 4: productRepo.GetByID undefined (argument type uuid.UUID)

**สาเหตุ:** เรียก method ผิด - GetByID รับ string ไม่ใช่ UUID

**วิธีแก้:**
```go
// ❌ Wrong
product, err := repo.GetByID(ctx, rowID) // rowID is uuid.UUID

// ✅ Correct
product, err := repo.GetByRowID(ctx, rowID) // GetByRowID รับ UUID
```

---

## ✅ Final Checklist

ก่อนส่งมอบ Phase 03:

- [ ] อ่าน SQL Schema จาก Phase 01 แล้ว
- [ ] สร้าง Type Mapping Table แล้ว
- [ ] สร้าง Models ตาม Mapping Table แล้ว
- [ ] สร้าง Repository Interfaces แล้ว (ใช้ GetByRowID)
- [ ] สร้าง Services แล้ว (ใช้ uuid.UUID)
- [ ] สร้าง Handlers แล้ว (Parse UUID จาก params)
- [ ] รัน `go build ./internal/models` - PASS
- [ ] รัน `go build ./internal/services` - PASS
- [ ] รัน `go build ./internal/handlers` - PASS
- [ ] รัน `go build ./...` - PASS
- [ ] ตรวจสอบ Validation Checklist ครบทุกข้อ
- [ ] อัปเดต Manifest แล้ว

---

**Phase 03 เสร็จสมบูรณ์! พร้อมไปต่อที่ Phase 04: QA & Validation** ✨
