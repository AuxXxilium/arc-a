# Get Network Config for Loader
function getnet() {
  ETHX=$(ls /sys/class/net/ 2>/dev/null | grep eth) || true
  ARCPATCH="$(readConfigKey "arc.patch" "${USER_CONFIG_FILE}")"
  ARCMACNUM=1
  for ETH in ${ETHX}; do
    ARCMAC="$(readModelKey "${MODEL}" "arc.mac${ARCMACNUM}")"
    [ -n "${ARCMAC}" ] && writeConfigKey "mac.${ETH}" "${ARCMAC}" "${USER_CONFIG_FILE}"
    [ -z "${ARCMAC}" ] && break
    ARCMACNUM=$((${ARCMACNUM} + 1))
    ARCMAC=""
  done
  writeConfigKey "arc.macsys" "hardware" "${USER_CONFIG_FILE}"
  MACSYS="$(readConfigKey "arc.macsys" "${USER_CONFIG_FILE}")"
}

# Get Amount of NIC
ETHX=$(ls /sys/class/net/ 2>/dev/null | grep eth) || true
# Get actual IP
for ETH in ${ETHX}; do
  IPCON="$(getIP ${ETH})"
  [ -n "${IPCON}" ] && break
done