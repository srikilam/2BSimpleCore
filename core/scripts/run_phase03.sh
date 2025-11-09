#!/bin/bash
# =========================================================
# ⚙️ 2BSimpleCore: Phase 03 Runner - Build & Integrate (Backend Golang)
# =========================================================
# อ่าน ERD + SQL + API Spec จาก Phase 02
# แล้วสร้างโครงสร้าง Golang Backend (Model, Repository, Service, Handler)
# =========================================================
set -e

# =========================================================
# ✅ Environment Setup
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
  echo "❌ กรุณาระบุ Feature Code เช่น ./core/scripts/run_phase03.sh 'Product Management' PROD001 Inventory"
  exit 1
fi

# =========================================================
# 🧠 Path Configuration
# =========================================================
FEATURE_PATH=$(find projects/erp/features -type f -name "FC-${FEATURE_CODE}-*.json" | head -n 1)
OUTPUT_DIR="projects/erp/backend/go_api/internal"
MANIFEST_FILE="projects/erp/manifest/${FEATURE_CODE}.json"
DATE_STR=$(date +%Y%m%d)

if [ ! -f "$FEATURE_PATH" ]; then
  echo "❌ ไม่พบ Feature Card: FC-${FEATURE_CODE}-*.json"
  exit 1
fi

mkdir -p "${OUTPUT_DIR}/models" "${OUTPUT_DIR}/repositories" "${OUTPUT_DIR}/services" "${OUTPUT_DIR}/handlers"

echo "---------------------------------------------"
echo "🚀 Running Phase 03 (Build & Integrate)"
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

if [ -z "$DATA_ENTITIES" ]; then
  echo "⚠️ ไม่มี entities ใน Feature Card → จะสร้าง model ตัวอย่าง"
  DATA_ENTITIES="entity"
fi

# =========================================================
# 🧱 Generate Golang Files
# =========================================================
for ENTITY in $DATA_ENTITIES; do
  ENTITY_LOWER=$(echo "$ENTITY" | $TR '[:upper:]' '[:lower:]')

  MODEL_FILE="${OUTPUT_DIR}/models/${ENTITY_LOWER}.go"
  REPO_FILE="${OUTPUT_DIR}/repositories/${ENTITY_LOWER}_repository.go"
  SERVICE_FILE="${OUTPUT_DIR}/services/${ENTITY_LOWER}_service.go"
  HANDLER_FILE="${OUTPUT_DIR}/handlers/${ENTITY_LOWER}_handler.go"

  # =========================================================
  # 🧩 Model
  # =========================================================
  {
    echo "package models"
    echo ""
    echo "// ${ENTITY} represents the ${FEATURE_NAME} entity"
    echo "type ${ENTITY} struct {"
    echo "    ID        int       \`json:\"id\"\`"
    echo "    Name      string    \`json:\"name\"\`"
    echo "    CreatedAt time.Time \`json:\"created_at\"\`"
    echo "    UpdatedAt time.Time \`json:\"updated_at\"\`"
    echo "    DeletedAt *time.Time \`json:\"deleted_at,omitempty\"\`"
    echo "}"
  } > "$MODEL_FILE"

  # =========================================================
  # 🧩 Repository
  # =========================================================
  {
    echo "package repositories"
    echo ""
    echo "import ("
    echo "    \"context\""
    echo "    \"${MODULE}/internal/models\""
    echo ")"
    echo ""
    echo "type ${ENTITY}Repository interface {"
    echo "    Create(ctx context.Context, m *models.${ENTITY}) error"
    echo "    FindAll(ctx context.Context) ([]models.${ENTITY}, error)"
    echo "    FindByID(ctx context.Context, id int) (*models.${ENTITY}, error)"
    echo "    Update(ctx context.Context, m *models.${ENTITY}) error"
    echo "    Delete(ctx context.Context, id int) error"
    echo "}"
  } > "$REPO_FILE"

  # =========================================================
  # 🧩 Service
  # =========================================================
  {
    echo "package services"
    echo ""
    echo "import ("
    echo "    \"context\""
    echo "    \"${MODULE}/internal/models\""
    echo "    \"${MODULE}/internal/repositories\""
    echo ")"
    echo ""
    echo "type ${ENTITY}Service struct {"
    echo "    repo repositories.${ENTITY}Repository"
    echo "}"
    echo ""
    echo "func New${ENTITY}Service(r repositories.${ENTITY}Repository) *${ENTITY}Service {"
    echo "    return &${ENTITY}Service{repo: r}"
    echo "}"
    echo ""
    echo "func (s *${ENTITY}Service) GetAll(ctx context.Context) ([]models.${ENTITY}, error) {"
    echo "    return s.repo.FindAll(ctx)"
    echo "}"
  } > "$SERVICE_FILE"

  # =========================================================
  # 🧩 Handler
  # =========================================================
  {
    echo "package handlers"
    echo ""
    echo "import ("
    echo "    \"net/http\""
    echo "    \"encoding/json\""
    echo "    \"${MODULE}/internal/services\""
    echo ")"
    echo ""
    echo "type ${ENTITY}Handler struct {"
    echo "    svc *services.${ENTITY}Service"
    echo "}"
    echo ""
    echo "func New${ENTITY}Handler(s *services.${ENTITY}Service) *${ENTITY}Handler {"
    echo "    return &${ENTITY}Handler{svc: s}"
    echo "}"
    echo ""
    echo "func (h *${ENTITY}Handler) List(w http.ResponseWriter, r *http.Request) {"
    echo "    data, err := h.svc.GetAll(r.Context())"
    echo "    if err != nil {"
    echo "        http.Error(w, err.Error(), http.StatusInternalServerError)"
    echo "        return"
    echo "    }"
    echo "    w.Header().Set(\"Content-Type\", \"application/json\")"
    echo "    json.NewEncoder(w).Encode(data)"
    echo "}"
  } > "$HANDLER_FILE"

done

# =========================================================
# 📜 Update Manifest
# =========================================================
{
  echo "{"
  echo "  \"feature\": \"${FEATURE_CODE}\","
  echo "  \"phase\": \"build_completed\","
  echo "  \"checked_at\": \"$(date -Iseconds)\","
  echo "  \"outputs\": ["
  echo "    \"models/*.go\","
  echo "    \"repositories/*.go\","
  echo "    \"services/*.go\","
  echo "    \"handlers/*.go\""
  echo "  ],"
  echo "  \"qa_status\": \"pending\""
  echo "}"
} > "$MANIFEST_FILE"

# =========================================================
# ✅ Summary
# =========================================================
echo ""
echo "✅ Model, Repository, Service, Handler created in:"
echo "   $OUTPUT_DIR"
echo "📘 Manifest: $MANIFEST_FILE"
echo "---------------------------------------------"
echo "🎯 Phase 03 Completed. Ready for QA (Phase 04)."
