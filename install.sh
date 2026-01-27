#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="${RADP_VF_REPO_OWNER:-xooooooooox}"
REPO_NAME="radp-vagrant-framework"
tmp_dir=""

# Installation mode: auto, manual, <pkm>
# auto: detect and use package manager if available, fallback to manual
# manual: always use manual installation (download from GitHub)
# homebrew/dnf/yum/apt/zypper: force specific package manager
RADP_VF_INSTALL_MODE="${RADP_VF_INSTALL_MODE:-auto}"

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

# ============================================================================
# Package Manager Detection and Installation
# ============================================================================

detect_os() {
  local os=""
  if [[ "${OSTYPE:-}" == darwin* ]]; then
    os="macos"
  elif [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    case "${ID:-}" in
      fedora | centos | rhel | rocky | almalinux | ol)
        os="rhel"
        ;;
      debian | ubuntu | linuxmint | pop)
        os="debian"
        ;;
      opensuse* | sles)
        os="suse"
        ;;
      *)
        os="linux"
        ;;
    esac
  else
    os="unknown"
  fi
  echo "${os}"
}

# Detect available package manager
# Returns: homebrew, dnf, yum, apt, zypper, or empty string
detect_package_manager() {
  local os
  os="$(detect_os)"

  # Homebrew (macOS and Linux)
  if have brew; then
    echo "homebrew"
    return 0
  fi

  # Linux package managers
  case "${os}" in
    rhel)
      if have dnf; then
        echo "dnf"
        return 0
      elif have yum; then
        echo "yum"
        return 0
      fi
      ;;
    debian)
      if have apt-get; then
        echo "apt"
        return 0
      fi
      ;;
    suse)
      if have zypper; then
        echo "zypper"
        return 0
      fi
      ;;
  esac

  echo ""
}

# Check if package manager repository is configured
check_repo_configured() {
  local pkm="$1"

  case "${pkm}" in
    homebrew)
      # Check if tap is configured
      if brew tap 2>/dev/null | grep -q "xooooooooox/radp"; then
        return 0
      fi
      return 1
      ;;
    dnf | yum)
      # Check if COPR repo is enabled
      if [[ -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:xooooooooox:radp.repo ]] \
        || [[ -f /etc/yum.repos.d/radp.repo ]]; then
        return 0
      fi
      return 1
      ;;
    apt)
      # Check if OBS repo is configured
      if [[ -f /etc/apt/sources.list.d/home:xooooooooox:radp.list ]]; then
        return 0
      fi
      return 1
      ;;
    zypper)
      # Check if OBS repo is configured
      if zypper repos 2>/dev/null | grep -q "xooooooooox"; then
        return 0
      fi
      return 1
      ;;
  esac

  return 1
}

# Setup repository for package manager
setup_repo() {
  local pkm="$1"

  log "Setting up repository for ${pkm}..."

  case "${pkm}" in
    homebrew)
      log "Adding Homebrew tap..."
      brew tap xooooooooox/radp
      ;;
    dnf)
      log "Enabling COPR repository..."
      sudo dnf install -y dnf-plugins-core >/dev/null 2>&1 || true
      sudo dnf copr enable -y xooooooooox/radp
      ;;
    yum)
      log "Enabling COPR repository..."
      sudo yum install -y yum-plugin-copr >/dev/null 2>&1 || true
      sudo yum copr enable -y xooooooooox/radp
      ;;
    apt)
      log "Adding OBS repository..."
      # Detect distro for OBS
      local distro=""
      if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        case "${ID:-}" in
          ubuntu)
            distro="xUbuntu_${VERSION_ID}"
            ;;
          debian)
            distro="Debian_${VERSION_ID}"
            ;;
          *)
            err "Unsupported distribution for apt: ${ID:-unknown}"
            return 1
            ;;
        esac
      fi
      if [[ -z "${distro}" ]]; then
        err "Cannot detect distribution for OBS repository"
        return 1
      fi
      echo "deb http://download.opensuse.org/repositories/home:/xooooooooox:/radp/${distro}/ /" \
        | sudo tee /etc/apt/sources.list.d/home:xooooooooox:radp.list >/dev/null
      curl -fsSL "https://download.opensuse.org/repositories/home:xooooooooox:radp/${distro}/Release.key" \
        | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/home_xooooooooox_radp.gpg >/dev/null
      sudo apt-get update >/dev/null
      ;;
    zypper)
      log "Adding OBS repository..."
      # Detect distro for OBS
      local distro=""
      if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        case "${ID:-}" in
          opensuse-tumbleweed)
            distro="openSUSE_Tumbleweed"
            ;;
          opensuse-leap)
            distro="openSUSE_Leap_${VERSION_ID}"
            ;;
          sles)
            distro="SLE_${VERSION_ID}"
            ;;
          *)
            err "Unsupported distribution for zypper: ${ID:-unknown}"
            return 1
            ;;
        esac
      fi
      if [[ -z "${distro}" ]]; then
        err "Cannot detect distribution for OBS repository"
        return 1
      fi
      sudo zypper addrepo -f "https://download.opensuse.org/repositories/home:/xooooooooox:/radp/${distro}/home:xooooooooox:radp.repo"
      ;;
    *)
      err "Unknown package manager: ${pkm}"
      return 1
      ;;
  esac
}

# Refresh package manager cache
refresh_cache() {
  local pkm="$1"

  log "Refreshing package cache..."

  case "${pkm}" in
    homebrew)
      brew update >/dev/null 2>&1 || true
      ;;
    dnf)
      sudo dnf clean all >/dev/null 2>&1 || true
      sudo dnf makecache >/dev/null 2>&1 || true
      ;;
    yum)
      sudo yum clean all >/dev/null 2>&1 || true
      ;;
    apt)
      sudo apt-get update >/dev/null 2>&1 || true
      ;;
    zypper)
      sudo zypper refresh >/dev/null 2>&1 || true
      ;;
  esac
}

# Install using package manager
install_via_pkm() {
  local pkm="$1"

  # Refresh cache to ensure we get the latest version
  refresh_cache "${pkm}"

  log "Installing ${REPO_NAME} via ${pkm}..."

  case "${pkm}" in
    homebrew)
      brew install radp-vagrant-framework
      ;;
    dnf)
      sudo dnf install -y radp-vagrant-framework
      ;;
    yum)
      sudo yum install -y radp-vagrant-framework
      ;;
    apt)
      sudo apt-get install -y radp-vagrant-framework
      ;;
    zypper)
      sudo zypper install -y radp-vagrant-framework
      ;;
    *)
      err "Unknown package manager: ${pkm}"
      return 1
      ;;
  esac
}

# ============================================================================
# Manual Installation (existing logic)
# ============================================================================

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
  local src_script="${src_root}/bin/radp-vf"
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

install_manual() {
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

  # Copy project templates
  if [[ -d "${src_root}/templates" ]]; then
    cp -R "${src_root}/templates" "${install_dir}/"
  fi

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

# ============================================================================
# Main
# ============================================================================

main() {
  local mode="${RADP_VF_INSTALL_MODE}"
  local pkm=""

  # Determine installation method
  case "${mode}" in
    manual)
      log "Using manual installation (RADP_VF_INSTALL_MODE=manual)"
      install_manual
      return 0
      ;;
    homebrew | dnf | yum | apt | zypper)
      # Force specific package manager
      pkm="${mode}"
      if ! have "${pkm}" && [[ "${pkm}" != "homebrew" ]]; then
        die "Package manager '${pkm}' not found"
      fi
      if [[ "${pkm}" == "homebrew" ]] && ! have brew; then
        die "Homebrew not found"
      fi
      ;;
    auto | "")
      # Auto-detect package manager
      pkm="$(detect_package_manager)"
      if [[ -z "${pkm}" ]]; then
        log "No supported package manager detected, using manual installation"
        install_manual
        return 0
      fi
      log "Detected package manager: ${pkm}"
      ;;
    *)
      die "Unknown install mode: ${mode}. Use: auto, manual, homebrew, dnf, yum, apt, zypper"
      ;;
  esac

  # Setup repository if needed
  if ! check_repo_configured "${pkm}"; then
    log "Repository not configured for ${pkm}"
    setup_repo "${pkm}" || {
      err "Failed to setup repository, falling back to manual installation"
      install_manual
      return 0
    }
  fi

  # Install via package manager
  install_via_pkm "${pkm}" || {
    err "Package manager installation failed, falling back to manual installation"
    install_manual
    return 0
  }

  log "Successfully installed ${REPO_NAME} via ${pkm}"
  log ""
  log "Quick start:"
  log "  radp-vf init myproject"
  log "  cd myproject"
  log "  vagrant status"
}

main "$@"
