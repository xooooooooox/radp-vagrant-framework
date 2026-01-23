#!/usr/bin/env bash
set -euo pipefail

# Builtin provision: radp:nfs/external-nfs-mount
# Mount external NFS shares with auto-directory creation and verification
#
# Required environment variables:
#   NFS_SERVER - NFS server hostname (e.g., nas.example.com)
#   NFS_ROOT   - NFS root path (e.g., /volume1/nfs)
#
# Mount paths:
#   {NFS_ROOT}/vm/{env}/{cluster}/{guest-id}        -> /data
#   {NFS_ROOT}/vm/{env}/{cluster}/backup/{guest-id} -> /backup_data
#   {NFS_ROOT}/vm/{env}/{cluster}/share             -> /cluster_data
#   {NFS_ROOT}/vm/public                            -> /public_data
#   {NFS_ROOT}/docker                               -> /docker_data

# Derive context from hostname convention: {guest-id}.{cluster}.{env}
cur_env=$(hostname -f | awk -F. '{print $NF}')
cur_cluster=$(hostname -f | awk -F. '{print $(NF-1)}')
cur_guest_id=$(hostname -s)

echo "[INFO] Context: env=${cur_env}, cluster=${cur_cluster}, guest_id=${cur_guest_id}"

# NFS mount point (local)
NFS_MOUNT="/mnt/nfs"

declare -A nfs_paths=(
  ["guest_data"]="${NFS_ROOT}/vm/${cur_env}/${cur_cluster}/${cur_guest_id}"
  ["backup_data"]="${NFS_ROOT}/vm/${cur_env}/${cur_cluster}/backup/${cur_guest_id}"
  ["cluster_data"]="${NFS_ROOT}/vm/${cur_env}/${cur_cluster}/share"
  ["public_data"]="${NFS_ROOT}/vm/public"
  ["docker_data"]="${NFS_ROOT}/docker"
)

declare -A mount_paths=(
  ["guest_data"]="/mnt/guest_data"
  ["backup_data"]="/mnt/backup_data"
  ["cluster_data"]="/mnt/cluster_data"
  ["public_data"]="/mnt/public_data"
  ["docker_data"]="/mnt/docker_data"
)

declare -A symlinks=(
  ["guest_data"]="/data"
  ["backup_data"]="/backup_data"
  ["cluster_data"]="/cluster_data"
  ["public_data"]="/public_data"
  ["docker_data"]="/docker_data"
)

# Install NFS client if needed
if ! command -v nfsstat >/dev/null 2>&1; then
  echo "[INFO] Installing nfs client..."
  if command -v yum >/dev/null 2>&1; then
    yum install -y nfs-utils
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update && apt-get install -y nfs-common
  else
    echo "[ERROR] Cannot install NFS client: unknown package manager"
    exit 1
  fi
fi

# Helper: convert NFS path to local path under mount point
nfs_to_local() {
  local nfs_path="$1"
  local relative_path="${nfs_path#$NFS_ROOT}"
  echo "${NFS_MOUNT}${relative_path}"
}

# Temporary mount to create directories
[[ ! -d "${NFS_MOUNT}" ]] && mkdir -pv "${NFS_MOUNT}"
if ! mountpoint -q "${NFS_MOUNT}" >/dev/null 2>&1; then
  mount -t nfs "${NFS_SERVER}:${NFS_ROOT}" "${NFS_MOUNT}" || exit 1
  echo "[INFO] Mounted ${NFS_SERVER}:${NFS_ROOT} -> ${NFS_MOUNT}"
fi

# Create all required directories on NFS
for key in "${!nfs_paths[@]}"; do
  nfs_path="${nfs_paths[$key]}"
  local_path=$(nfs_to_local "$nfs_path")

  if [[ ! -d "$local_path" ]]; then
    mkdir -p "$local_path"
    chmod 755 "$local_path"
    echo "[INFO] Created remote directory: $local_path"
  fi
done

# Mount each NFS path
for key in "${!nfs_paths[@]}"; do
  mount_dir="${mount_paths[$key]}"
  nfs_path="${nfs_paths[$key]}"
  link_name="${symlinks[$key]}"

  [[ ! -d "$mount_dir" ]] && mkdir -p "$mount_dir"

  # Mount NFS
  if ! mountpoint -q "$mount_dir" >/dev/null 2>&1; then
    if ! mount -t nfs "${NFS_SERVER}:${nfs_path}" "$mount_dir"; then
      echo "[ERROR] Failed to mount ${NFS_SERVER}:${nfs_path} -> $mount_dir"
      exit 1
    fi
  fi
  echo "[INFO] Mounted ${NFS_SERVER}:${nfs_path} -> $mount_dir"

  # Create/update symlink
  if [[ -e "$link_name" ]]; then
    if [[ -L "$link_name" ]]; then
      ln -snf "$mount_dir" "$link_name"
    elif [[ -d "$link_name" ]]; then
      if [[ -z "$(ls -A "$link_name")" ]]; then
        rmdir "$link_name"
        ln -snf "$mount_dir" "$link_name"
      else
        echo "[ERROR] $link_name is a non-empty directory"
        exit 1
      fi
    else
      echo "[ERROR] $link_name exists and is not a symlink or directory"
      exit 1
    fi
  else
    ln -snf "$mount_dir" "$link_name"
  fi
  echo "[INFO] Symlink: $link_name -> $mount_dir"
done

echo "[INFO] NFS mounts completed successfully"

# Verification phase
echo ""
echo "[INFO] Running mount verification..."

# Check mount points
failed=0
for mp in "${symlinks[@]}"; do
  if [[ -L "$mp" && -d "$mp" ]]; then
    echo "[OK] Mount point accessible: $mp"
  elif [[ -d "$mp" ]]; then
    echo "[OK] Directory exists: $mp"
  else
    echo "[WARN] Mount point not found: $mp"
    ((failed++)) || true
  fi
done

if [[ $failed -gt 0 ]]; then
  echo "[WARN] Some mount points are missing."
fi

# Create vagrant data directory
VAGRANT_DATA_DIR="/data/vagrant"
if [[ -d "/data" ]]; then
  if [[ ! -d "$VAGRANT_DATA_DIR" ]]; then
    mkdir -p "$VAGRANT_DATA_DIR"
    echo "[INFO] Created vagrant data directory: $VAGRANT_DATA_DIR"
  else
    echo "[OK] Vagrant data directory exists: $VAGRANT_DATA_DIR"
  fi
else
  echo "[WARN] /data not available, skipping vagrant data directory creation"
fi

echo "[INFO] External NFS mount provision completed"
