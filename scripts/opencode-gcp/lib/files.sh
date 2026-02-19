#!/usr/bin/env bash

opencode_gcp_write_profile_if_missing() {
  local region="$1"
  local force="$2"

  if [[ -f "$PROFILE_FILE" && "$force" != "true" ]]; then
    opencode_gcp_log "Perfil existente: $PROFILE_FILE (no se modifica)"
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
  opencode_gcp_log "Perfil generado: $PROFILE_FILE"
}

opencode_gcp_ensure_credentials_layout() {
  local idx
  local project_key
  local project_id
  local project_dir
  local map_file

  mkdir -p "$CREDENTIALS_PROJECTS_DIR"
  mkdir -p "$CREDENTIALS_ACTIVE_DIR"

  [[ ${#MAPPED_PROJECT_KEYS[@]} -eq ${#MAPPED_PROJECT_IDS[@]} ]] || opencode_gcp_fail "Catálogo de proyectos inválido en el script."
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
  "private_key": "-----BEGIN PRIVATE KEY-----\\nreplace-me\\n-----END PRIVATE KEY-----\\n",
  "client_email": "replace-me",
  "client_id": "replace-me",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token"
}
KEY_PLACEHOLDER
    chmod 600 "$ACTIVE_KEY_PATH"
    opencode_gcp_warn "Se creó placeholder en $ACTIVE_KEY_PATH. Reemplázalo con tu finerio key.json."
  fi
}

opencode_gcp_write_gcp_env_files() {
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

  opencode_gcp_log "Entornos GCP disponibles en: $GCP_ENV_DIR"
}

opencode_gcp_write_shell_module_if_missing() {
  local force="$1"

  mkdir -p "$SHELL_MODULE_DIR"

  if [[ -f "$SHELL_MODULE_FILE" && "$force" != "true" ]]; then
    opencode_gcp_log "Módulo shell existente: $SHELL_MODULE_FILE"
    return 0
  fi

  cat >"$SHELL_MODULE_FILE" <<MODULE
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
    printf "%s -> %s\\n" "\$name" "\${project_id:-N/A}"
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

_opencode_gcp_env_names() {
  local env_file
  for env_file in "\$OPENCODE_GCP_ENV_DIR"/*.env; do
    [[ -e "\$env_file" ]] || continue
    basename "\$env_file" .env
  done
}

_opencode_gcp_comp_use_gcp_zsh() {
  local env_name
  local -a envs
  envs=()

  while IFS= read -r env_name; do
    [[ -n "\$env_name" ]] || continue
    envs+=("\$env_name")
  done < <(_opencode_gcp_env_names)

  compadd -- "\${envs[@]}"
}

_opencode_gcp_comp_use_gcp_bash() {
  local cur opts
  cur="\${COMP_WORDS[COMP_CWORD]}"
  opts="\$(_opencode_gcp_env_names | tr '\\n' ' ')"
  COMPREPLY=( \$(compgen -W "\$opts" -- "\$cur") )
}

_opencode_gcp_enable_use_gcp_tab() {
  if [[ -n "\${ZSH_VERSION:-}" ]]; then
    typeset -f compdef >/dev/null 2>&1 || return 0
    compdef _opencode_gcp_comp_use_gcp_zsh use-gcp 2>/dev/null || true
    return 0
  fi

  if [[ -n "\${BASH_VERSION:-}" ]]; then
    complete -F _opencode_gcp_comp_use_gcp_bash use-gcp 2>/dev/null || true
  fi
}

_opencode_gcp_enable_postman_tab() {
  local shell_name
  local completion_script

  command -v postman >/dev/null 2>&1 || return 0

  if [[ -n "\${ZSH_VERSION:-}" ]]; then
    shell_name="zsh"
  elif [[ -n "\${BASH_VERSION:-}" ]]; then
    shell_name="bash"
  else
    return 0
  fi

  if completion_script="\$(postman completion \"\$shell_name\" 2>/dev/null)"; then
    [[ -n "\$completion_script" ]] && eval "\$completion_script"
    return 0
  fi

  if completion_script="\$(postman completion --shell \"\$shell_name\" 2>/dev/null)"; then
    [[ -n "\$completion_script" ]] && eval "\$completion_script"
    return 0
  fi
}

_opencode_gcp_enable_use_gcp_tab
_opencode_gcp_enable_postman_tab
MODULE

  chmod +x "$SHELL_MODULE_FILE"
  opencode_gcp_log "Módulo shell creado: $SHELL_MODULE_FILE"
}

opencode_gcp_print_shell_hook_hint() {
  cat <<HINT
Carga el módulo en ~/.zshrc o ~/.bashrc con:
  [[ -f "$SHELL_MODULE_FILE" ]] && source "$SHELL_MODULE_FILE"
HINT
}

opencode_gcp_write_opencode_env_if_missing() {
  if [[ -f "$OPENCODE_ENV_FILE" ]]; then
    opencode_gcp_log "Configuración OpenCode existente: $OPENCODE_ENV_FILE"
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
  opencode_gcp_log "Configuración OpenCode creada: $OPENCODE_ENV_FILE"
}

opencode_gcp_write_opencode_json_if_missing() {
  local region="$1"
  local force="$2"
  local backup_file

  mkdir -p "$OPENCODE_CONFIG_DIR"

  if [[ -f "$OPENCODE_JSON_FILE" && "$force" != "true" ]]; then
    opencode_gcp_log "Config principal OpenCode existente: $OPENCODE_JSON_FILE"
    return 0
  fi

  if [[ -f "$OPENCODE_JSON_FILE" && "$force" == "true" ]]; then
    backup_file="$OPENCODE_JSON_FILE.bak.$(date +%Y%m%d%H%M%S)"
    cp "$OPENCODE_JSON_FILE" "$backup_file"
    opencode_gcp_warn "Se creó respaldo de opencode.json en: $backup_file"
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
          "name": "Gemini 3.1 Pro",
          "id": "gemini-3.1-pro-preview",
          "attachment": true,
          "tool_call": true,
          "limit": {
            "context": 1000000,
            "output": 65536
          }
        },
        "finerio/deep": {
          "name": "Gemini 3.1 Flash",
          "id": "gemini-3-flash-preview",
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
  opencode_gcp_log "Config base OpenCode creada: $OPENCODE_JSON_FILE"

  if [[ ! -f "$DEFAULT_MCP_BROWSER_PATH" ]]; then
    opencode_gcp_warn "No se encontró MCP browser en '$DEFAULT_MCP_BROWSER_PATH'. Ajusta la ruta en $OPENCODE_JSON_FILE."
  fi
}

opencode_gcp_ensure_path_hint() {
  if [[ ":$PATH:" == *":$WRAPPER_DIR:"* ]]; then
    return 0
  fi
  opencode_gcp_warn "Agrega '$WRAPPER_DIR' a tu PATH para usar 'opencode-gcp' desde cualquier terminal."
}

opencode_gcp_verify_project_access() {
  if ! command -v gcloud >/dev/null 2>&1; then
    opencode_gcp_warn "gcloud no está instalado; no se valida acceso al proyecto '$FIXED_GCP_PROJECT'."
    return 0
  fi

  if gcloud projects describe "$FIXED_GCP_PROJECT" --format="value(projectId)" >/dev/null 2>&1; then
    opencode_gcp_log "Acceso validado a proyecto: $FIXED_GCP_PROJECT"
  else
    opencode_gcp_warn "No se pudo validar acceso a '$FIXED_GCP_PROJECT'. Verifica permisos/cuenta de gcloud."
  fi
}
