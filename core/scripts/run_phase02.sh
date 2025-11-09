#!/bin/bash
# =========================================================
# ⚙️ 2BSimpleCore: Phase 02 Runner - Design & Schema (Universal Compatible)
# =========================================================
# ใช้สำหรับอ่าน Feature Card → ออกแบบ ERD, SQL Schema, API Spec อัตโนมัติ
# ทำงานได้ทั้งบน macOS และ Linux
# =========================================================
set -e

# =========================================================
# ✅ Ensure Essential Paths & Commands
# =========================================================
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

AWK=$(which awk)
TR=$(which tr)
JQ=$(which jq)

for cmd in "$AWK" "$TR" "$JQ"; do
  if [ ! -x "$cmd" ]; then
    echo "❌ Missing command: $cmd"
    exit 1
  fi
done

FEATURE_NAME=$1
FEATURE_CODE=$2
MODULE=$3

if [ -z "$FEATURE_CODE" ]; then
  echo "❌ กรุณาระบุ Feature Code เช่น ./core/scripts/run_phase02.sh 'Product Management' PROD001 Inventory"
  exit 1
fi

# =========================================================
# 🧠 Path Configuration
# =========================================================
FEATURE_PATH=$(find projects/erp/features -type f \
  \( -name "FC-${FEATURE_CODE}-*.json" -o -name "feature-${FEATURE_CODE}.json" \) | head -n 1)
OUTPUT_DIR="projects/erp/backend/go_api"
DATE_STR=$(date +%Y%m%d)
MANIFEST_DIR="projects/erp/manifest"
MANIFEST_FILE="${MANIFEST_DIR}/${FEATURE_CODE}.json"

mkdir -p projects/erp/docs/erd projects/erp/docs/api "${OUTPUT_DIR}/migrations" "${MANIFEST_DIR}"

if [ ! -f "$FEATURE_PATH" ]; then
  echo "❌ ไม่พบไฟล์ Feature Card: FC-${FEATURE_CODE}-*.json หรือ feature-${FEATURE_CODE}.json"
  exit 1
fi

echo "---------------------------------------------"
echo "🧠 Running Phase 02 (Design & Schema)"
echo "📘 Feature: $FEATURE_NAME ($FEATURE_CODE)"
echo "📂 Module: $MODULE"
echo "📄 Feature Card: $FEATURE_PATH"
echo "---------------------------------------------"

# =========================================================
# 📦 อ่านข้อมูลจาก Feature Card (JSON)
# =========================================================
DATA_ENTITIES=$($JQ -r '
  if has("entities") then
    .entities[].name
  elif has("data_entities") then
    .data_entities[]
  else
    empty
  end' "$FEATURE_PATH")

API_ENDPOINTS=$($JQ -r '
  if (.api_endpoints[0]? | type) == "object" then
    .api_endpoints[] | "\(.method) \(.path)"
  else
    .api_endpoints[]
  end' "$FEATURE_PATH")

LINKED_FEATURES=$($JQ -r '.linked_features[]?' "$FEATURE_PATH")

if [ -z "$DATA_ENTITIES" ]; then
  echo "⚠️ Feature Card นี้ไม่มี data_entities หรือ entities ระบุไว้ จะสร้าง ERD และ SQL ขั้นพื้นฐานแทน"
  DATA_ENTITIES="entity"
fi

# =========================================================
# 🧱 Generate ERD (Mermaid)
# =========================================================
LOWER_MODULE=$(echo "$MODULE" | $TR '[:upper:]' '[:lower:]')
ERD_FILE="projects/erp/docs/erd/${FEATURE_CODE}-${LOWER_MODULE}.mmd"

echo "%% Auto-generated ERD for ${FEATURE_NAME}" > "$ERD_FILE"
echo "erDiagram" >> "$ERD_FILE"

for ENTITY in $DATA_ENTITIES; do
  UPPER_ENTITY=$(echo "$ENTITY" | $TR '[:lower:]' '[:upper:]')
  echo "  ${UPPER_ENTITY} {" >> "$ERD_FILE"
  echo "    int id PK" >> "$ERD_FILE"
  echo "    string name" >> "$ERD_FILE"
  echo "    timestamp created_at" >> "$ERD_FILE"
  echo "    timestamp updated_at" >> "$ERD_FILE"
  echo "    timestamp deleted_at" >> "$ERD_FILE"
  echo "  }" >> "$ERD_FILE"
done

MAIN_ENTITY=$(echo "$DATA_ENTITIES" | head -n 1 | $TR '[:lower:]' '[:upper:]')
for ENTITY in $(echo "$DATA_ENTITIES" | tail -n +2); do
  echo "  $(echo "$ENTITY" | $TR '[:lower:]' '[:upper:]') ||--o{ ${MAIN_ENTITY} : relates_to" >> "$ERD_FILE"
done

# =========================================================
# 🧾 Generate SQL Schema
# =========================================================
LOWER_FEATURE_CODE=$(echo "$FEATURE_CODE" | $TR '[:upper:]' '[:lower:]')
SQL_FILE="${OUTPUT_DIR}/migrations/${DATE_STR}_create_${LOWER_FEATURE_CODE}_schema.sql"
echo "-- Auto-generated SQL Schema for ${FEATURE_NAME}" > "$SQL_FILE"

for ENTITY in $DATA_ENTITIES; do
  TABLE_NAME=$(echo "${ENTITY}s" | $TR '[:upper:]' '[:lower:]')
  echo "" >> "$SQL_FILE"
  echo "CREATE TABLE ${TABLE_NAME} (" >> "$SQL_FILE"
  echo "  id SERIAL PRIMARY KEY," >> "$SQL_FILE"
  echo "  name VARCHAR(255) NOT NULL," >> "$SQL_FILE"
  echo "  created_at TIMESTAMPTZ DEFAULT NOW()," >> "$SQL_FILE"
  echo "  updated_at TIMESTAMPTZ DEFAULT NOW()," >> "$SQL_FILE"
  echo "  deleted_at TIMESTAMPTZ" >> "$SQL_FILE"
  echo ");" >> "$SQL_FILE"
done

# =========================================================
# 🌐 Generate OpenAPI Spec (YAML)
# =========================================================
API_FILE="projects/erp/docs/api/${FEATURE_CODE}-${LOWER_MODULE}-openapi.yaml"
echo "openapi: 3.0.3" > "$API_FILE"
echo "info:" >> "$API_FILE"
echo "  title: ${FEATURE_NAME} API" >> "$API_FILE"
echo "  version: 1.0.0" >> "$API_FILE"
echo "paths:" >> "$API_FILE"

for ENDPOINT in $API_ENDPOINTS; do
  METHOD=$(echo "$ENDPOINT" | $AWK '{print $1}' | $TR '[:upper:]' '[:lower:]')
  PATH=$(echo "$ENDPOINT" | $AWK '{print $2}')
  echo "  ${PATH}:" >> "$API_FILE"
  echo "    ${METHOD}:" >> "$API_FILE"
  echo "      summary: Auto-generated endpoint for ${FEATURE_NAME}" >> "$API_FILE"
  echo "      responses:" >> "$API_FILE"
  echo "        '200':" >> "$API_FILE"
  echo "          description: Success" >> "$API_FILE"
done

# =========================================================
# 📜 Generate Manifest (no cat/heredoc)
# =========================================================
{
  echo "{"
  echo "  \"feature\": \"${FEATURE_CODE}\","
  echo "  \"feature_name\": \"${FEATURE_NAME}\","
  echo "  \"module\": \"${MODULE}\","
  echo "  \"phase\": \"design_completed\","
  echo "  \"checked_at\": \"$(date -Iseconds)\","
  echo "  \"outputs\": ["
  echo "    \"${ERD_FILE}\","
  echo "    \"${SQL_FILE}\","
  echo "    \"${API_FILE}\""
  echo "  ],"
  echo "  \"linked_features\": [$(printf '\"%s\",' $LINKED_FEATURES | sed 's/,$//')],"
  echo "  \"qa_status\": \"pending\""
  echo "}"
} > "$MANIFEST_FILE"

# =========================================================
# ✅ Summary
# =========================================================
echo ""
echo "✅ ERD Diagram:  $ERD_FILE"
echo "✅ SQL Schema:   $SQL_FILE"
echo "✅ OpenAPI Spec: $API_FILE"
echo "📘 Manifest:     $MANIFEST_FILE"
echo "---------------------------------------------"
echo "🧩 ขั้นตอนต่อไป: ใช้ run_phase03.sh เพื่อสร้าง Golang Backend Code"
