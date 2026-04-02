#!/usr/bin/env bash
set -euo pipefail

OPENCODE_GCP_MODULES=(
  "scripts/opencode-gcp/lib/common.sh"
  "scripts/opencode-gcp/lib/files.sh"
  "scripts/opencode-gcp/lib/opencode-config.sh"
  "scripts/opencode-gcp/lib/wrapper.sh"
  "scripts/opencode-gcp/lib/main.sh"
)

OPENCODE_GCP_CONFIG_FILES=(
  "scripts/opencode-gcp/config/base.json"
  "scripts/opencode-gcp/config/mcp-servers.json"
  "scripts/opencode-gcp/config/providers.json"
  "scripts/opencode-gcp/config/agents.json"
  "scripts/opencode-gcp/config/tui.json"
  "scripts/opencode-gcp/config/themes/finerio.json"
)
OPENCODE_GCP_REMOTE_BOOTSTRAP="false"
OPENCODE_GCP_INSTALL_ROOT=""

opencode_gcp_bootstrap_fail() {
  printf "[ERROR] %s\n" "$*" >&2
  exit 1
}

opencode_gcp_detect_local_root() {
  local script_source
  local script_dir

  script_source="${BASH_SOURCE[0]:-}"
  if [[ -z "$script_source" || "$script_source" == "bash" || "$script_source" == "-bash" ]]; then
    return 1
  fi

  if [[ ! -f "$script_source" ]]; then
    return 1
  fi

  script_dir="$(cd "$(dirname "$script_source")" && pwd)"
  if [[ -d "$script_dir/scripts/opencode-gcp/lib" ]]; then
    printf "%s\n" "$script_dir"
    return 0
  fi

  return 1
}

opencode_gcp_fetch_remote_files() {
  local base_url="$1"
  local target_root="$2"
  shift 2
  local file_path
  local target_path

  for file_path in "$@"; do
    target_path="$target_root/$file_path"
    mkdir -p "$(dirname "$target_path")"
    curl -fsSL "${base_url%/}/$file_path" -o "$target_path" || \
      opencode_gcp_bootstrap_fail "No se pudo descargar: ${base_url%/}/$file_path"
  done
}

opencode_gcp_fetch_prompt_files() {
  local base_url="$1"
  local target_root="$2"
  local agents_file="$target_root/scripts/opencode-gcp/config/agents.json"

  [[ -f "$agents_file" ]] || return 0

  local prompt_file
  local prompt_files=()
  while IFS= read -r prompt_file; do
    [[ -n "$prompt_file" ]] || continue
    prompt_files+=("scripts/opencode-gcp/config/prompts/$prompt_file")
  done < <(jq -r '[.[] | .promptFile // empty] | unique[]' "$agents_file" 2>/dev/null)

  if [[ ${#prompt_files[@]} -gt 0 ]]; then
    opencode_gcp_fetch_remote_files "$base_url" "$target_root" "${prompt_files[@]}"
  fi
}

opencode_gcp_fetch_modules() {
  local base_url="$1"
  local target_root="$2"

  command -v curl >/dev/null 2>&1 || opencode_gcp_bootstrap_fail "curl es requerido para bootstrap remoto."

  opencode_gcp_fetch_remote_files "$base_url" "$target_root" "${OPENCODE_GCP_MODULES[@]}"
  opencode_gcp_fetch_remote_files "$base_url" "$target_root" "${OPENCODE_GCP_CONFIG_FILES[@]}"
  opencode_gcp_fetch_prompt_files "$base_url" "$target_root"
}

opencode_gcp_resolve_root() {
  local local_root
  local remote_root
  local remote_ref
  local remote_base_url

  if local_root="$(opencode_gcp_detect_local_root)"; then
    OPENCODE_GCP_REMOTE_BOOTSTRAP="false"
    OPENCODE_GCP_INSTALL_ROOT="$local_root"
    return 0
  fi

  remote_ref="${OPENCODE_GCP_INSTALL_REF:-main}"
  remote_base_url="${OPENCODE_GCP_INSTALL_BASE_URL:-https://raw.githubusercontent.com/finerio-connect/developer-tools/$remote_ref}"
  remote_root="$(mktemp -d "${TMPDIR:-/tmp}/opencode-gcp-installer.XXXXXX")"

  printf "[INFO] Descargando instalador modular desde %s\n" "$remote_base_url" >&2
  opencode_gcp_fetch_modules "$remote_base_url" "$remote_root"

  OPENCODE_GCP_REMOTE_BOOTSTRAP="true"
  OPENCODE_GCP_INSTALL_ROOT="$remote_root"
}

opencode_gcp_source_modules() {
  local root="$1"
  local module_path

  for module_path in "${OPENCODE_GCP_MODULES[@]}"; do
    # shellcheck disable=SC1090
    . "$root/$module_path"
  done
}

main() {
  local install_root

  opencode_gcp_resolve_root
  install_root="$OPENCODE_GCP_INSTALL_ROOT"
  if [[ "$OPENCODE_GCP_REMOTE_BOOTSTRAP" == "true" ]]; then
    trap 'rm -rf "$install_root"' EXIT
  fi

  opencode_gcp_source_modules "$install_root"
  opencode_gcp_main "$@"
}

main "$@"
