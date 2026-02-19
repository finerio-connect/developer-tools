#!/usr/bin/env bash

opencode_gcp_init_defaults() {
  OPENCODE_INSTALL_URL="${OPENCODE_INSTALL_URL:-https://opencode.ai/install}"
  CONFIG_ROOT="${OPENCODE_GCP_CONFIG_ROOT:-$HOME/.config/opencode-gcp}"
  PROFILE_DIR="${OPENCODE_GCP_PROFILE_DIR:-$CONFIG_ROOT/profiles}"
  WRAPPER_DIR="${OPENCODE_GCP_BIN_DIR:-$HOME/.local/bin}"
  WRAPPER_PATH="$WRAPPER_DIR/opencode-gcp"
  PROFILE_FILE="$PROFILE_DIR/developer-tools.env"

  CREDENTIALS_DIR="${OPENCODE_GCP_CREDENTIALS_DIR:-$CONFIG_ROOT/credentials}"
  CREDENTIALS_PROJECTS_DIR="$CREDENTIALS_DIR/projects"
  CREDENTIALS_ACTIVE_DIR="$CREDENTIALS_DIR/active"
  ACTIVE_KEY_PATH="$CREDENTIALS_ACTIVE_DIR/finerio-key.json"

  OPENCODE_ENV_FILE="${OPENCODE_GCP_OPENCODE_ENV_FILE:-$CONFIG_ROOT/opencode.env}"
  OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
  OPENCODE_JSON_FILE="${OPENCODE_GCP_OPENCODE_JSON_FILE:-$OPENCODE_CONFIG_DIR/opencode.json}"

  GCP_ENV_DIR="${OPENCODE_GCP_ENV_DIR:-$HOME/.config/gcp-env}"
  SHELL_MODULE_DIR="${OPENCODE_GCP_SHELL_MODULE_DIR:-$CONFIG_ROOT/shell}"
  SHELL_MODULE_FILE="$SHELL_MODULE_DIR/gcp-tools.sh"

  DEFAULT_REGION="${OPENCODE_GCP_DEFAULT_REGION:-global}"
  DEFAULT_VERTEX_PROJECT_ID="${OPENCODE_GCP_VERTEX_PROJECT_ID:-developer-tools-482502}"
  FIXED_GCP_PROJECT="${OPENCODE_GCP_PROJECT_ID:-$DEFAULT_VERTEX_PROJECT_ID}"

  DEFAULT_MCP_BROWSER_PATH="${OPENCODE_GCP_BROWSER_MCP_PATH:-$HOME/workspace_projects/chrome-devtools-mcp/build/src/index.js}"

  MAPPED_PROJECT_KEYS=(
    "multiclient-dev"
    "enrichment-dev"
    "developer-tools"
    "data-dev"
    "finerio-labs"
    "cortex-dev"
    "multiclient-demo"
    "pfm-dev"
    "cortex-prod"
  )

  MAPPED_PROJECT_IDS=(
    "multiclient-dev"
    "enrichment-dev-485816"
    "developer-tools-482502"
    "data-dev-487014"
    "finerio-labs"
    "cortex-dev-480819"
    "multiclient-demo"
    "pfm-dev-485816"
    "cortex-prod-481416"
  )
}

opencode_gcp_log() {
  printf "[INFO] %s\n" "$*"
}

opencode_gcp_warn() {
  printf "[WARN] %s\n" "$*" >&2
}

opencode_gcp_fail() {
  printf "[ERROR] %s\n" "$*" >&2
  exit 1
}

opencode_gcp_usage() {
  cat <<'USAGE'
Instalador de OpenCode + credenciales GCP (modular, proyecto fijo configurable).

Uso:
  ./install-opencode-gcp.sh [--region REGION] [--force|--force-opencode-config]
  ./install-opencode-gcp.sh --help

Opciones:
  --region   Región por defecto de Vertex AI (ej: global, us-central1)
  --force    Reescribe perfil/envs/módulo shell y opencode.json (full)
  --force-opencode-config
             Reescribe solo opencode.json (con backup)
  --help     Muestra esta ayuda

Ejemplos:
  curl -fsSL https://raw.githubusercontent.com/finerio-connect/developer-tools/main/install-opencode-gcp.sh | bash
  curl -fsSL https://raw.githubusercontent.com/finerio-connect/developer-tools/main/install-opencode-gcp.sh | bash -s -- --force-opencode-config
  curl -fsSL https://raw.githubusercontent.com/finerio-connect/developer-tools/main/install-opencode-gcp.sh | bash -s -- --region us-central1 --force
USAGE
}

opencode_gcp_is_supported_os() {
  case "$(uname -s)" in
    Darwin|Linux)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

opencode_gcp_ensure_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || opencode_gcp_fail "No se encontró '$cmd'. Instálalo y vuelve a intentar."
}

opencode_gcp_prepare_dirs() {
  mkdir -p "$CONFIG_ROOT"
  mkdir -p "$PROFILE_DIR"
  mkdir -p "$WRAPPER_DIR"
  mkdir -p "$OPENCODE_CONFIG_DIR"
  mkdir -p "$GCP_ENV_DIR"
  mkdir -p "$SHELL_MODULE_DIR"
}
