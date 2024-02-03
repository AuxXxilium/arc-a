# Get Network Config for Loader
function getnet() {
  ARCPATCH="$(readConfigKey "arc.patch" "${USER_CONFIG_FILE}")"
  ARCMACNUM=4
  ARCMAC="$(readModelKey "${MODEL}" "arc.mac${ARCMACNUM}")"
  writeConfigKey "arc.mac1" "${ARCMAC}" "${USER_CONFIG_FILE}"
  writeConfigKey "arc.macsys" "hardware" "${USER_CONFIG_FILE}"
  MACSYS="$(readConfigKey "arc.macsys" "${USER_CONFIG_FILE}")"
}

# Get Amount of NIC
ETHX=$(ls /sys/class/net/ | grep -v lo) || true
ETH=$(echo ${ETHX} | wc -w)
writeConfigKey "device.nic" "${ETH}" "${USER_CONFIG_FILE}"
# Get actual IP
ARCIP="$(readConfigKey "arc.ip" "${USER_CONFIG_FILE}")"
if [ -n "${ARCIP}" ]; then
  IPCON="${ARCIP}"
else
  IPCON="$(getIP)"
fi