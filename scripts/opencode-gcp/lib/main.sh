#!/usr/bin/env bash

opencode_gcp_install_rtk() {
  if command -v rtk >/dev/null 2>&1; then
    opencode_gcp_log "RTK ya está instalado en: $(command -v rtk)"
    return 0
  fi

  opencode_gcp_log "Instalando RTK ..."
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh

  command -v rtk >/dev/null 2>&1 || opencode_gcp_warn "RTK no quedó disponible en PATH tras la instalación. Reinicia tu terminal o agrega su ruta al PATH."
  opencode_gcp_log "RTK instalado en: $(command -v rtk)"
}

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

opencode_gcp_update_opencode() {
  opencode_gcp_log "Actualizando OpenCode desde $OPENCODE_INSTALL_URL ..."
  curl -fsSL "$OPENCODE_INSTALL_URL" | bash

  command -v opencode >/dev/null 2>&1 || opencode_gcp_fail "OpenCode no quedó disponible en PATH tras la actualización."
  opencode_gcp_log "OpenCode actualizado en: $(command -v opencode)"
}

opencode_gcp_print_summary() {
  printf "\n${_C_BOLD}${_C_GREEN}Instalación terminada.${_C_RESET}\n\n"
  printf "${_C_BOLD}Comandos principales:${_C_RESET}\n"
  printf "  ${_C_CYAN}opencode-gcp --doctor${_C_RESET}\n"
  printf "  ${_C_CYAN}opencode-gcp --show-config${_C_RESET}\n"
  printf "  ${_C_CYAN}opencode-gcp${_C_RESET}\n\n"
  printf "${_C_BOLD}Perfil único:${_C_RESET}\n"
  printf "  ${_C_CYAN}%s${_C_RESET}\n\n" "$PROFILE_FILE"
  printf "${_C_BOLD}Configuración única OpenCode:${_C_RESET}\n"
  printf "  ${_C_CYAN}%s${_C_RESET}\n" "$OPENCODE_ENV_FILE"
  printf "  ${_C_CYAN}%s${_C_RESET}\n\n" "$OPENCODE_JSON_FILE"
  printf "${_C_BOLD}Estructura estándar de credenciales:${_C_RESET}\n"
  printf "  ${_C_CYAN}%s/<mapped-project>/finerio-key.json${_C_RESET}\n" "$CREDENTIALS_PROJECTS_DIR"
  printf "  ${_C_CYAN}%s/projects-map.txt${_C_RESET}\n" "$CREDENTIALS_PROJECTS_DIR"
  printf "  ${_C_CYAN}%s${_C_RESET}   (ruta activa usada por opencode-gcp)\n\n" "$ACTIVE_KEY_PATH"
  printf "${_C_BOLD}Entornos para use-gcp:${_C_RESET}\n"
  printf "  ${_C_CYAN}%s/<mapped-project>.env${_C_RESET}\n\n" "$GCP_ENV_DIR"
  printf "${_C_BOLD}Módulo shell:${_C_RESET}\n"
  printf "  ${_C_CYAN}%s${_C_RESET}\n\n" "$SHELL_MODULE_FILE"
  printf "Este setup usa credenciales de ${_C_BOLD}'%s'${_C_RESET} para cualquier uso de opencode-gcp.\n" "$FIXED_GCP_PROJECT"
  printf "Para activar un key.json, cópialo a:\n"
  printf "  ${_C_CYAN}%s${_C_RESET}\n" "$ACTIVE_KEY_PATH"

  opencode_gcp_print_shell_hook_hint
}

opencode_gcp_main() {
  opencode_gcp_init_defaults

  local selected_region="$DEFAULT_REGION"
  local force_all="false"
  local force_opencode_config="false"
  local force_opencode_json="false"
  local update_opencode="false"

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
      --update)
        update_opencode="true"
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

  opencode_gcp_install_rtk
  if [[ "$update_opencode" == "true" ]]; then
    opencode_gcp_update_opencode
  else
    opencode_gcp_install_opencode
  fi
  opencode_gcp_ensure_credentials_layout
  opencode_gcp_write_gcp_env_files "$selected_region" "$force_all"
  opencode_gcp_write_profile_if_missing "$selected_region" "$force_all"
  opencode_gcp_write_opencode_env_if_missing
  opencode_gcp_write_opencode_json "$selected_region" "$force_opencode_json"
  opencode_gcp_verify_project_access

  opencode_gcp_install_wrapper
  opencode_gcp_write_shell_module_if_missing "$force_all"
  opencode_gcp_ensure_path_hint

  opencode_gcp_print_summary
}
