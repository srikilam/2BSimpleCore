# 🧪 QA Report — Feature: Cane Receive (CNRC001)

**Module:** AGM
**Sprint:** 01
**Reviewed by:** Claude QA Agent
**Review Date:** 2025-11-18

---

## ✅ Summary

Feature CNRC001 (Cane Receive) พบปัญหาร้ายแรงหลายจุดที่ต้องแก้ไขก่อนการปล่อยใช้งาน:

1. **❌ CRITICAL:** ไม่มี test coverage สำหรับ CNRC001 (0% coverage) - ระบบ build fail จาก test cases ของ module อื่น
2. **⚠️ MAJOR:** Service layer ยังไม่ implement side-effects สำคัญ (weigh-coin free, CBM status update, EventBus emission, PDF generation)
3. **⚠️ MAJOR:** ไม่มี idempotency key storage/check implementation - อาจเกิด duplicate receiving notes
4. **⚠️ MAJOR:** ไม่มี payment linkage detection ใน void operation - อาจ void ได้แม้ว่ามี payment แล้ว
5. **⚠️ MODERATE:** Factory API integration ยังไม่ implement - auto-fetch mode ใช้งานไม่ได้
6. **⚠️ MODERATE:** CSV export และ PDF generation services ยังไม่มีการ implement
7. **✅ PASSED:** Schema consistency ระหว่าง SQL → Model → API ถูกต้อง สอดคล้องกัน
8. **✅ PASSED:** Naming conventions ตรงตาม standards (snake_case สำหรับ DB, PascalCase สำหรับ structs)

**Recommendation:** ❌ **NOT READY FOR PRODUCTION** - ต้องแก้ไข Critical และ Major issues ก่อนปล่อยใช้งาน

---

## 🧱 Schema Check

### ✅ Schema Consistency (SQL → Model → API)

| Field | SQL Type | Model Type | API Type | Status |
|-------|----------|------------|----------|--------|
| row_id | UUID | uuid.UUID | (internal) | ✅ Pass |
| id | VARCHAR(14) | string | string | ✅ Pass |
| created_at | TIMESTAMPTZ | time.Time | date-time | ✅ Pass |
| updated_at | TIMESTAMPTZ | time.Time | date-time | ✅ Pass |
| deleted_at | TIMESTAMPTZ | sql.NullTime | (omitted) | ✅ Pass |
| version | INTEGER | int | integer | ✅ Pass |
| status | TEXT | string | enum | ✅ Pass |
| source_type | TEXT | string | enum | ✅ Pass |
| source_ref | VARCHAR(255) | sql.NullString | string | ✅ Pass |
| checkin_id | VARCHAR(64) | string | string | ✅ Pass |
| checkin_time | TIMESTAMPTZ | sql.NullTime | date-time | ✅ Pass |
| checkin_snapshot | JSONB | json.RawMessage | object | ✅ Pass |
| weigh_coin | INTEGER | sql.NullInt64 | integer | ✅ Pass |
| dump_fetch_mode | TEXT | string | enum | ✅ Pass |
| ccs | NUMERIC(5,2) | *decimal.Decimal | decimal | ✅ Pass |
| net_weight_kg | NUMERIC(10,2) | *decimal.Decimal | decimal | ✅ Pass |
| issued_at | TIMESTAMPTZ | sql.NullTime | date-time | ✅ Pass |
| issued_by | VARCHAR(64) | sql.NullString | string | ✅ Pass |
| voided_at | TIMESTAMPTZ | sql.NullTime | date-time | ✅ Pass |
| voided_by | VARCHAR(64) | sql.NullString | string | ✅ Pass |
| void_reason | TEXT | sql.NullString | string | ✅ Pass |
| pdf_url | TEXT | sql.NullString | string (uri) | ✅ Pass |
| booking_id | VARCHAR(255) | sql.NullString | string | ✅ Pass |
| payment_prefs | JSONB | json.RawMessage | object | ✅ Pass |

### ✅ Database Constraints

- PK constraint on `row_id` (UUID): ✅ Implemented
- UNIQUE constraint on `id` (CRN-YYYY-NNNNN): ✅ Implemented
- CHECK constraint `id ~ '^CRN-\d{4}-\d{5}$'`: ✅ Implemented
- CHECK constraint on `version > 0`: ✅ Implemented
- CHECK constraint on `status IN (Draft, Issued, Void)`: ✅ Implemented
- CHECK constraint on `source_type IN (CBM, NBM, CENTRAL)`: ✅ Implemented
- CHECK constraint on `dump_fetch_mode IN (auto, manual)`: ✅ Implemented
- CHECK constraint on `ccs >= 0 AND round(ccs, 2)`: ✅ Implemented
- CHECK constraint on `net_weight_kg >= 0 AND round(net_weight_kg, 2)`: ✅ Implemented
- CHECK constraint `chk_void_reason_length`: ✅ Implemented (void status requires reason ≥ 5 chars)
- CHECK constraint `chk_manual_mode_requires_values`: ✅ Implemented (manual mode requires ccs and net_weight_kg)
- FK constraint `fk_factory_dump_results_receiving`: ✅ Implemented (ON UPDATE CASCADE, ON DELETE SET NULL)

### ✅ Indexes

- `idx_receiving_notes_weigh_coin_checkin_time`: ✅ Implemented
- `idx_receiving_notes_source_type_source_ref`: ✅ Implemented
- `idx_receiving_notes_status_updated_at`: ✅ Implemented (DESC)
- `idx_receiving_notes_checkin_id`: ✅ Implemented
- `idx_receiving_notes_deleted_at`: ✅ Implemented (partial index WHERE deleted_at IS NULL)
- `idx_factory_dump_results_lookup`: ✅ Implemented (quota_id, checkin_date, weigh_coin)
- `idx_factory_dump_results_receiving_row_id`: ✅ Implemented
- `uq_factory_dump_results_key`: ✅ Implemented (partial unique index WHERE quota_id IS NOT NULL)

### ✅ Triggers

- `trg_receiving_notes_before_insert`: ✅ Implemented (auto-generate public ID CRN-YYYY-NNNNN)
- `trg_factory_dump_results_before_insert`: ✅ Implemented (auto-generate public ID FDR-NNNNNNNNNN)
- `trg_receiving_notes_update_timestamp`: ✅ Implemented (auto-update updated_at)

### ✅ Field Naming Consistency (DB ↔ Model ↔ API)

All field names follow the standard mapping:
- Database: `snake_case` ✅
- Go Model: `PascalCase` for struct fields, `snake_case` for db tags ✅
- JSON API: `snake_case` for request/response ✅

---

## ⚙️ Logic & API Check

### ❌ CRITICAL ISSUES

#### 1. ❌ Missing Test Coverage (0%)
- **Location:** ทุก package ของ CNRC001
- **Issue:** ไม่มี test files สำหรับ:
  - `internal/models/receiving_note.go`
  - `internal/models/factory_dump_result.go`
  - `internal/models/cane_receiving_dto.go`
  - `internal/services/cane_receiving_service.go`
  - `internal/handlers/cane_receiving_handler_gin.go`
  - `internal/repositories/sql/receiving_note_repository.go`
- **Impact:** ไม่สามารถยืนยันความถูกต้องของ business logic, data validation, error handling
- **Recommendation:** สร้าง unit tests และ integration tests ให้ครบทุก layer (target coverage ≥ 80%)

#### 2. ❌ Side-Effects Not Implemented
- **Location:** `internal/services/cane_receiving_service.go:86-110`
- **Missing implementations:**
  - `POST /api/weigh-coin/free {weigh_coin}` - ไม่มีการเรียก API เพื่อปล่อย weigh coin
  - `PATCH /api/cbm/{booking_id}/status {status: awaiting_payment}` - ไม่มีการ update CBM status
  - EventBus emission `cane_receiving.issued` - ไม่มีการ emit event
  - PDF generation with QR code - comment TODO ไว้ แต่ยังไม่ implement
- **Impact:** Critical business flow ไม่ทำงาน - weigh coin ไม่ถูกปล่อย, CBM status ไม่ update, downstream systems ไม่ได้รับ event
- **Recommendation:** Implement ทุก side-effects ตาม feature spec ก่อนการปล่อยใช้งาน

#### 3. ❌ Idempotency Key Not Stored/Checked
- **Location:** `internal/handlers/cane_receiving_handler_gin.go:70-82`
- **Issue:** Handler รับ `X-Idempotency-Key` แต่มี comment `// TODO: Check idempotency key in cache/database` - ยังไม่มี implementation
- **Impact:** Duplicate request อาจสร้าง receiving note ซ้ำ ละเมิด idempotency requirement
- **Recommendation:** Implement idempotency key storage (Redis cache หรือ DB table) พร้อม response caching

#### 4. ❌ Payment Linkage Detection Missing
- **Location:** `internal/services/cane_receiving_service.go:267-303`
- **Issue:** Void operation ไม่มีการตรวจสอบว่า receiving note ถูก link กับ payment หรือไม่
- **Impact:** อาจ void receiving note ที่มี payment แล้ว ทำให้เกิด data inconsistency
- **Recommendation:** เพิ่ม payment linkage check API หรือ field ใน receiving_notes table

### ⚠️ MAJOR ISSUES

#### 5. ⚠️ Factory API Integration Not Implemented
- **Location:** `internal/services/cane_receiving_service.go:85-91`
- **Issue:** Auto-fetch mode มี comment `// TODO: Call external factory API` - ยังไม่มี implementation
- **Impact:** Auto-fetch dump results ใช้งานไม่ได้, ต้องใช้ manual mode เสมอ
- **Recommendation:** Implement factory API client with retry policy (3 attempts, exponential backoff)

#### 6. ⚠️ CSV Export Service Not Implemented
- **Location:** `internal/services/cane_receiving_service.go:342-359`
- **Issue:** เรียกใช้ `s.csvService.ExportToCSV(notes)` แต่ `ReceivingNoteCSVService` ยังไม่มีการ implement
- **Impact:** CSV export feature ไม่ทำงาน
- **Recommendation:** Implement `ReceivingNoteCSVService` ตาม feature spec (Thai headers, all filter support)

#### 7. ⚠️ PDF Generation Service Not Fully Implemented
- **Location:** `internal/services/cane_receiving_service.go:307-339`
- **Issue:** เรียกใช้ `s.pdfService.GeneratePDF(note, snapshot)` แต่ service นี้อาจยังไม่สมบูรณ์
- **Impact:** PDF generation with QR code อาจไม่ทำงานหรือยังไม่ผ่าน test
- **Recommendation:** ตรวจสอบและทดสอบ `ReceivingNotePDFService` ให้ครบถ้วน

### ⚠️ MODERATE ISSUES

#### 8. ⚠️ Optimistic Locking Version Parsing
- **Location:** `internal/handlers/cane_receiving_handler_gin.go:188`
- **Issue:** ใช้ `utils.ParseVersionFromETag(ifMatch)` แต่ utility function นี้อาจยังไม่ถูก test
- **Impact:** ETag parsing ผิดพลาดอาจทำให้ optimistic locking ไม่ทำงาน
- **Recommendation:** เพิ่ม unit tests สำหรับ `ParseVersionFromETag` และ `GenerateETag`

#### 9. ⚠️ Error Handling Inconsistency
- **Location:** `internal/handlers/cane_receiving_handler_gin.go:88-96`
- **Issue:** ใช้ `strings.Contains(err.Error(), "CCS")` เพื่อตรวจสอบ error type - วิธีนี้ไม่ robust
- **Recommendation:** ใช้ custom error types (e.g., `errors.As()`) แทนการ parse error message

#### 10. ⚠️ QR Code Resolution Logic
- **Location:** `internal/services/cane_receiving_service.go:362-386`
- **Issue:** QR resolver ตรวจสอบแค่ prefix `CHK-` และ `CRN-` - ไม่รองรับ JSON format หรือ prefixed format (เช่น `CHK:CHK-2025-00001`)
- **Impact:** QR codes ที่ใช้รูปแบบอื่นจะ resolve ไม่ได้
- **Recommendation:** Implement multi-format QR parsing ตาม feature spec

### ✅ PASSED

#### ✅ CRUD Operations Complete
- Create: ✅ `CreateReceivingNote` implemented
- Read: ✅ `GetReceivingNoteDetail`, `ListReceivingNotes` implemented
- Update: ✅ `VoidReceivingNote` (status update) implemented
- Soft Delete: ✅ `Delete` method in repository interface defined

#### ✅ Validation Logic
- Manual mode validation: ✅ ตรวจสอบ CCS และ NetWeightKg required (service:47-58)
- Decimal precision: ✅ ตรวจสอบ >= 0 (service:52-57)
- Void reason validation: ✅ min 5 chars (DTO:28 + DB constraint)
- Receiving ID format validation: ✅ pattern check (handler:115, 165)

#### ✅ Status Transition Logic
- Draft → Issued: ✅ Implemented (สร้าง receiving note เป็น Issued ทันที)
- Issued → Void: ✅ Implemented with validation (service:275-276)
- Void blocking: ✅ ตรวจสอบ status = Issued (service:275)

#### ✅ API Endpoint Mapping
ทุก endpoint ใน OpenAPI spec มี handler ครบ:
- `GET /api/v1/agm/cane-receivings` → `ListReceivingNotes` ✅
- `POST /api/v1/agm/cane-receivings` → `CreateReceivingNote` ✅
- `GET /api/v1/agm/cane-receivings/:receiving_id` → `GetReceivingNoteDetail` ✅
- `POST /api/v1/agm/cane-receivings/:receiving_id/void` → `VoidReceivingNote` ✅
- `POST /api/v1/agm/cane-receivings/:receiving_id/pdf` → `GeneratePDF` ✅
- `GET /api/v1/agm/cane-receivings/export` → `ExportCSV` ✅
- `POST /api/v1/scan/resolve` → `ResolveQRCode` ✅

#### ✅ HTTP Status Codes
- 200 OK: ✅ List, Detail, Void, PDF generation
- 201 Created: ✅ Create receiving note
- 304 Not Modified: ✅ If-None-Match support (handler:152-155)
- 400 Bad Request: ✅ Invalid request/query
- 401 Unauthorized: ✅ (ตาม spec, ยังไม่เห็น auth middleware)
- 403 Forbidden: ✅ (ตาม spec, ยังไม่เห็น RBAC middleware)
- 404 Not Found: ✅ Receiving note not found, QR not resolved
- 409 Conflict: ✅ Void not allowed
- 412 Precondition Failed: ✅ ETag mismatch (handler:220-226)
- 422 Unprocessable Entity: ✅ CCS/Weight validation (handler:89-95)
- 428 Precondition Required: ✅ Missing If-Match (handler:178-184)
- 500 Internal Error: ✅ Generic errors

#### ✅ ETag Support for Optimistic Locking
- ETag generation: ✅ `utils.GenerateETag(version, epoch)` (handler:148)
- ETag header return: ✅ GET detail (handler:149)
- If-None-Match support: ✅ 304 response (handler:152-155)
- If-Match requirement: ✅ Void operation (handler:176-197)
- Version increment: ✅ Void operation (service:286)

---

## 🧩 Test Result

### ❌ Test Coverage Summary

**Overall Status:** ❌ **FAILED** - Build errors ใน test suite ของ modules อื่น, CNRC001 ไม่มี tests

| Package | Coverage | Status | Note |
|---------|----------|--------|------|
| `internal/models` | **0.0%** | ❌ No tests | ไม่มี test files สำหรับ CNRC001 models |
| `internal/services` | **0.0%** | ❌ No tests | ไม่มี test files สำหรับ `cane_receiving_service.go` |
| `internal/handlers` | **Build Failed** | ❌ Build error | Test compilation errors ใน modules อื่น |
| `internal/repositories` | **0.0%** | ❌ No tests | ไม่มี test files สำหรับ CNRC001 repositories |
| `internal/repositories/sql` | **0.0%** | ❌ No tests | ไม่มี test files สำหรับ `receiving_note_repository.go` |

### ❌ Build/Test Failures Summary

1. **handlers test build failed** - undefined types ใน `warehouse_area_handler_test.go`
2. **finance handler test build failed** - mock interface mismatch
3. **finance repository tests failed** - SQL syntax errors (near "(")
4. **routes/services/validators build failed** - dependency issues

### 📋 Missing Test Files

ต้องสร้าง test files สำหรับ:
1. `internal/models/receiving_note_test.go`
2. `internal/models/factory_dump_result_test.go`
3. `internal/models/cane_receiving_dto_test.go`
4. `internal/services/cane_receiving_service_test.go`
5. `internal/handlers/cane_receiving_handler_gin_test.go`
6. `internal/repositories/sql/receiving_note_repository_test.go`
7. `internal/repositories/sql/factory_dump_result_repository_test.go`

### 📋 Test Cases Recommended

**Unit Tests:**
- Model validation (constants, table names)
- DTO validation tags
- Service business logic (manual validation, status transitions, error handling)
- Handler request/response mapping, error codes
- Repository CRUD operations, query filters

**Integration Tests:**
- End-to-end flow: Create → Detail → Void
- Auto-fetch mode (with factory API mock)
- Manual mode with decimal validation
- Idempotency key handling
- Optimistic locking (version conflict scenarios)
- PDF generation
- CSV export with filters
- QR code resolution

**Target:** ≥ 80% coverage per package

---

## 📊 Naming Conventions Check

### ✅ Database (snake_case)

**Tables:**
- `receiving_notes` ✅
- `factory_dump_results` ✅

**Columns:**
- `row_id`, `created_at`, `updated_at`, `deleted_at` ✅
- `checkin_id`, `weigh_coin`, `dump_fetch_mode` ✅
- `ccs`, `net_weight_kg`, `issued_at`, `voided_at` ✅
- `source_type`, `source_ref`, `checkin_snapshot` ✅
- `payment_prefs`, `booking_id`, `pdf_url` ✅

**Constraints:**
- `chk_void_reason_length` ✅
- `chk_manual_mode_requires_values` ✅
- `fk_factory_dump_results_receiving` ✅

**Indexes:**
- `idx_receiving_notes_weigh_coin_checkin_time` ✅
- `idx_receiving_notes_source_type_source_ref` ✅
- `uq_factory_dump_results_key` ✅

**Triggers/Functions:**
- `fn_receiving_notes_make_public_id()` ✅
- `fn_factory_dump_results_make_public_id()` ✅
- `fn_update_timestamp()` ✅
- `trg_receiving_notes_before_insert` ✅

### ✅ Go Code (PascalCase for types, camelCase for variables)

**Structs:**
- `ReceivingNote`, `FactoryDumpResult` ✅
- `CheckinSnapshotData`, `PaymentPrefsData` ✅
- `CreateReceivingNoteRequest`, `VoidReceivingNoteRequest` ✅
- `ReceivingNoteListItem`, `ReceivingNoteDetail` ✅

**Interfaces:**
- `ReceivingNoteRepository` ✅
- `FactoryDumpResultRepository` ✅

**Services:**
- `CaneReceivingService` ✅

**Handlers:**
- `CaneReceivingHandlerGin` ✅

**Functions:**
- `NewCaneReceivingService`, `CreateReceivingNote` ✅
- `GetReceivingNoteDetail`, `VoidReceivingNote` ✅
- `ListReceivingNotes`, `GeneratePDF`, `ExportCSV` ✅

**Variables:**
- `receivingRepo`, `factoryDumpRepo`, `pdfService` ✅

**Files:**
- `receiving_note.go`, `factory_dump_result.go` ✅
- `cane_receiving_dto.go` ✅
- `cane_receiving_service.go` ✅
- `cane_receiving_handler_gin.go` ✅
- `receiving_note_repository.go` ✅

### ✅ API (kebab-case for paths, snake_case for params)

**Paths:**
- `/api/v1/agm/cane-receivings` ✅
- `/api/v1/agm/cane-receivings/:receiving_id` ✅
- `/api/v1/agm/cane-receivings/:receiving_id/void` ✅
- `/api/v1/agm/cane-receivings/:receiving_id/pdf` ✅
- `/api/v1/agm/cane-receivings/export` ✅
- `/api/v1/scan/resolve` ✅

**Query Parameters:**
- `q`, `date_from`, `date_to`, `source_type`, `status` ✅
- `checkin_id`, `weigh_coin`, `page`, `page_size`, `sort` ✅

**JSON Fields:**
- `receiving_id`, `source_type`, `checkin_id` ✅
- `dump_fetch_mode`, `ccs`, `net_weight_kg` ✅
- `issued_at`, `voided_at`, `void_reason` ✅

---

## 🎯 Manifest Completeness

### ✅ Manifest File: `projects/erp/manifest/CNRC001.json`

**Present Fields:**
- `feature_code`: ✅ "CNRC001"
- `feature_name`: ✅ "Cane Receiving"
- `module`: ✅ "AGM"
- `phase`: ✅ "build_completed"
- `outputs`: ✅ ครบทุกไฟล์ (models, repositories, services, handlers, routes)
- `files_created`: ✅ สรุปจำนวนไฟล์ถูกต้อง (total: 11)
- `compilation_status`: ✅ "success"
- `build_result`: ✅ "PASS"
- `dependency_injection`: ✅ มีรายละเอียดครบ (repos, services, handlers, routes)
- `endpoints`: ✅ ครบทั้ง 7 endpoints
- `database_tables`: ✅ ครบทั้ง 2 tables (receiving_notes, factory_dump_results)

**Missing/Needs Update:**
- `qa_status`: ไม่มี field นี้ (ยังเป็น pending ก่อน QA)
- `qa_report`: ไม่มี field นี้ (จะเพิ่มหลัง QA)
- `notes`: มี TODOs ที่ยังไม่ implement:
  - "TODO: Implement PDF generation with QR code"
  - "TODO: Implement external factory API integration"
  - "TODO: Implement CSV export functionality"
  - "TODO: Extract version from If-Match header for optimistic locking" (แก้ไขแล้ว)

---

## 🔴 Critical Action Items (ต้องแก้ก่อนปล่อยใช้งาน)

1. **[CRITICAL]** สร้าง unit tests และ integration tests ให้ครบ ≥ 80% coverage
2. **[CRITICAL]** Implement side-effects:
   - POST /api/weigh-coin/free
   - PATCH /api/cbm/{booking_id}/status (Issue + Void)
   - EventBus emission (cane_receiving.issued, cane_receiving.void)
   - PDF generation with QR code
3. **[CRITICAL]** Implement idempotency key storage and checking (Redis or DB)
4. **[CRITICAL]** Implement payment linkage detection for void blocking
5. **[MAJOR]** Implement factory API client with retry policy
6. **[MAJOR]** Implement CSV export service with Thai headers
7. **[MAJOR]** Verify PDF generation service completeness
8. **[MODERATE]** Fix error handling (use custom error types แทน string matching)
9. **[MODERATE]** Enhance QR code resolver (support JSON/prefixed formats)
10. **[MODERATE]** เพิ่ม auth middleware และ RBAC middleware ตาม feature spec

---

## 📝 Notes

- **Compilation:** ✅ `go build` สำเร็จ (manifest ระบุ "success")
- **Test Suite:** ❌ Build failures ใน modules อื่น, CNRC001 ไม่มี tests
- **Side-effects:** ❌ Critical business logic ยังไม่ implement
- **Feature Completeness:** ⚠️ ~60% - Core CRUD ครบ แต่ side-effects และ integrations ยังไม่เสร็จ

**Overall Assessment:** ❌ **NOT READY FOR QA APPROVAL** - ต้องแก้ไข Critical issues ทั้งหมดและเพิ่ม test coverage ก่อน

---

**Next Steps:**
1. แก้ไข Critical และ Major issues ตามรายการข้างต้น
2. สร้าง test suite ครบถ้วน (unit + integration)
3. รัน test และให้ได้ coverage ≥ 80%
4. ทดสอบ end-to-end flow ทั้งหมด (auto-fetch, manual, void, PDF, CSV)
5. Re-run QA validation
