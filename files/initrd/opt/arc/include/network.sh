# Get Network Config for Loader
function getnet() {
  ARCPATCH="$(readConfigKey "arc.patch" "${USER_CONFIG_FILE}")"
  ARCMACNUM=4
  ARCMAC="$(readModelKey "${MODEL}" "arc.mac${ARCMACNUM}")"
  writeConfigKey "mac.eth0" "${ARCMAC}" "${USER_CONFIG_FILE}"
  writeConfigKey "arc.macsys" "arc" "${USER_CONFIG_FILE}"
  MACSYS="$(readConfigKey "arc.macsys" "${USER_CONFIG_FILE}")"
}

# Get Amount of NIC
ETHX=$(ls /sys/class/net/ | grep -v lo) || true
# Get actual IP
for ETH in ${ETHX}; do
  IPCON="$(readConfigKey "ip.${ETH}" "${USER_CONFIG_FILE}")"
  [ -z "${IPCON}" ] && IPCON="$(getIP ${ETH})"
  [ -n "${IPCON}" ] && break
done