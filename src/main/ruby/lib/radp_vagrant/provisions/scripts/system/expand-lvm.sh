#!/usr/bin/env bash
set -euo pipefail

# Builtin provision: radp:system/expand-lvm
# Expand LVM partition and filesystem to use all available disk space
#
# This is useful when vagrant-disksize plugin resizes the virtual disk,
# but the partition table and LVM volumes are not automatically expanded.
#
# Optional environment variables:
#   LVM_PARTITION  - Partition containing LVM PV (e.g., /dev/sda3). Auto-detected if empty.
#   LVM_VG         - Volume group name. Auto-detected if empty.
#   LVM_LV         - Logical volume to expand. Auto-detected (root LV) if empty.
#   DRY_RUN        - Show what would be done without making changes (default: false)
#
# Usage in vagrant.yaml:
#   provisions:
#     - name: radp:system/expand-lvm
#       enabled: true

echo "[INFO] Expanding LVM partition and filesystem..."

# Default values
LVM_PARTITION="${LVM_PARTITION:-}"
LVM_VG="${LVM_VG:-}"
LVM_LV="${LVM_LV:-}"
DRY_RUN="${DRY_RUN:-false}"

# Detect package manager
detect_pm() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  else
    echo "unknown"
  fi
}

# Install growpart if not available
install_growpart() {
  if command -v growpart >/dev/null 2>&1; then
    echo "[OK] growpart is already installed"
    return 0
  fi

  echo "[INFO] Installing growpart..."
  local pm
  pm=$(detect_pm)

  case "$pm" in
    apt)
      apt-get update -qq
      apt-get install -y cloud-guest-utils
      ;;
    dnf)
      dnf install -y cloud-utils-growpart
      ;;
    yum)
      yum install -y cloud-utils-growpart
      ;;
    *)
      echo "[ERROR] Cannot install growpart: unsupported package manager"
      exit 1
      ;;
  esac
  echo "[OK] growpart installed"
}

# Auto-detect LVM partition (the partition containing the root PV)
detect_lvm_partition() {
  if [[ -n "$LVM_PARTITION" ]]; then
    echo "$LVM_PARTITION"
    return 0
  fi

  # Find the PV that contains the root filesystem
  local root_device root_vg pv_device

  # Get the device for root filesystem
  root_device=$(findmnt -n -o SOURCE / 2>/dev/null | head -1)
  if [[ -z "$root_device" ]]; then
    echo "[ERROR] Cannot determine root filesystem device"
    return 1
  fi

  # Check if root is on LVM
  if [[ "$root_device" == /dev/mapper/* ]] || [[ "$root_device" == /dev/dm-* ]]; then
    # Get VG name from the LV
    if [[ "$root_device" == /dev/mapper/* ]]; then
      # Format: /dev/mapper/vgname-lvname
      root_vg=$(lvs --noheadings -o vg_name "$root_device" 2>/dev/null | tr -d ' ')
    else
      # dm-X device
      root_vg=$(lvs --noheadings -o vg_name "$root_device" 2>/dev/null | tr -d ' ')
    fi

    if [[ -z "$root_vg" ]]; then
      echo "[ERROR] Cannot determine volume group for root"
      return 1
    fi

    # Find the PV for this VG
    pv_device=$(pvs --noheadings -o pv_name -S "vg_name=$root_vg" 2>/dev/null | tr -d ' ' | head -1)
    if [[ -z "$pv_device" ]]; then
      echo "[ERROR] Cannot find PV for VG $root_vg"
      return 1
    fi

    echo "$pv_device"
  else
    echo "[ERROR] Root filesystem is not on LVM"
    return 1
  fi
}

# Auto-detect volume group
detect_vg() {
  if [[ -n "$LVM_VG" ]]; then
    echo "$LVM_VG"
    return 0
  fi

  local root_device vg_name
  root_device=$(findmnt -n -o SOURCE / 2>/dev/null | head -1)

  if [[ "$root_device" == /dev/mapper/* ]] || [[ "$root_device" == /dev/dm-* ]]; then
    vg_name=$(lvs --noheadings -o vg_name "$root_device" 2>/dev/null | tr -d ' ')
    echo "$vg_name"
  else
    echo ""
  fi
}

# Auto-detect logical volume (root LV)
detect_lv() {
  if [[ -n "$LVM_LV" ]]; then
    echo "$LVM_LV"
    return 0
  fi

  local root_device lv_name
  root_device=$(findmnt -n -o SOURCE / 2>/dev/null | head -1)

  if [[ "$root_device" == /dev/mapper/* ]] || [[ "$root_device" == /dev/dm-* ]]; then
    lv_name=$(lvs --noheadings -o lv_name "$root_device" 2>/dev/null | tr -d ' ')
    echo "$lv_name"
  else
    echo ""
  fi
}

# Get disk device from partition (e.g., /dev/sda3 -> /dev/sda)
get_disk_from_partition() {
  local partition="$1"
  # Remove partition number: /dev/sda3 -> /dev/sda, /dev/nvme0n1p3 -> /dev/nvme0n1
  if [[ "$partition" =~ ^/dev/nvme ]]; then
    # NVMe: /dev/nvme0n1p3 -> /dev/nvme0n1
    echo "${partition%p[0-9]*}"
  else
    # SATA/SCSI: /dev/sda3 -> /dev/sda
    echo "${partition%%[0-9]*}"
  fi
}

# Get partition number from partition device
get_partition_number() {
  local partition="$1"
  if [[ "$partition" =~ ^/dev/nvme ]]; then
    # NVMe: /dev/nvme0n1p3 -> 3
    echo "${partition##*p}"
  else
    # SATA/SCSI: /dev/sda3 -> 3
    echo "${partition##*[a-z]}"
  fi
}

# Detect filesystem type
detect_fs_type() {
  local device="$1"
  lsblk -no FSTYPE "$device" 2>/dev/null | head -1
}

# Main execution
main() {
  # Check if running as root
  if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] This script must be run as root"
    exit 1
  fi

  # Install growpart
  install_growpart

  # Detect LVM configuration
  local partition vg lv disk part_num
  partition=$(detect_lvm_partition) || exit 1
  vg=$(detect_vg) || exit 1
  lv=$(detect_lv) || exit 1

  if [[ -z "$partition" ]] || [[ -z "$vg" ]] || [[ -z "$lv" ]]; then
    echo "[ERROR] Cannot auto-detect LVM configuration"
    echo "  Partition: ${partition:-not found}"
    echo "  VG: ${vg:-not found}"
    echo "  LV: ${lv:-not found}"
    exit 1
  fi

  disk=$(get_disk_from_partition "$partition")
  part_num=$(get_partition_number "$partition")
  local lv_path="/dev/${vg}/${lv}"
  local fs_type
  fs_type=$(detect_fs_type "$lv_path")

  echo "[INFO] Detected configuration:"
  echo "  Disk: $disk"
  echo "  Partition: $partition (partition $part_num)"
  echo "  Volume Group: $vg"
  echo "  Logical Volume: $lv ($lv_path)"
  echo "  Filesystem: $fs_type"
  echo ""

  # Show current state
  echo "[INFO] Current disk layout:"
  lsblk "$disk"
  echo ""

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY-RUN] Would execute:"
    echo "  1. growpart $disk $part_num"
    echo "  2. pvresize $partition"
    echo "  3. lvextend -l +100%FREE $lv_path"
    case "$fs_type" in
      ext4|ext3|ext2)
        echo "  4. resize2fs $lv_path"
        ;;
      xfs)
        echo "  4. xfs_growfs $lv_path"
        ;;
    esac
    return 0
  fi

  # Step 1: Expand partition
  echo "[INFO] Step 1: Expanding partition $partition..."
  if growpart "$disk" "$part_num" 2>&1; then
    echo "[OK] Partition expanded"
  else
    # growpart returns 1 if partition is already at max size
    echo "[INFO] Partition may already be at maximum size (this is OK)"
  fi

  # Step 2: Resize PV
  echo "[INFO] Step 2: Resizing physical volume $partition..."
  pvresize "$partition"
  echo "[OK] PV resized"

  # Step 3: Extend LV
  echo "[INFO] Step 3: Extending logical volume $lv_path..."
  lvextend -l +100%FREE "$lv_path" 2>&1 || echo "[INFO] LV may already be at maximum size"
  echo "[OK] LV extended"

  # Step 4: Resize filesystem
  echo "[INFO] Step 4: Resizing filesystem ($fs_type)..."
  case "$fs_type" in
    ext4|ext3|ext2)
      resize2fs "$lv_path"
      ;;
    xfs)
      xfs_growfs "$lv_path"
      ;;
    *)
      echo "[WARN] Unknown filesystem type: $fs_type. Skipping filesystem resize."
      ;;
  esac
  echo "[OK] Filesystem resized"

  # Show final state
  echo ""
  echo "[INFO] Final disk layout:"
  lsblk "$disk"
  echo ""
  echo "[INFO] Filesystem usage:"
  df -h "$lv_path"
  echo ""
  echo "[INFO] LVM expansion completed successfully"
}

main "$@"
