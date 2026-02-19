#!/usr/bin/env bash

opencode_gcp_install_opencode() {
  local opencode_bin=""

  if command -v opencode >/dev/null 2>&1; then
    opencode_bin="$(command -v opencode)"
  elif [[ -x "$HOME/.opencode/bin/opencode" ]]; then
    opencode_bin="$HOME/.opencode/bin/opencode"
  fi

  if [[ -n "$opencode_bin" ]]; then
    opencode_gcp_log "OpenCode ya está instalado en: $opencode_bin"
    if [[ ":$PATH:" != *":$(dirname "$opencode_bin"):"* ]]; then
      opencode_gcp_warn "OpenCode existe pero no está en PATH. Agrega: export PATH=\"$(dirname "$opencode_bin"):\$PATH\""
    fi
    return 0
  fi

  opencode_gcp_log "Instalando OpenCode desde $OPENCODE_INSTALL_URL ..."
  curl -fsSL "$OPENCODE_INSTALL_URL" | bash

  command -v opencode >/dev/null 2>&1 || opencode_gcp_fail "OpenCode no quedó disponible en PATH tras la instalación."
  opencode_gcp_log "OpenCode instalado en: $(command -v opencode)"
}

opencode_gcp_print_summary() {
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

  opencode_gcp_print_shell_hook_hint
}

opencode_gcp_main() {
  opencode_gcp_init_defaults

  local selected_region="$DEFAULT_REGION"
  local force_all="false"
  local force_opencode_config="false"
  local force_opencode_json="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        opencode_gcp_usage
        exit 0
        ;;
      --region)
        shift
        [[ $# -gt 0 ]] || opencode_gcp_fail "Falta valor para --region"
        selected_region="$1"
        ;;
      --force)
        force_all="true"
        ;;
      --force-opencode-config)
        force_opencode_config="true"
        ;;
      *)
        opencode_gcp_fail "Opción no soportada: $1 (usa --help)"
        ;;
    esac
    shift
  done

  opencode_gcp_is_supported_os || opencode_gcp_fail "Sistema no soportado por este instalador (usa macOS/Linux o WSL)."
  opencode_gcp_ensure_cmd bash
  opencode_gcp_ensure_cmd curl

  opencode_gcp_prepare_dirs
  if [[ "$force_all" == "true" || "$force_opencode_config" == "true" ]]; then
    force_opencode_json="true"
  fi

  opencode_gcp_install_opencode
  opencode_gcp_ensure_credentials_layout
  opencode_gcp_write_gcp_env_files "$selected_region" "$force_all"
  opencode_gcp_write_profile_if_missing "$selected_region" "$force_all"
  opencode_gcp_write_opencode_env_if_missing
  opencode_gcp_write_opencode_json_if_missing "$selected_region" "$force_opencode_json"
  opencode_gcp_verify_project_access

  opencode_gcp_install_wrapper
  opencode_gcp_write_shell_module_if_missing "$force_all"
  opencode_gcp_ensure_path_hint

  opencode_gcp_print_summary
}
