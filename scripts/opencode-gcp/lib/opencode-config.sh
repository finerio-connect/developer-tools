#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# opencode-config.sh
#
# Ensambla opencode.json a partir de los archivos JSON modulares en config/.
# Para agregar un nuevo MCP server, modelo o agente, edita el JSON
# correspondiente en scripts/opencode-gcp/config/.
# ---------------------------------------------------------------------------

opencode_gcp_resolve_config_dir() {
  if [[ -n "${OPENCODE_GCP_CONFIG_FILES_DIR:-}" ]]; then
    printf "%s" "$OPENCODE_GCP_CONFIG_FILES_DIR"
    return 0
  fi

  if [[ -n "${OPENCODE_GCP_INSTALL_ROOT:-}" ]]; then
    printf "%s" "$OPENCODE_GCP_INSTALL_ROOT/scripts/opencode-gcp/config"
    return 0
  fi

  opencode_gcp_fail "No se pudo determinar la ruta de los archivos de configuración."
}

opencode_gcp_substitute_placeholders() {
  local content="$1"
  shift

  while [[ $# -ge 2 ]]; do
    local placeholder="$1"
    local value="$2"
    content="${content//\{\{$placeholder\}\}/$value}"
    shift 2
  done

  printf "%s" "$content"
}

opencode_gcp_build_opencode_json() {
  local region="$1"
  local config_dir
  config_dir="$(opencode_gcp_resolve_config_dir)"

  local base_json mcp_json providers_json agents_json

  # Leer archivos de configuración
  base_json="$(cat "$config_dir/base.json")" \
    || opencode_gcp_fail "No se pudo leer $config_dir/base.json"
  mcp_json="$(cat "$config_dir/mcp-servers.json")" \
    || opencode_gcp_fail "No se pudo leer $config_dir/mcp-servers.json"
  providers_json="$(cat "$config_dir/providers.json")" \
    || opencode_gcp_fail "No se pudo leer $config_dir/providers.json"
  agents_json="$(cat "$config_dir/agents.json")" \
    || opencode_gcp_fail "No se pudo leer $config_dir/agents.json"

  # Resolver promptFile -> prompt en agentes
  local prompts_dir="$config_dir/prompts"
  local agents_tmp filter_tmp
  agents_tmp="$(mktemp)"
  filter_tmp="$(mktemp)"
  printf '%s\n' "$agents_json" > "$agents_tmp"

  local jq_args=()
  printf '.' > "$filter_tmp"
  local prompt_files
  prompt_files="$(jq -r 'to_entries[] | select(.value.promptFile) | "\(.key)\t\(.value.promptFile)"' "$agents_tmp")"
  local idx=0
  while IFS=$'\t' read -r agent_name prompt_file; do
    [[ -z "$agent_name" ]] && continue
    local prompt_path="$prompts_dir/$prompt_file"
    [[ -f "$prompt_path" ]] || opencode_gcp_fail "No se encontró prompt: $prompt_path"
    jq_args+=(--rawfile "p${idx}" "$prompt_path" --arg "n${idx}" "$agent_name")
    printf ' | .[($n%s)] = (.[($n%s)] | del(.promptFile) + {prompt: $p%s})' "$idx" "$idx" "$idx" >> "$filter_tmp"
    idx=$((idx + 1))
  done <<< "$prompt_files"

  if [[ ${#jq_args[@]} -gt 0 ]]; then
    agents_json="$(jq "${jq_args[@]}" -f "$filter_tmp" "$agents_tmp")"
  fi
  rm -f "$agents_tmp" "$filter_tmp"

  # Sustituir placeholders en MCP servers
  mcp_json="$(opencode_gcp_substitute_placeholders "$mcp_json" \
    "MCP_BROWSER_PATH"        "$DEFAULT_MCP_BROWSER_PATH" \
    "MCP_FINERIO_CONNECT_URL" "$DEFAULT_MCP_FINERIO_CONNECT_URL" \
    "MCP_GITHUB_URL"          "$DEFAULT_MCP_GITHUB_URL"
  )"

  # Sustituir placeholders en providers
  providers_json="$(opencode_gcp_substitute_placeholders "$providers_json" \
    "VERTEX_PROJECT"  "$DEFAULT_VERTEX_PROJECT_ID" \
    "VERTEX_LOCATION" "$region"
  )"

  # Ensamblar JSON final con jq
  jq -n \
    --argjson base      "$base_json" \
    --argjson mcp       "$mcp_json" \
    --argjson provider  "$providers_json" \
    --argjson agent     "$agents_json" \
    '$base + {"mcp": $mcp, "provider": $provider, "agent": (($base.agent // {}) + $agent)}'
}

opencode_gcp_install_themes() {
  local config_dir
  config_dir="$(opencode_gcp_resolve_config_dir)"

  local themes_src="$config_dir/themes"
  local themes_dest="$OPENCODE_CONFIG_DIR/themes"

  if [[ ! -d "$themes_src" ]]; then
    return 0
  fi

  mkdir -p "$themes_dest"

  local theme_file theme_name theme_content
  for theme_file in "$themes_src"/*.json; do
    [[ -e "$theme_file" ]] || continue
    theme_name="$(basename "$theme_file")"
    theme_content="$(cat "$theme_file")" \
      || { opencode_gcp_warn "No se pudo leer tema: $theme_name"; continue; }

    printf "%s\n" "$theme_content" > "$themes_dest/$theme_name"
    opencode_gcp_log "Tema generado: $themes_dest/$theme_name"
  done
}

opencode_gcp_write_tui_json() {
  local force="$1"
  local config_dir
  config_dir="$(opencode_gcp_resolve_config_dir)"

  local tui_src="$config_dir/tui.json"

  if [[ ! -f "$tui_src" ]]; then
    opencode_gcp_warn "No se encontró $tui_src; se omite tui.json."
    return 0
  fi

  if [[ -f "$OPENCODE_TUI_JSON_FILE" && "$force" != "true" ]]; then
    opencode_gcp_log "Config TUI existente: $OPENCODE_TUI_JSON_FILE"
    return 0
  fi

  local tui_content
  tui_content="$(cat "$tui_src")" \
    || opencode_gcp_fail "No se pudo leer $tui_src"

  printf "%s\n" "$tui_content" > "$OPENCODE_TUI_JSON_FILE"
  opencode_gcp_log "Config TUI generada: $OPENCODE_TUI_JSON_FILE"
}

opencode_gcp_write_opencode_json() {
  local region="$1"
  local force="$2"
  local backup_file
  local assembled_json

  mkdir -p "$OPENCODE_CONFIG_DIR"

  # Generar temas y tui.json
  opencode_gcp_install_themes
  opencode_gcp_write_tui_json "$force"

  if [[ -f "$OPENCODE_JSON_FILE" && "$force" != "true" ]]; then
    opencode_gcp_log "Config principal OpenCode existente: $OPENCODE_JSON_FILE"
    return 0
  fi

  # Verificar que jq esté disponible
  if ! command -v jq >/dev/null 2>&1; then
    opencode_gcp_fail "Se requiere 'jq' para generar opencode.json. Instálalo con: brew install jq"
  fi

  if [[ -f "$OPENCODE_JSON_FILE" && "$force" == "true" ]]; then
    backup_file="$OPENCODE_JSON_FILE.bak.$(date +%Y%m%d%H%M%S)"
    cp "$OPENCODE_JSON_FILE" "$backup_file"
    opencode_gcp_warn "Se creó respaldo de opencode.json en: $backup_file"
  fi

  assembled_json="$(opencode_gcp_build_opencode_json "$region")"

  printf "%s\n" "$assembled_json" > "$OPENCODE_JSON_FILE"
  chmod 600 "$OPENCODE_JSON_FILE"
  opencode_gcp_log "Config base OpenCode creada: $OPENCODE_JSON_FILE"

  if [[ ! -f "$DEFAULT_MCP_BROWSER_PATH" ]]; then
    opencode_gcp_warn "No se encontró MCP browser en '$DEFAULT_MCP_BROWSER_PATH'. Ajusta la ruta en $OPENCODE_JSON_FILE."
  fi
}
