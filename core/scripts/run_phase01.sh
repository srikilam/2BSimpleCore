#!/usr/bin/env bash
set -e

# =========================================================
# 🧩 2BSimpleCore: Phase 01 Runner - Define & Analyze
# =========================================================
# ใช้สำหรับเรียก Claude Architect Agent เพื่อแปลง FRD → Feature Card
# =========================================================

# 🧠 ตัวแปร Input
FEATURE_NAME=$1
FEATURE_CODE=$2
MODULE=$3

# 📘 ตำแหน่งไฟล์ FRD
FRD_PATH="projects/erp/docs/frd/FRD-${FEATURE_NAME// /_}.md"

# 🧩 Prompt Template
PROMPT_PATH="core/prompts/backend/phase_01_define.md"

# 🗂 Output Directory
OUTPUT_DIR="projects/erp/features"
OUTPUT_FILE="${OUTPUT_DIR}/feature-${FEATURE_CODE}.json"

# ✅ ตรวจสอบไฟล์ FRD
if [ ! -f "$FRD_PATH" ]; then
  echo "❌ ไม่พบไฟล์ FRD: $FRD_PATH"
  exit 1
fi

# ✅ ตรวจสอบ Prompt Template
if [ ! -f "$PROMPT_PATH" ]; then
  echo "❌ ไม่พบไฟล์ Prompt Template: $PROMPT_PATH"
  exit 1
fi

# =========================================================
# 🚀 เริ่มการทำงาน (เรียก Claude / Chat Model)
# =========================================================
echo "🧠 Running Phase 01 (Define & Analyze)"
echo "📘 Feature: $FEATURE_NAME ($FEATURE_CODE)"
echo "📂 Module: $MODULE"
echo "📄 FRD: $FRD_PATH"
echo "------------------------------------------"

# ตัวอย่าง mock การเรียก Claude (ในระบบจริงจะเชื่อม Claude Code หรือ OpenAI API)
# สามารถปรับให้รันผ่าน API ที่คุณใช้ เช่น openai / claude / local agent

echo "✨ เรียก Claude เพื่อสร้าง Feature Card..."
echo "------------------------------------------"

# ตัวอย่าง pseudo-command (คุณสามารถแทนด้วย API call จริงได้)
# ตัวอย่าง: ใช้ claude หรือ openai API ผ่าน CLI
# openai api chat.completions.create \
#   -m claude-code \
#   -p "$PROMPT_PATH" \
#   -v "FEATURE_NAME=$FEATURE_NAME" \
#   -v "FEATURE_CODE=$FEATURE_CODE" \
#   -v "MODULE=$MODULE" \
#   -v "FRD_PATH=$FRD_PATH" \
#   -o "$OUTPUT_FILE"

# 💡 สำหรับตอนนี้ เราจะ mock การสร้างไฟล์ JSON แทน (ทดลอง)
cat <<EOF > "$OUTPUT_FILE"
{
  "feature_code": "$FEATURE_CODE",
  "feature_name": "$FEATURE_NAME",
  "module": "$MODULE",
  "business_context": "TODO: Claude จะเติมข้อมูลนี้จาก FRD",
  "user_story": [],
  "acceptance_criteria": [],
  "data_entities": [],
  "api_endpoints": [],
  "linked_features": [],
  "dependencies": [],
  "dev_status": "draft",
  "assigned_to": "",
  "reviewer": "",
  "last_update": "$(date -Iseconds)"
}
EOF

echo "✅ Feature Card สร้างแล้วที่: $OUTPUT_FILE"
echo "------------------------------------------"
echo "🧩 ขั้นตอนต่อไป: ใช้ run_phase02.sh เพื่อออกแบบ Schema & API"
