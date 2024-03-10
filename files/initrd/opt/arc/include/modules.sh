###############################################################################
# Return list of all modules available
# 1 - Platform
# 2 - Kernel Version
function getAllModules() {
  local PLATFORM=${1}
  local KVER=${2}

  if [[ -z "${PLATFORM}" || -z "${KVER}" ]]; then
    echo ""
    return 1
  fi
  # Unzip modules for temporary folder
  rm -rf "${TMP_PATH}/modules"
  mkdir -p "${TMP_PATH}/modules"
  local KERNEL="$(readConfigKey "arc.kernel" "${USER_CONFIG_FILE}")"
  if [ "${KERNEL}" = "custom" ]; then
    tar zxf "${CUSTOM_PATH}/modules-${PLATFORM}-${KVER}.tgz" -C "${TMP_PATH}/modules"
  else
    tar zxf "${MODULES_PATH}/${PLATFORM}-${KVER}.tgz" -C "${TMP_PATH}/modules"
  fi
  # Get list of all modules
  for F in $(ls ${TMP_PATH}/modules/*.ko 2>/dev/null); do
    local X=$(basename ${F})
    local M=${X:0:-3}
    local DESC=$(modinfo ${F} | awk -F':' '/description:/{ print $2}' | awk '{sub(/^[ ]+/,""); print}')
    [ -z "${DESC}" ] && DESC="${X}"
    echo "${M} \"${DESC}\""
  done
  rm -rf "${TMP_PATH}/modules"
}

###############################################################################
# Return list of all modules available
# 1 - Platform
# 2 - Kernel Version
# 3 - Module list
function installModules() {
  local PLATFORM=${1}
  local KVER=${2}
  shift 2
  local MLIST="${@}"

  if [[ -z "${PLATFORM}" || -z "${KVER}" ]]; then
    echo ""
    return 1
  fi
  # Unzip modules for temporary folder
  rm -rf "${TMP_PATH}/modules"
  mkdir -p "${TMP_PATH}/modules"
  local KERNEL="$(readConfigKey "arc.kernel" "${USER_CONFIG_FILE}")"
  if [ "${KERNEL}" = "custom" ]; then
    tar zxf "${CUSTOM_PATH}/modules-${PLATFORM}-${KVER}.tgz" -C "${TMP_PATH}/modules"
  else
    tar zxf "${MODULES_PATH}/${PLATFORM}-${KVER}.tgz" -C "${TMP_PATH}/modules"
  fi
  local ODP="$(readConfigKey "arc.odp" "${USER_CONFIG_FILE}")"
  for F in $(ls "${TMP_PATH}/modules/"*.ko 2>/dev/null); do
    local M=$(basename ${F})
    [ "${ODP}" = "true" ] && [ -f "${RAMDISK_PATH}/usr/lib/modules/${M}" ] && continue
    if echo "${MLIST}" | grep -wq "${M:0:-3}"; then
      cp -f "${F}" "${RAMDISK_PATH}/usr/lib/modules/${M}"
    else
      rm -f "${RAMDISK_PATH}/usr/lib/modules/${M}"
    fi
  done
  mkdir -p "${RAMDISK_PATH}/usr/lib/firmware"
  if [ "${KERNEL}" = "custom" ]; then
    tar zxf "${CUSTOM_PATH}/firmware.tgz" -C "${RAMDISK_PATH}/usr/lib/firmware"
  else
    tar zxf "${MODULES_PATH}/firmware.tgz" -C "${RAMDISK_PATH}/usr/lib/firmware"
  fi
  # Clean
  rm -rf "${TMP_PATH}/modules"
}

###############################################################################
# add a ko of modules.tgz
# 1 - Platform
# 2 - Kernel Version
# 3 - ko file
function addToModules() {
  local PLATFORM=${1}
  local KVER=${2}
  local KOFILE=${3}

  if [[ -z "${PLATFORM}" || -z "${KVER}" || -z "${KOFILE}" ]]; then
    echo ""
    return 1
  fi
  # Unzip modules for temporary folder
  rm -rf "${TMP_PATH}/modules"
  mkdir -p "${TMP_PATH}/modules"
  tar zxf "${MODULES_PATH}/${PLATFORM}-${KVER}.tgz" -C "${TMP_PATH}/modules"
  cp -f ${KOFILE} ${TMP_PATH}/modules
  tar zcf "${MODULES_PATH}/${PLATFORM}-${KVER}.tgz" -C "${TMP_PATH}/modules" .
}

###############################################################################
# del a ko of modules.tgz
# 1 - Platform
# 2 - Kernel Version
# 3 - ko name
function delToModules() {
  local PLATFORM=${1}
  local KVER=${2}
  local KONAME=${3}

  if [[ -z "${PLATFORM}" || -z "${KVER}" || -z "${KOFILE}" ]]; then
    echo ""
    return 1
  fi
  # Unzip modules for temporary folder
  rm -rf "${TMP_PATH}/modules"
  mkdir -p "${TMP_PATH}/modules"
  tar zxf "${MODULES_PATH}/${PLATFORM}-${KVER}.tgz" -C "${TMP_PATH}/modules"
  rm -f ${TMP_PATH}/modules/${KONAME}
  tar zcf "${MODULES_PATH}/${PLATFORM}-${KVER}.tgz" -C "${TMP_PATH}/modules" .
}

###############################################################################
# get depends of ko
# 1 - Platform
# 2 - Kernel Version
# 3 - ko name
function getdepends() {
  function _getdepends() {
    if [ -f "${TMP_PATH}/modules/${1}.ko" ]; then
      depends=($(modinfo "${TMP_PATH}/modules/${1}.ko" | grep depends: | awk -F: '{print $2}' | awk '$1=$1' | sed 's/,/ /g'))
      if [ ${#depends[@]} -gt 0 ]; then
        for k in ${depends[@]}; do
          echo "${k}"
          _getdepends "${k}"
        done
      fi
    fi
  }
  local PLATFORM=${1}
  local KVER=${2}
  local KONAME=${3}

  if [[ -z "${PLATFORM}" || -z "${KVER}" || -z "${KOFILE}" ]]; then
    echo ""
    return 1
  fi
  # Unzip modules for temporary folder
  rm -rf "${TMP_PATH}/modules"
  mkdir -p "${TMP_PATH}/modules"
  tar zxf "${MODULES_PATH}/${PLATFORM}-${KVER}.tgz" -C "${TMP_PATH}/modules"
  DPS=($(_getdepends ${KONAME} | tr ' ' '\n' | sort -u))
  echo ${DPS[@]}
  rm -rf "${TMP_PATH}/modules"
}
