#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="${RADP_VF_REPO_OWNER:-xooooooooox}"
REPO_NAME="radp-vagrant-framework"
tmp_dir=""

log() {
  printf "%s\n" "$*"
}

err() {
  printf "radp-vagrant-framework install: %s\n" "$*" >&2
}

die() {
  err "$@"
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

detect_fetcher() {
  if have curl; then
    echo "curl"
    return 0
  fi
  if have wget; then
    echo "wget"
    return 0
  fi
  if have fetch; then
    echo "fetch"
    return 0
  fi
  return 1
}

fetch_url() {
  local tool="$1"
  local url="$2"
  local out="$3"

  case "${tool}" in
  curl)
    curl -fsSL "${url}" -o "${out}"
    ;;
  wget)
    wget -qO "${out}" "${url}"
    ;;
  fetch)
    fetch -qo "${out}" "${url}"
    ;;
  *)
    return 1
    ;;
  esac
}

fetch_text() {
  local tool="$1"
  local url="$2"

  case "${tool}" in
  curl)
    curl -fsSL "${url}"
    ;;
  wget)
    wget -qO- "${url}"
    ;;
  fetch)
    fetch -qo- "${url}"
    ;;
  *)
    return 1
    ;;
  esac
}

resolve_ref() {
  local manual_ref="${RADP_VF_REF:-}"
  local manual_version="${RADP_VF_VERSION:-}"

  if [[ -n "${manual_ref}" ]]; then
    echo "${manual_ref}"
    return 0
  fi

  if [[ -n "${manual_version}" ]]; then
    echo "${manual_version}"
    return 0
  fi

  local api_url="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest"
  local json
  json="$(fetch_text "${FETCH_TOOL}" "${api_url}" || true)"
  if [[ -z "${json}" ]]; then
    die "Failed to fetch latest release; set RADP_VF_VERSION or RADP_VF_REF."
  fi

  local tag
  tag="$(sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<<"${json}")"
  tag="${tag%%$'\n'*}"
  if [[ -z "${tag}" ]]; then
    die "Failed to parse latest tag; set RADP_VF_VERSION or RADP_VF_REF."
  fi
  echo "${tag}"
}

cleanup() {
  if [[ -n "${tmp_dir:-}" ]]; then
    rm -rf "${tmp_dir}"
  fi
}

install_cli() {
  local install_dir="$1"
  local bin_dir="$2"
  local src_root="$3"

  mkdir -p "${bin_dir}"

  # Copy CLI script from source
  local src_script="${src_root}/src/main/shell/bin/radp-vf"
  local target_script="${bin_dir}/radp-vf"

  if [[ -f "${src_script}" ]]; then
    cp "${src_script}" "${target_script}"
    chmod 0755 "${target_script}"
  else
    die "CLI script not found: ${src_script}"
  fi

  # Create alias symlink
  ln -sf "${target_script}" "${bin_dir}/radp-vagrant-framework"
}

main() {
  FETCH_TOOL="$(detect_fetcher)" || die "Requires curl, wget, or fetch."

  local install_dir="${RADP_VF_INSTALL_DIR:-$HOME/.local/lib/${REPO_NAME}}"
  local bin_dir="${RADP_VF_BIN_DIR:-$HOME/.local/bin}"
  local ref
  ref="$(resolve_ref)"

  if [[ -z "${install_dir}" || "${install_dir}" == "/" ]]; then
    die "Unsafe install dir: ${install_dir}"
  fi
  if [[ "${RADP_VF_ALLOW_ANY_DIR:-0}" != "1" ]]; then
    if [[ "$(basename "${install_dir}")" != "${REPO_NAME}" ]]; then
      die "Install dir must end with ${REPO_NAME} (set RADP_VF_ALLOW_ANY_DIR=1 to override)."
    fi
  fi

  local tar_url="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/${ref}.tar.gz"
  tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t "${REPO_NAME}")"
  local tarball="${tmp_dir}/${REPO_NAME}.tar.gz"
  trap cleanup EXIT

  log "Downloading ${tar_url}"
  if ! fetch_url "${FETCH_TOOL}" "${tar_url}" "${tarball}"; then
    die "Failed to download ${tar_url}"
  fi

  local tar_listing
  tar_listing="$(tar -tzf "${tarball}")"
  local root_dir="${tar_listing%%/*}"
  if [[ -z "${root_dir}" ]]; then
    die "Unable to read archive structure."
  fi

  tar -xzf "${tarball}" -C "${tmp_dir}"
  local src_root="${tmp_dir}/${root_dir}"
  if [[ ! -d "${src_root}/src/main/ruby/lib" ]]; then
    die "Archive layout unexpected; missing src/main/ruby/lib."
  fi

  rm -rf "${install_dir}"
  mkdir -p "${install_dir}"

  # Copy Ruby framework files
  cp -R "${src_root}/src/main/ruby/lib" "${install_dir}/"
  cp -R "${src_root}/src/main/ruby/Vagrantfile" "${install_dir}/" 2>/dev/null || true

  # Copy sample config if exists
  if [[ -d "${src_root}/src/main/ruby/config" ]]; then
    cp -R "${src_root}/src/main/ruby/config" "${install_dir}/"
  fi

  # Set permissions
  find "${install_dir}" -type f -name "*.rb" -exec chmod 0644 {} \;

  # Install CLI script
  install_cli "${install_dir}" "${bin_dir}" "${src_root}"

  log ""
  log "Installed to ${install_dir}"
  log ""
  log "Ensure ${bin_dir} is in your PATH:"
  log "  export PATH=\"${bin_dir}:\$PATH\""
  log ""
  log "Quick start:"
  log "  radp-vf init myproject"
  log "  cd myproject"
  log "  vagrant status"
}

main "$@"
