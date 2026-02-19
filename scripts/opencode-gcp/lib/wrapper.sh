#!/usr/bin/env bash

opencode_gcp_install_wrapper() {
  cat >"$WRAPPER_PATH" <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail

CONFIG_ROOT="${OPENCODE_GCP_CONFIG_ROOT:-$HOME/.config/opencode-gcp}"
PROFILE_DIR="${OPENCODE_GCP_PROFILE_DIR:-$CONFIG_ROOT/profiles}"
PROFILE_FILE="${OPENCODE_GCP_PROFILE_FILE:-$PROFILE_DIR/developer-tools.env}"
ACTIVE_KEY_PATH="${OPENCODE_GCP_ACTIVE_KEY_PATH:-$CONFIG_ROOT/credentials/active/finerio-key.json}"
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
  opencode-gcp --debug-credentials [--] [argumentos de opencode]

Notas:
  - Existe un único opencode-gcp.
  - Siempre usa la key activa: credentials/active/finerio-key.json.
  - --debug-credentials imprime credenciales en texto plano (solo para diagnóstico local).

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
  export GOOGLE_APPLICATION_CREDENTIALS="$ACTIVE_KEY_PATH"
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
  log "Se usará credencial fija en '$GOOGLE_APPLICATION_CREDENTIALS'; se omite activación de gcloud."
}

check_auth() {
  [[ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]] || fail "No existe finerio key activa: $GOOGLE_APPLICATION_CREDENTIALS"
  if grep -q 'replace-me' "$GOOGLE_APPLICATION_CREDENTIALS" 2>/dev/null; then
    fail "La key activa es placeholder: $GOOGLE_APPLICATION_CREDENTIALS. Reemplaza con tu finerio key.json real."
  fi
}

print_plain_credentials_debug() {
  local debug_enabled="$1"

  if [[ "$debug_enabled" != "true" ]]; then
    return 0
  fi

  warn "DEBUG habilitado: se imprimirá información sensible en texto plano."
  cat <<DEBUG_INFO
----- BEGIN OPENCODE-GCP CREDENTIAL PAYLOAD (PLAINTEXT) -----
GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT
VERTEX_LOCATION=$VERTEX_LOCATION
GOOGLE_VERTEX_PROJECT=${GOOGLE_VERTEX_PROJECT:-}
GOOGLE_VERTEX_LOCATION=${GOOGLE_VERTEX_LOCATION:-}
GOOGLE_APPLICATION_CREDENTIALS=$GOOGLE_APPLICATION_CREDENTIALS
----- BEGIN GOOGLE_APPLICATION_CREDENTIALS JSON -----
DEBUG_INFO
  cat "$GOOGLE_APPLICATION_CREDENTIALS"
  cat <<DEBUG_INFO
----- END GOOGLE_APPLICATION_CREDENTIALS JSON -----
----- END OPENCODE-GCP CREDENTIAL PAYLOAD (PLAINTEXT) -----
DEBUG_INFO
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
  local debug_credentials="${OPENCODE_GCP_DEBUG_CREDENTIALS:-false}"
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
      --debug-credentials)
        debug_credentials="true"
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
  print_plain_credentials_debug "$debug_credentials"

  log "Iniciando OpenCode con credenciales del proyecto '$GOOGLE_CLOUD_PROJECT' ..."
  if [[ ${#opencode_args[@]} -eq 0 ]]; then
    exec opencode
  fi
  exec opencode "${opencode_args[@]}"
}

main "$@"
WRAPPER

  chmod +x "$WRAPPER_PATH"
  opencode_gcp_log "Comando instalado: $WRAPPER_PATH"
}
