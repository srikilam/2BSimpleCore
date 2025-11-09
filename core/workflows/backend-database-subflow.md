# 🧱 Database Subflow (2BSimpleCore)

## Phase Mapping
| Phase | Task | Output |
|--------|------|---------|
| 01 | ออกแบบ ERD | .mmd |
| 02 | เขียน Migration + Model | .sql, .go |
| 03 | ทดสอบ Data Integrity | test/data_integrity_test.go |
| 04 | ปรับจูน Query / Index | qa-db-report.md |
| 05 | Backup + Monitoring | logbook-db.md |

## Validation
- ตรวจ Foreign Key, Constraint, Enum
- ตรวจ naming field และ type
- ตรวจ test coverage ของ repository

## Manifest Keys
```json
{
  "phase": "database_validated",
  "db_schema": "migrations/<feature>_create_table.sql",
  "model": "internal/models/<entity>.go"
}
