#!/usr/bin/env bash
set -euo pipefail

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

log() {
  printf "[INFO] %s\n" "$*"
}

warn() {
  printf "[WARN] %s\n" "$*" >&2
}

fail() {
  printf "[ERROR] %s\n" "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Instalador de OpenCode + credenciales GCP (proyecto fijo configurable).

Uso:
  ./install-opencode-gcp.sh [--region REGION] [--force]
  ./install-opencode-gcp.sh --help

Opciones:
  --region   Región por defecto de Vertex AI (ej: global, us-central1)
  --force    Reescribe perfil/config base (con backup de opencode.json)
  --help     Muestra esta ayuda

Ejemplo:
  curl -fsSL <URL_DE_TU_SCRIPT> | bash -s -- --region us-central1
USAGE
}

is_supported_os() {
  case "$(uname -s)" in
    Darwin|Linux) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || fail "No se encontró '$cmd'. Instálalo y vuelve a intentar."
}

write_profile_if_missing() {
  local region="$1"
  local force="$2"

  if [[ -f "$PROFILE_FILE" && "$force" != "true" ]]; then
    log "Perfil existente: $PROFILE_FILE (no se modifica)"
    return 0
  fi

  cat >"$PROFILE_FILE" <<PROFILE
# Perfil único de OpenCode para Vertex AI
# Se usa SIEMPRE este proyecto para credenciales:
GOOGLE_CLOUD_PROJECT="$FIXED_GCP_PROJECT"
VERTEX_LOCATION="$region"

# Compatibilidad con algunas configuraciones antiguas:
GOOGLE_VERTEX_PROJECT="$FIXED_GCP_PROJECT"
GOOGLE_VERTEX_LOCATION="$region"

# Opcional: nombre de configuración gcloud a activar automáticamente.
GCLOUD_CONFIGURATION="$FIXED_GCP_PROJECT"

# Ruta estándar del JSON activo de Finerio.
# Puedes reemplazar este archivo o actualizar el symlink activo.
GOOGLE_APPLICATION_CREDENTIALS="$ACTIVE_KEY_PATH"
PROFILE

  chmod 600 "$PROFILE_FILE"
  log "Perfil generado: $PROFILE_FILE"
}

ensure_credentials_layout() {
  local idx
  local project_key
  local project_id
  local project_dir
  local map_file

  mkdir -p "$CREDENTIALS_PROJECTS_DIR"
  mkdir -p "$CREDENTIALS_ACTIVE_DIR"

  [[ ${#MAPPED_PROJECT_KEYS[@]} -eq ${#MAPPED_PROJECT_IDS[@]} ]] || fail "Catálogo de proyectos inválido en el script."
  map_file="$CREDENTIALS_PROJECTS_DIR/projects-map.txt"
  : > "$map_file"

  for idx in "${!MAPPED_PROJECT_KEYS[@]}"; do
    project_key="${MAPPED_PROJECT_KEYS[$idx]}"
    project_id="${MAPPED_PROJECT_IDS[$idx]}"
    project_dir="$CREDENTIALS_PROJECTS_DIR/$project_key"

    mkdir -p "$project_dir"
    printf "%s=%s\n" "$project_key" "$project_id" >>"$map_file"

    if [[ ! -f "$project_dir/project-id.txt" ]]; then
      printf "%s\n" "$project_id" >"$project_dir/project-id.txt"
      chmod 600 "$project_dir/project-id.txt"
    fi
  done

  if [[ ! -e "$ACTIVE_KEY_PATH" ]]; then
    cat >"$ACTIVE_KEY_PATH" <<'KEY_PLACEHOLDER'
{
  "type": "service_account",
  "project_id": "replace-me",
  "private_key_id": "replace-me",
  "private_key": "-----BEGIN PRIVATE KEY-----\nreplace-me\n-----END PRIVATE KEY-----\n",
  "client_email": "replace-me",
  "client_id": "replace-me",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token"
}
KEY_PLACEHOLDER
    chmod 600 "$ACTIVE_KEY_PATH"
    warn "Se creó placeholder en $ACTIVE_KEY_PATH. Reemplázalo con tu finerio key.json."
  fi
}

write_gcp_env_files() {
  local region="$1"
  local force="$2"
  local idx
  local project_key
  local project_id
  local env_file
  local key_file

  mkdir -p "$GCP_ENV_DIR"

  for idx in "${!MAPPED_PROJECT_KEYS[@]}"; do
    project_key="${MAPPED_PROJECT_KEYS[$idx]}"
    project_id="${MAPPED_PROJECT_IDS[$idx]}"
    env_file="$GCP_ENV_DIR/$project_key.env"
    key_file="$CREDENTIALS_PROJECTS_DIR/$project_key/finerio-key.json"

    if [[ -f "$env_file" && "$force" != "true" ]]; then
      continue
    fi

    cat >"$env_file" <<ENVFILE
# Auto-generado por install-opencode-gcp.sh
PROJECT_KEY="$project_key"
PROJECT_ID="$project_id"
LOCATION="$region"
GOOGLE_APPLICATION_CREDENTIALS="$key_file"
ENVFILE
    chmod 600 "$env_file"
  done

  log "Entornos GCP disponibles en: $GCP_ENV_DIR"
}

write_shell_module_if_missing() {
  local force="$1"

  mkdir -p "$SHELL_MODULE_DIR"

  if [[ -f "$SHELL_MODULE_FILE" && "$force" != "true" ]]; then
    log "Módulo shell existente: $SHELL_MODULE_FILE"
    return 0
  fi

  cat >"$SHELL_MODULE_FILE" <<EOF
#!/usr/bin/env bash
# Módulo de utilidades GCP para cargar desde ~/.zshrc o ~/.bashrc

: "\${OPENCODE_GCP_CONFIG_ROOT:=$CONFIG_ROOT}"
: "\${OPENCODE_GCP_ENV_DIR:=$GCP_ENV_DIR}"
: "\${OPENCODE_GCP_ACTIVE_KEY_PATH:=\${OPENCODE_GCP_CONFIG_ROOT}/credentials/active/finerio-key.json}"
: "\${OPENCODE_GCP_OPENCODE_JSON_FILE:=$OPENCODE_JSON_FILE}"

gcp-list() {
  local env_file
  local found=0
  local name
  local project_id

  for env_file in "\$OPENCODE_GCP_ENV_DIR"/*.env; do
    [[ -e "\$env_file" ]] || continue
    found=1
    name="\$(basename "\$env_file" .env)"
    project_id="\$(grep '^PROJECT_ID=' "\$env_file" | head -n 1 | cut -d '=' -f 2- | tr -d '\"')"
    printf "%s -> %s\n" "\$name" "\${project_id:-N/A}"
  done

  if [[ "\$found" -eq 0 ]]; then
    echo "No hay env files en \$OPENCODE_GCP_ENV_DIR"
  fi
}

use-gcp() {
  local env_name="\$1"
  local env_file
  local tmp_json

  if [[ -z "\$env_name" ]]; then
    echo "Uso: use-gcp <mapped-project>"
    gcp-list
    return 1
  fi

  env_file="\$OPENCODE_GCP_ENV_DIR/\${env_name}.env"
  if [[ ! -f "\$env_file" ]]; then
    echo "Env file not found: \$env_file"
    gcp-list
    return 1
  fi

  set -a
  # shellcheck disable=SC1090
  . "\$env_file"
  set +a

  : "\${PROJECT_ID:?PROJECT_ID no está definido en \$env_file}"
  : "\${LOCATION:=us-central1}"

  export GOOGLE_CLOUD_PROJECT="\$PROJECT_ID"
  export VERTEX_LOCATION="\$LOCATION"
  export GOOGLE_VERTEX_PROJECT="\$PROJECT_ID"
  export GOOGLE_VERTEX_LOCATION="\$LOCATION"

  if [[ -n "\${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
    if [[ ! -f "\$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
      echo "Key file not found: \$GOOGLE_APPLICATION_CREDENTIALS"
      return 1
    fi

    mkdir -p "\$(dirname "\$OPENCODE_GCP_ACTIVE_KEY_PATH")"
    ln -sfn "\$GOOGLE_APPLICATION_CREDENTIALS" "\$OPENCODE_GCP_ACTIVE_KEY_PATH"
    export GOOGLE_APPLICATION_CREDENTIALS="\$OPENCODE_GCP_ACTIVE_KEY_PATH"
  fi

  if command -v gcloud >/dev/null 2>&1; then
    gcloud config set project "\$PROJECT_ID" >/dev/null
  fi

  if [[ -f "\$OPENCODE_GCP_OPENCODE_JSON_FILE" ]] && command -v jq >/dev/null 2>&1; then
    tmp_json="\$(mktemp "\${TMPDIR:-/tmp}/opencode-json.XXXXXX")"
    if jq --arg project "\$PROJECT_ID" --arg location "\$LOCATION" \\
      '.provider.finerio.options.project=\$project | .provider.finerio.options.location=\$location' \\
      "\$OPENCODE_GCP_OPENCODE_JSON_FILE" >"\$tmp_json"; then
      mv "\$tmp_json" "\$OPENCODE_GCP_OPENCODE_JSON_FILE"
    else
      rm -f "\$tmp_json"
      echo "No se pudo actualizar opencode.json"
      return 1
    fi
  fi

  echo "GCP env active: \$env_name"
  echo "  Project : \$PROJECT_ID"
  echo "  Region  : \$LOCATION"
  echo "  Key     : \${GOOGLE_APPLICATION_CREDENTIALS:-ADC}"
}
EOF

  chmod +x "$SHELL_MODULE_FILE"
  log "Módulo shell creado: $SHELL_MODULE_FILE"
}

print_shell_hook_hint() {
  cat <<EOF
Carga el módulo en ~/.zshrc o ~/.bashrc con:
  [[ -f "$SHELL_MODULE_FILE" ]] && source "$SHELL_MODULE_FILE"
EOF
}

write_opencode_env_if_missing() {
  if [[ -f "$OPENCODE_ENV_FILE" ]]; then
    log "Configuración OpenCode existente: $OPENCODE_ENV_FILE"
    return 0
  fi

  cat >"$OPENCODE_ENV_FILE" <<'ENVFILE'
# Configuración única de OpenCode (independiente del proyecto).
# Este archivo se carga siempre que ejecutas opencode-gcp.
#
# Ejemplos opcionales:
# OPENCODE_DEFAULT_MODEL="google/gemini-2.5-pro"
# OPENCODE_LOG_LEVEL="info"
ENVFILE

  chmod 600 "$OPENCODE_ENV_FILE"
  log "Configuración OpenCode creada: $OPENCODE_ENV_FILE"
}

write_opencode_json_if_missing() {
  local region="$1"
  local force="$2"
  local backup_file

  mkdir -p "$OPENCODE_CONFIG_DIR"

  if [[ -f "$OPENCODE_JSON_FILE" && "$force" != "true" ]]; then
    log "Config principal OpenCode existente: $OPENCODE_JSON_FILE"
    return 0
  fi

  if [[ -f "$OPENCODE_JSON_FILE" && "$force" == "true" ]]; then
    backup_file="$OPENCODE_JSON_FILE.bak.$(date +%Y%m%d%H%M%S)"
    cp "$OPENCODE_JSON_FILE" "$backup_file"
    warn "Se creó respaldo de opencode.json en: $backup_file"
  fi

  cat >"$OPENCODE_JSON_FILE" <<JSON
{
  "\$schema": "https://opencode.ai/config.json",
  "theme": "matrix",
  "mcp": {
    "browser": {
      "type": "local",
      "command": ["node", "$DEFAULT_MCP_BROWSER_PATH"]
    }
  },
  "provider": {
    "finerio": {
      "npm": "@ai-sdk/google-vertex",
      "name": "Finerio Models",
      "options": {
        "project": "$DEFAULT_VERTEX_PROJECT_ID",
        "location": "$region"
      },
      "models": {
        "finerio/fast": {
          "name": "Gemini Fast",
          "id": "gemini-2.5-flash",
          "attachment": true,
          "tool_call": true,
          "limit": {
            "context": 1000000,
            "output": 65536
          }
        },
        "finerio/deep": {
          "name": "Gemini Pro",
          "id": "gemini-2.5-pro",
          "attachment": true,
          "tool_call": true,
          "limit": {
            "context": 1000000,
            "output": 65536
          }
        }
      }
    }
  },
  "agent": {
    "Scraper Architect": {
      "model": "finerio/finerio/deep",
      "prompt": "You are a Requirements Analyst specialized in web portals and automated scraping..."
    }
  },
  "model": "finerio/finerio/deep"
}
JSON

  chmod 600 "$OPENCODE_JSON_FILE"
  log "Config base OpenCode creada: $OPENCODE_JSON_FILE"

  if [[ ! -f "$DEFAULT_MCP_BROWSER_PATH" ]]; then
    warn "No se encontró MCP browser en '$DEFAULT_MCP_BROWSER_PATH'. Ajusta la ruta en $OPENCODE_JSON_FILE."
  fi
}

install_opencode() {
  if command -v opencode >/dev/null 2>&1; then
    log "OpenCode ya está instalado en: $(command -v opencode)"
    return 0
  fi

  log "Instalando OpenCode desde $OPENCODE_INSTALL_URL ..."
  curl -fsSL "$OPENCODE_INSTALL_URL" | bash

  command -v opencode >/dev/null 2>&1 || fail "OpenCode no quedó disponible en PATH tras la instalación."
  log "OpenCode instalado en: $(command -v opencode)"
}

install_wrapper() {
  cat >"$WRAPPER_PATH" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail

CONFIG_ROOT="${OPENCODE_GCP_CONFIG_ROOT:-$HOME/.config/opencode-gcp}"
PROFILE_DIR="${OPENCODE_GCP_PROFILE_DIR:-$CONFIG_ROOT/profiles}"
PROFILE_FILE="${OPENCODE_GCP_PROFILE_FILE:-$PROFILE_DIR/developer-tools.env}"
OPENCODE_ENV_FILE="${OPENCODE_GCP_OPENCODE_ENV_FILE:-$CONFIG_ROOT/opencode.env}"
OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
OPENCODE_JSON_FILE="${OPENCODE_GCP_OPENCODE_JSON_FILE:-$OPENCODE_CONFIG_DIR/opencode.json}"
FIXED_GCP_PROJECT="${OPENCODE_GCP_PROJECT_ID:-developer-tools-482502}"

log() { printf "[INFO] %s\n" "$*"; }
warn() { printf "[WARN] %s\n" "$*" >&2; }
fail() { printf "[ERROR] %s\n" "$*" >&2; exit 1; }

usage() {
  cat <<USAGE
Uso:
  opencode-gcp [--] [argumentos de opencode]
  opencode-gcp --doctor
  opencode-gcp --show-config

Notas:
  - Existe un único opencode-gcp.
  - Siempre usa el perfil de credenciales definido en developer-tools.env.

Ejemplos:
  opencode-gcp
  opencode-gcp -- -m google/gemini-2.5-pro
  opencode-gcp --doctor
USAGE
}

ensure_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || fail "No se encontró '$cmd'."
}

load_profile() {
  [[ -f "$PROFILE_FILE" ]] || fail "No existe el perfil: $PROFILE_FILE"

  set -a
  # shellcheck disable=SC1090
  . "$PROFILE_FILE"
  set +a

  : "${GOOGLE_CLOUD_PROJECT:?GOOGLE_CLOUD_PROJECT no está definido en $PROFILE_FILE}"
  : "${VERTEX_LOCATION:=global}"

  export GOOGLE_CLOUD_PROJECT
  export VERTEX_LOCATION
  export GOOGLE_VERTEX_PROJECT="${GOOGLE_VERTEX_PROJECT:-$GOOGLE_CLOUD_PROJECT}"
  export GOOGLE_VERTEX_LOCATION="${GOOGLE_VERTEX_LOCATION:-$VERTEX_LOCATION}"
}

load_opencode_env() {
  if [[ ! -f "$OPENCODE_ENV_FILE" ]]; then
    warn "No existe $OPENCODE_ENV_FILE. Continúo con defaults."
    return 0
  fi

  set -a
  # shellcheck disable=SC1090
  . "$OPENCODE_ENV_FILE"
  set +a
}

activate_gcloud_configuration() {
  if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
    log "GOOGLE_APPLICATION_CREDENTIALS detectado; se omite activación de gcloud."
    return 0
  fi

  if ! command -v gcloud >/dev/null 2>&1; then
    warn "gcloud no está instalado. Se omite activación de configuración."
    return 0
  fi

  if [[ -n "${GCLOUD_CONFIGURATION:-}" ]] && gcloud config configurations describe "$GCLOUD_CONFIGURATION" >/dev/null 2>&1; then
    gcloud config configurations activate "$GCLOUD_CONFIGURATION" >/dev/null
    log "Configuración gcloud activada: $GCLOUD_CONFIGURATION"
  fi

  gcloud config set project "$GOOGLE_CLOUD_PROJECT" >/dev/null
}

check_auth() {
  if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]]; then
    [[ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]] || fail "No existe GOOGLE_APPLICATION_CREDENTIALS: $GOOGLE_APPLICATION_CREDENTIALS. Copia tu finerio key.json a esa ruta."
    if grep -q 'replace-me' "$GOOGLE_APPLICATION_CREDENTIALS" 2>/dev/null; then
      fail "GOOGLE_APPLICATION_CREDENTIALS apunta a un placeholder: $GOOGLE_APPLICATION_CREDENTIALS. Reemplaza con tu finerio key.json real."
    fi
    return 0
  fi

  if ! command -v gcloud >/dev/null 2>&1; then
    fail "Sin GOOGLE_APPLICATION_CREDENTIALS y sin gcloud. Instala gcloud o define credenciales."
  fi

  if gcloud auth application-default print-access-token >/dev/null 2>&1; then
    return 0
  fi

  warn "No hay credenciales ADC activas para este entorno."
  warn "Ejecuta: gcloud auth application-default login"
  exit 1
}

doctor() {
  ensure_cmd opencode
  load_profile
  load_opencode_env
  if [[ "$GOOGLE_CLOUD_PROJECT" != "$FIXED_GCP_PROJECT" ]]; then
    warn "El perfil usa GOOGLE_CLOUD_PROJECT='$GOOGLE_CLOUD_PROJECT'. Se recomienda '$FIXED_GCP_PROJECT'."
  fi
  activate_gcloud_configuration
  check_auth
  log "Doctor OK (project: $GOOGLE_CLOUD_PROJECT, region: $VERTEX_LOCATION)."
}

show_config() {
  load_profile
  load_opencode_env
  cat <<CFG
PROFILE_FILE=$PROFILE_FILE
OPENCODE_ENV_FILE=$OPENCODE_ENV_FILE
OPENCODE_JSON_FILE=$OPENCODE_JSON_FILE
GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT
VERTEX_LOCATION=$VERTEX_LOCATION
GCLOUD_CONFIGURATION=${GCLOUD_CONFIGURATION:-}
GOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_APPLICATION_CREDENTIALS:-}
OPENCODE_DEFAULT_MODEL=${OPENCODE_DEFAULT_MODEL:-}
CFG
}

main() {
  local run_doctor="false"
  local run_show_config="false"
  local -a opencode_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage
        exit 0
        ;;
      --doctor)
        run_doctor="true"
        ;;
      --show-config)
        run_show_config="true"
        ;;
      --)
        shift
        opencode_args+=("$@")
        break
        ;;
      *)
        opencode_args+=("$1")
        ;;
    esac
    shift
  done

  if [[ "$run_show_config" == "true" ]]; then
    show_config
    exit 0
  fi

  if [[ "$run_doctor" == "true" ]]; then
    doctor
    exit 0
  fi

  ensure_cmd opencode
  load_profile
  load_opencode_env

  if [[ "$GOOGLE_CLOUD_PROJECT" != "$FIXED_GCP_PROJECT" ]]; then
    warn "Perfil con GOOGLE_CLOUD_PROJECT='$GOOGLE_CLOUD_PROJECT'. Se esperaba '$FIXED_GCP_PROJECT'."
  fi

  activate_gcloud_configuration
  check_auth

  log "Iniciando OpenCode con credenciales del proyecto '$GOOGLE_CLOUD_PROJECT' ..."
  exec opencode "${opencode_args[@]}"
}

main "$@"
WRAPPER

  chmod +x "$WRAPPER_PATH"
  log "Comando instalado: $WRAPPER_PATH"
}

ensure_path_hint() {
  if [[ ":$PATH:" == *":$WRAPPER_DIR:"* ]]; then
    return 0
  fi
  warn "Agrega '$WRAPPER_DIR' a tu PATH para usar 'opencode-gcp' desde cualquier terminal."
}

verify_project_access() {
  if ! command -v gcloud >/dev/null 2>&1; then
    warn "gcloud no está instalado; no se valida acceso al proyecto '$FIXED_GCP_PROJECT'."
    return 0
  fi

  if gcloud projects describe "$FIXED_GCP_PROJECT" --format="value(projectId)" >/dev/null 2>&1; then
    log "Acceso validado a proyecto: $FIXED_GCP_PROJECT"
  else
    warn "No se pudo validar acceso a '$FIXED_GCP_PROJECT'. Verifica permisos/cuenta de gcloud."
  fi
}

main() {
  local selected_region="$DEFAULT_REGION"
  local force="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage
        exit 0
        ;;
      --region)
        shift
        [[ $# -gt 0 ]] || fail "Falta valor para --region"
        selected_region="$1"
        ;;
      --force)
        force="true"
        ;;
      *)
        fail "Opción no soportada: $1 (usa --help)"
        ;;
    esac
    shift
  done

  is_supported_os || fail "Sistema no soportado por este instalador (usa macOS/Linux o WSL)."
  ensure_cmd bash
  ensure_cmd curl

  mkdir -p "$CONFIG_ROOT"
  mkdir -p "$PROFILE_DIR"
  mkdir -p "$WRAPPER_DIR"
  mkdir -p "$OPENCODE_CONFIG_DIR"
  mkdir -p "$GCP_ENV_DIR"
  mkdir -p "$SHELL_MODULE_DIR"

  install_opencode
  ensure_credentials_layout
  write_gcp_env_files "$selected_region" "$force"
  write_profile_if_missing "$selected_region" "$force"
  write_opencode_env_if_missing
  write_opencode_json_if_missing "$selected_region" "$force"
  verify_project_access

  install_wrapper
  write_shell_module_if_missing "$force"
  ensure_path_hint

  cat <<SUMMARY

Instalación terminada.

Comandos principales:
  opencode-gcp --doctor
  opencode-gcp --show-config
  opencode-gcp

Perfil único:
  $PROFILE_FILE

Configuración única OpenCode:
  $OPENCODE_ENV_FILE
  $OPENCODE_JSON_FILE

Estructura estándar de credenciales:
  $CREDENTIALS_PROJECTS_DIR/<mapped-project>/finerio-key.json
  $CREDENTIALS_PROJECTS_DIR/projects-map.txt
  $ACTIVE_KEY_PATH   (ruta activa usada por opencode-gcp)

Entornos para use-gcp:
  $GCP_ENV_DIR/<mapped-project>.env

Módulo shell:
  $SHELL_MODULE_FILE

Este setup usa credenciales de '$FIXED_GCP_PROJECT' para cualquier uso de opencode-gcp.
Para activar un key.json, cópialo a:
  $ACTIVE_KEY_PATH
SUMMARY

  print_shell_hook_hint
}

main "$@"
