#!/usr/bin/env bash

[[ -z "${ARC_PATH}" || ! -d "${ARC_PATH}/include" ]] && ARC_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

. ${ARC_PATH}/include/functions.sh
. ${ARC_PATH}/include/addons.sh
. ${ARC_PATH}/include/modules.sh
. ${ARC_PATH}/include/storage.sh
. ${ARC_PATH}/include/network.sh

[ -z "${LOADER_DISK}" ] && die "Loader Disk not found!"

# Memory: Check Memory installed
RAMTOTAL=0
while read -r LINE; do
  RAMSIZE=${LINE}
  RAMTOTAL=$((${RAMTOTAL} + ${RAMSIZE}))
done < <(dmidecode -t memory | grep -i "Size" | cut -d" " -f2 | grep -i "[1-9]")
RAMTOTAL=$((${RAMTOTAL} * 1024))
RAMMAX=$((${RAMTOTAL} * 2))
RAMMIN=$((${RAMTOTAL} / 2))

# Check for Hypervisor
if grep -q "^flags.*hypervisor.*" /proc/cpuinfo; then
  # Check for Hypervisor
  MACHINE="$(lscpu | grep Hypervisor | awk '{print $3}')"
else
  MACHINE="NATIVE"
fi

# Get Loader Disk Bus
BUS=$(getBus "${LOADER_DISK}")

# Set Warning to 0
WARNON=0

# Get DSM Data from Config
MODEL="$(readConfigKey "model" "${USER_CONFIG_FILE}")"
PRODUCTVER="$(readConfigKey "productver" "${USER_CONFIG_FILE}")"
LAYOUT="$(readConfigKey "layout" "${USER_CONFIG_FILE}")"
KEYMAP="$(readConfigKey "keymap" "${USER_CONFIG_FILE}")"
LKM="$(readConfigKey "lkm" "${USER_CONFIG_FILE}")"
if [ -n "${MODEL}" ]; then
  PLATFORM="$(readModelKey "${MODEL}" "platform")"
  DT="$(readModelKey "${MODEL}" "dt")"
fi

# Get Arc Data from Config
DIRECTBOOT="$(readConfigKey "arc.directboot" "${USER_CONFIG_FILE}")"
BOOTCOUNT="$(readConfigKey "arc.bootcount" "${USER_CONFIG_FILE}")"
CONFDONE="$(readConfigKey "arc.confdone" "${USER_CONFIG_FILE}")"
BUILDDONE="$(readConfigKey "arc.builddone" "${USER_CONFIG_FILE}")"
ARCPATCH="$(readConfigKey "arc.patch" "${USER_CONFIG_FILE}")"
BOOTIPWAIT="$(readConfigKey "arc.bootipwait" "${USER_CONFIG_FILE}")"
REMAP="$(readConfigKey "arc.remap" "${USER_CONFIG_FILE}")"
KERNELLOAD="$(readConfigKey "arc.kernelload" "${USER_CONFIG_FILE}")"
KERNELPANIC="$(readConfigKey "arc.kernelpanic" "${USER_CONFIG_FILE}")"
MACSYS="$(readConfigKey "arc.macsys" "${USER_CONFIG_FILE}")"
ODP="$(readConfigKey "arc.odp" "${USER_CONFIG_FILE}")"
HDDSORT="$(readConfigKey "arc.hddsort" "${USER_CONFIG_FILE}")"
STATICIP="$(readConfigKey "arc.staticip" "${USER_CONFIG_FILE}")"
ARCIPV6="$(readConfigKey "arc.ipv6" "${USER_CONFIG_FILE}")"
OFFLINE="$(readConfigKey "arc.offline" "${USER_CONFIG_FILE}")"

###############################################################################
# Mounts backtitle dynamically
function backtitle() {
  BACKTITLE="${ARC_TITLE} |"
  if [ -n "${MODEL}" ]; then
    BACKTITLE+=" ${MODEL}"
  else
    BACKTITLE+=" (no model)"
  fi
  BACKTITLE+=" |"
  if [ -n "${PRODUCTVER}" ]; then
    BACKTITLE+=" ${PRODUCTVER}"
  else
    BACKTITLE+=" (no version)"
  fi
  BACKTITLE+=" |"
  if [ -n "${IPCON}" ]; then
    BACKTITLE+=" ${IPCON}"
  else
    BACKTITLE+=" (no IP)"
  fi
  BACKTITLE+=" |"
  BACKTITLE+=" Patch: ${ARCPATCH}"
  BACKTITLE+=" |"
  if [ "${CONFDONE}" = "true" ]; then
    BACKTITLE+=" Config: Y"
  else
    BACKTITLE+=" Config: N"
  fi
  BACKTITLE+=" |"
  if [ "${BUILDDONE}" = "true" ]; then
    BACKTITLE+=" Build: Y"
  else
    BACKTITLE+=" Build: N"
  fi
  BACKTITLE+=" |"
  BACKTITLE+=" ${MACHINE}(${BUS^^})"
  echo "${BACKTITLE}"
}

###############################################################################
# Make Model Config
function arcMenu() {
  # read model config for dt and aes
  MODEL="RS4021xs+"
  DT="$(readModelKey "${MODEL}" "dt")"
  PRODUCTVER=""
  writeConfigKey "model" "${MODEL}" "${USER_CONFIG_FILE}"
  writeConfigKey "productver" "" "${USER_CONFIG_FILE}"
  writeConfigKey "arc.confdone" "false" "${USER_CONFIG_FILE}"
  writeConfigKey "arc.builddone" "false" "${USER_CONFIG_FILE}"
  writeConfigKey "arc.remap" "" "${USER_CONFIG_FILE}"
  writeConfigKey "arc.paturl" "" "${USER_CONFIG_FILE}"
  writeConfigKey "arc.pathash" "" "${USER_CONFIG_FILE}"
  writeConfigKey "arc.sn" "" "${USER_CONFIG_FILE}"
  writeConfigKey "arc.mac1" "" "${USER_CONFIG_FILE}"
  if [ "${DT}" = "true" ]; then
    deleteConfigKey "cmdline.SataPortMap" "${USER_CONFIG_FILE}"
    deleteConfigKey "cmdline.DiskIdxMap" "${USER_CONFIG_FILE}"
    deleteConfigKey "cmdline.sata_remap" "${USER_CONFIG_FILE}"
  fi
  CONFDONE="$(readConfigKey "arc.confdone" "${USER_CONFIG_FILE}")"
  BUILDDONE="$(readConfigKey "arc.builddone" "${USER_CONFIG_FILE}")"
  if [[ -f "${ORI_ZIMAGE_FILE}" || -f "${ORI_RDGZ_FILE}" || -f "${MOD_ZIMAGE_FILE}" || -f "${MOD_RDGZ_FILE}" ]]; then
    # Delete old files
    rm -f "${ORI_ZIMAGE_FILE}" "${ORI_RDGZ_FILE}" "${MOD_ZIMAGE_FILE}" "${MOD_RDGZ_FILE}"
  fi
  arcbuild
}

###############################################################################
# Shows menu to user type one or generate randomly
function arcbuild() {
  # read model values for arcbuild
  MODEL="$(readConfigKey "model" "${USER_CONFIG_FILE}")"
  PLATFORM="$(readModelKey "${MODEL}" "platform")"
  writeConfigKey "productver" "7.2" "${USER_CONFIG_FILE}"
  if [[ -f "${ORI_ZIMAGE_FILE}" || -f "${ORI_RDGZ_FILE}" || -f "${MOD_ZIMAGE_FILE}" || -f "${MOD_RDGZ_FILE}" ]]; then
    # Delete old files
    rm -f "${ORI_ZIMAGE_FILE}" "${ORI_RDGZ_FILE}" "${MOD_ZIMAGE_FILE}" "${MOD_RDGZ_FILE}"
  fi
  PRODUCTVER="$(readConfigKey "productver" "${USER_CONFIG_FILE}")"
  KVER="$(readModelKey "${MODEL}" "productvers.[${PRODUCTVER}].kver")"
  if [ "${PLATFORM}" = "epyc7002" ]; then
    KVER="${PRODUCTVER}-${KVER}"
  fi
  dialog --backtitle "$(backtitle)" --title "Arc Config" \
    --infobox "Reconfiguring Synoinfo, Addons and Modules" 3 46
  # Delete synoinfo and reload model/build synoinfo
  writeConfigKey "synoinfo" "{}" "${USER_CONFIG_FILE}"
  while IFS=': ' read -r KEY VALUE; do
    writeConfigKey "synoinfo.\"${KEY}\"" "${VALUE}" "${USER_CONFIG_FILE}"
  done < <(readModelMap "${MODEL}" "productvers.[${PRODUCTVER}].synoinfo")
  # Rebuild modules
  writeConfigKey "modules" "{}" "${USER_CONFIG_FILE}"
  while read -r ID DESC; do
    writeConfigKey "modules.\"${ID}\"" "" "${USER_CONFIG_FILE}"
  done < <(getAllModules "${PLATFORM}" "${KVER}")
  arcsettings
}

###############################################################################
# Make Arc Settings
function arcsettings() {
  # Read Model Values
  MODEL="$(readConfigKey "model" "${USER_CONFIG_FILE}")"
  DT="$(readModelKey "${MODEL}" "dt")"
  ARCCONF="$(readConfigKey "arc.serial" "${MODEL_CONFIG_PATH}/${MODEL}.yml")"
  # Read Arc Patch from File
  SN="$(readModelKey "${MODEL}" "arc.serial")"
  writeConfigKey "arc.patch" "arc" "${USER_CONFIG_FILE}"
  writeConfigKey "addons.acpid" "" "${USER_CONFIG_FILE}"
  writeConfigKey "addons.cpuinfo" "" "${USER_CONFIG_FILE}"
  writeConfigKey "addons.hibernation" "" "${USER_CONFIG_FILE}"
  writeConfigKey "addons.hdddb" "" "${USER_CONFIG_FILE}"
  writeConfigKey "addons.multismb3" "" "${USER_CONFIG_FILE}"
  writeConfigKey "addons.nvmevolume" "" "${USER_CONFIG_FILE}"
  writeConfigKey "addons.powersched" "" "${USER_CONFIG_FILE}"
  writeConfigKey "addons.storagepanel" "" "${USER_CONFIG_FILE}"
  # Check for ACPI Support
  if ! grep -q "^flags.*acpi.*" /proc/cpuinfo; then
    deleteConfigKey "addons.acpid" "${USER_CONFIG_FILE}"
  fi
  writeConfigKey "arc.sn" "${SN}" "${USER_CONFIG_FILE}"
  ARCPATCH="$(readConfigKey "arc.patch" "${USER_CONFIG_FILE}")"
  # Get Network Config for Loader
  getnet
  # Get Portmap for Loader
  getmap
  # Config is done
  writeConfigKey "arc.confdone" "true" "${USER_CONFIG_FILE}"
  CONFDONE="$(readConfigKey "arc.confdone" "${USER_CONFIG_FILE}")"
  make
}

###############################################################################
# Building Loader Online
function make() {
  # Read Config
  MODEL="$(readConfigKey "model" "${USER_CONFIG_FILE}")"
  PLATFORM="$(readModelKey "${MODEL}" "platform")"
  PRODUCTVER="$(readConfigKey "productver" "${USER_CONFIG_FILE}")"
  KVER="$(readModelKey "${MODEL}" "productvers.[${PRODUCTVER}].kver")"
  if [ "${PLATFORM}" = "epyc7002" ]; then
    KVER="${PRODUCTVER}-${KVER}"
  fi
  if [ -d "${UNTAR_PAT_PATH}" ]; then
    rm -rf "${UNTAR_PAT_PATH}"
  fi
  mkdir -p "${UNTAR_PAT_PATH}"
  # Memory: Set mem_max_mb to the amount of installed memory to bypass Limitation
  writeConfigKey "synoinfo.mem_max_mb" "${RAMMAX}" "${USER_CONFIG_FILE}"
  writeConfigKey "synoinfo.mem_min_mb" "${RAMMIN}" "${USER_CONFIG_FILE}"
  # Check if all addon exists
  while IFS=': ' read -r ADDON PARAM; do
    [ -z "${ADDON}" ] && continue
    if ! checkAddonExist "${ADDON}" "${PLATFORM}" "${KVER}"; then
      dialog --backtitle "$(backtitle)" --title "Error" --aspect 18 \
        --msgbox "Addon ${ADDON} not found!" 0 0
      return 1
    fi
  done < <(readConfigMap "addons" "${USER_CONFIG_FILE}")
  # Check for eMMC Boot
  if [[ ! "${LOADER_DISK}" = /dev/mmcblk* ]]; then
    deleteConfigKey "modules.mmc_block" "${USER_CONFIG_FILE}"
    deleteConfigKey "modules.mmc_core" "${USER_CONFIG_FILE}"
  fi
  while true; do
    dialog --backtitle "$(backtitle)" --colors --title "Arc Build" \
      --infobox "Get PAT Data from Syno..." 3 30
    idx=0
    while [ ${idx} -le 3 ]; do # Loop 3 times, if successful, break
      PAT_URL="$(curl -skL "https://www.synology.com/api/support/findDownloadInfo?lang=en-us&product=${MODEL/+/%2B}&major=${PRODUCTVER%%.*}&minor=${PRODUCTVER##*.}" | jq -r '.info.system.detail[0].items[0].files[0].url')"
      PAT_HASH="$(curl -skL "https://www.synology.com/api/support/findDownloadInfo?lang=en-us&product=${MODEL/+/%2B}&major=${PRODUCTVER%%.*}&minor=${PRODUCTVER##*.}" | jq -r '.info.system.detail[0].items[0].files[0].checksum')"
      PAT_URL=${PAT_URL%%\?*}
      if [[ -n "${PAT_URL}" && -n "${PAT_HASH}" ]]; then
        break
      fi
      sleep 3
      idx=$((${idx} + 1))
    done
    if [[ -z "${PAT_URL}" || -z "${PAT_HASH}" ]]; then
      dialog --backtitle "$(backtitle)" --colors --title "Arc Build" \
        --infobox "Syno Connection failed,\ntry to get from Github..." 4 30
      idx=0
      while [ ${idx} -le 3 ]; do # Loop 3 times, if successful, break
        PAT_URL="$(curl -skL "https://raw.githubusercontent.com/AuxXxilium/arc-dsm/main/dsm/${MODEL/+/%2B}/${PRODUCTVER%%.*}.${PRODUCTVER##*.}/pat_url")"
        PAT_HASH="$(curl -skL "https://raw.githubusercontent.com/AuxXxilium/arc-dsm/main/dsm/${MODEL/+/%2B}/${PRODUCTVER%%.*}.${PRODUCTVER##*.}/pat_hash")"
        PAT_URL=${PAT_URL%%\?*}
        if [[ -n "${PAT_URL}" && -n "${PAT_HASH}" ]]; then
          break
        fi
        sleep 3
        idx=$((${idx} + 1))
      done
    fi
    break
  done
  writeConfigKey "arc.paturl" "${PAT_URL}" "${USER_CONFIG_FILE}"
  writeConfigKey "arc.pathash" "${PAT_HASH}" "${USER_CONFIG_FILE}"
  # Check for existing Files
  DSM_FILE="${UNTAR_PAT_PATH}/${PAT_HASH}.tar"
  # Get new Files
  DSM_URL="https://raw.githubusercontent.com/AuxXxilium/arc-dsm/main/files/${MODEL}/${PRODUCTVER}/${PAT_HASH}.tar"
  STATUS=$(curl --insecure -s -w "%{http_code}" -L "${DSM_URL}" -o "${DSM_FILE}")
  if [[ $? -ne 0 || ${STATUS} -ne 200 ]]; then
    dialog --backtitle "$(backtitle)" --title "DSM Download" --aspect 18 \
    --msgbox "No DSM Image found!\nTry Syno Link." 0 0
    # Grep PAT_URL
    PAT_FILE="${TMP_PATH}/${PAT_HASH}.pat"
    STATUS=$(curl -k -w "%{http_code}" -L "${PAT_URL}" -o "${PAT_FILE}" --progress-bar)
    if [[ $? -ne 0 || ${STATUS} -ne 200 ]]; then
      dialog --backtitle "$(backtitle)" --title "DSM Download" --aspect 18 \
        --msgbox "No DSM Image found!\ Exit." 0 0
      return 1
    fi
    # Extract Files
    header=$(od -bcN2 ${PAT_FILE} | head -1 | awk '{print $3}')
    case ${header} in
        105)
        isencrypted="no"
        ;;
        213)
        isencrypted="no"
        ;;
        255)
        isencrypted="yes"
        ;;
        *)
        echo -e "Could not determine if pat file is encrypted or not, maybe corrupted, try again!"
        ;;
    esac
    if [ "${isencrypted}" = "yes" ]; then
      # Uses the extractor to untar PAT file
      LD_LIBRARY_PATH="${EXTRACTOR_PATH}" "${EXTRACTOR_PATH}/${EXTRACTOR_BIN}" "${PAT_FILE}" "${UNTAR_PAT_PATH}"
    else
      # Untar PAT file
      tar xf "${PAT_FILE}" -C "${UNTAR_PAT_PATH}" >"${LOG_FILE}" 2>&1
    fi
    # Cleanup PAT Download
    rm -f "${PAT_FILE}"
  elif [ -f "${DSM_FILE}" ]; then
    tar xf "${DSM_FILE}" -C "${UNTAR_PAT_PATH}" >"${LOG_FILE}" 2>&1
  fi
  # Copy DSM Files to Locations if DSM Files not found
  cp -f "${UNTAR_PAT_PATH}/grub_cksum.syno" "${PART1_PATH}"
  cp -f "${UNTAR_PAT_PATH}/GRUB_VER" "${PART1_PATH}"
  cp -f "${UNTAR_PAT_PATH}/grub_cksum.syno" "${PART2_PATH}"
  cp -f "${UNTAR_PAT_PATH}/GRUB_VER" "${PART2_PATH}"
  cp -f "${UNTAR_PAT_PATH}/zImage" "${ORI_ZIMAGE_FILE}"
  cp -f "${UNTAR_PAT_PATH}/rd.gz" "${ORI_RDGZ_FILE}"
  rm -rf "${UNTAR_PAT_PATH}"
  # Reset Bootcount if User rebuild DSM
  if [[ -z "${BOOTCOUNT}" || ${BOOTCOUNT} -gt 0 ]]; then
    writeConfigKey "arc.bootcount" "0" "${USER_CONFIG_FILE}"
  fi
  (
    livepatch
    sleep 3
  ) 2>&1 | dialog --backtitle "$(backtitle)" --colors --title "Build Loader" \
    --progressbox "Doing the Magic..." 20 70
  if [[ -f "${ORI_ZIMAGE_FILE}" && -f "${ORI_RDGZ_FILE}" && -f "${MOD_ZIMAGE_FILE}" && -f "${MOD_RDGZ_FILE}" ]]; then
    # Build is done
    writeConfigKey "arc.builddone" "true" "${USER_CONFIG_FILE}"
    BUILDDONE="$(readConfigKey "arc.builddone" "${USER_CONFIG_FILE}")"
    boot && exit 0
  fi
}

###############################################################################
# Calls boot.sh to boot into DSM kernel/ramdisk
function boot() {
  BUILDDONE="$(readConfigKey "arc.builddone" "${USER_CONFIG_FILE}")"
  [ "${BUILDDONE}" = "false" ] && dialog --backtitle "$(backtitle)" --title "Alert" \
    --yesno "Config changed, you need to rebuild the Loader?" 0 0
  if [ $? -eq 0 ]; then
    make
  fi
  grub-editenv ${GRUB_PATH}/grubenv set next_entry="boot"
  writeConfigKey "arc.bootcount" "0" "${USER_CONFIG_FILE}"
  dialog --backtitle "$(backtitle)" --title "Arc Boot" \
    --infobox "Booting DSM...\nPlease stay patient!" 4 25
  sleep 2
  exec reboot
}

###############################################################################
###############################################################################
# Main loop
arcMenu

# Inform user
echo -e "Call \033[1;34marc.sh\033[0m to configure loader"
echo
echo -e "Access:"
echo -e "IP: \033[1;34m${IPCON}\033[0m"
echo -e "User: \033[1;34mroot\033[0m"
echo -e "Password: \033[1;34marc\033[0m"
echo
echo -e "Web Terminal Access:"
echo -e "Address: \033[1;34mhttp://${IPCON}:7681\033[0m"