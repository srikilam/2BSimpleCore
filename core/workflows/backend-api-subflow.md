# ⚙️ API Subflow (2BSimpleCore)

## Phase Mapping
| Phase | Task | Output |
|--------|------|---------|
| 01 | ระบุ API จาก FRD | Feature Card (api_endpoints) |
| 02 | สร้าง OpenAPI Spec + Mock | .yaml / .json |
| 03 | เขียน Handler, Service, Middleware | .go files |
| 04 | QA Endpoint + Validation | QA Report |
| 05 | Log Result | logbook-api.md |

## Validation
- ตรวจ path, method, naming
- ตรวจ response schema vs OpenAPI
- ตรวจ middleware / auth consistency

## Manifest Keys
```json
{
  "phase": "api_validated",
  "openapi": "projects/erp/docs/api/<feature>.yaml",
  "handler": "internal/handlers/<entity>_handler.go"
}