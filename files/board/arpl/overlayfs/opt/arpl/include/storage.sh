# Get SataPortMap for Loader
function getmap() {
  [ -n "$SATAPORTMAP" ] && SATAPORTMAP=0
  rm -f ${TMP_PATH}/drives
  touch ${TMP_PATH}/drives
  # Get Number of Drives per Sata Controller
  pcis=$(lspci -nnk | grep -ie "\[0106\]" | awk '{print $1}')
  [ ! -z "$pcis" ]
  # loop through controllers
  for pci in $pcis; do
  # get attached block devices (exclude CD-ROMs)
  DRIVES=$(ls -la /sys/block | fgrep "${pci}" | grep -v "sr.$" | wc -l)
  if [ "$DRIVES" -gt "8" ]; then
    DRIVES=8
    WARNON=1
  fi
  echo -n "$DRIVES" >> ${TMP_PATH}/drives
  done
  # Get Number of Drives per SCSI Controller
  pcis=$(lspci -nnk | grep -ie "\[0104\]" | awk '{print $1}')
  [ ! -z "$pcis" ]
  # loop through controllers
  for pci in $pcis; do
  # get attached block devices (exclude CD-ROMs)
  DRIVES=$(ls -la /sys/block | fgrep "${pci}" | grep -v "sr.$" | wc -l)
  if [ "$DRIVES" -gt "8" ]; then
    DRIVES=8
    WARNON=1
  fi
  echo -n "$DRIVES" >> ${TMP_PATH}/drives
  done
  # Get Number of Drives per SAS Controller
  pcis=$(lspci -nnk | grep -ie "\[0107\]" | awk '{print $1}')
  [ ! -z "$pcis" ]
  # loop through controllers
  for pci in $pcis; do
  # get attached block devices (exclude CD-ROMs)
  DRIVES=$(ls -la /sys/block | fgrep "${pci}" | grep -v "sr.$" | wc -l)
  if [ "$DRIVES" -gt "8" ]; then
    DRIVES=8
    WARNON=1
  fi
  echo -n "$DRIVES" >> ${TMP_PATH}/drives
  done
  # Write to config
  SATAPORTMAP=$(awk '{print$1}' ${TMP_PATH}/drives)
  if [ "$SATAPORTMAP" -lt "11" ]; then
    deleteConfigKey "cmdline.SataPortMap" "${USER_CONFIG_FILE}"
  else
    writeConfigKey "cmdline.SataPortMap" "${SATAPORTMAP}" "${USER_CONFIG_FILE}"
  fi
  #writeConfigKey "cmdline.DiskIdxMap" "0" "${USER_CONFIG_FILE}"
}

# Check for Controller
SATAPORTMAP="`readConfigKey "cmdline.SataPortMap" "${USER_CONFIG_FILE}"`"
SATACONTROLLER=$(lspci -nnk | grep -ie "\[0106\]" | wc -l)
SCSICONTROLLER=$(lspci -nnk | grep -ie "\[0104\]" -ie "\[0107\]" | wc -l)

# Launch getmap
getmap