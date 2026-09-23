#!/bin/bash

# Change this array to hold the containers you want to check
# No commas between items, each item in quotes.
# eg: CONTAINERS=("prowlarr" "transmission")

CONTAINERS=("prowlarr" "transmission")


# -----------------------------------------------------------
# No need to change anything below here
GRN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1;4m'

output(){
	MESSAGE=$1
	COL=$GRN
	echo -e "${COL}${MESSAGE}${NC}"
}

output_error(){
	MESSAGE=$1
	COL=$RED
	echo -e "${COL}${MESSAGE}${NC}"
}
echo
echo    "========================================================================="
echo -e "This script validates that your containers behind a VPN are"
echo -e " correctly using the VPN for OUTBOUND traffic."
echo -e " - A ${RED}RED${NC} IP address means the container's egress is the same as your host"
echo -e " - A ${GRN}GREEN${NC} IP address means the container's egress is across the VPN"
echo    "========================================================================="
echo
echo "This hosts public IP:"
PUBLIC_IP=$(wget -q -O - http://api.ipify.org)
output "  - $PUBLIC_IP"
echo

for CONTAINER in "${CONTAINERS[@]}"; do
	echo -e "Checking ${BOLD}${CONTAINER}${NC}..."

	if ! docker container ps | grep ${CONTAINER} >/dev/null 2>&1; then
		output_error "  - Container not running"
		echo
		continue
	fi

	echo " External IP: "
	EXT_IP_GRABBED=false

	if docker exec "${CONTAINER}" which wget >/dev/null 2>&1; then
		EXT_IP=$(docker exec "${CONTAINER}" wget -q -O - http://api.ipify.org)
		EXT_IP_GRABBED=true
	elif docker exec "${CONTAINER}" which curl >/dev/null 2>&1; then
		EXT_IP=$(docker exec "${CONTAINER}" curl -s api.ipify.org)
		EXT_IP_GRABBED=true
	elif docker exec "${CONTAINER}" which nc >/dev/null 2>&1; then
		EXT_IP=$(docker exec "${CONTAINER}" sh -c "echo -e 'GET / HTTP/1.1\r\nHost: api.ipify.org\r\nConnection: close\r\n\r\n' | nc api.ipify.org 80 | grep -oE '([0-9]{1,3}\\.){3}[0-9]{1,3}'")
		EXT_IP_GRABBED=true
	else
		EXT_IP="\"No wget,curl,nc available in container\""
	fi
	if [[ $EXT_IP_GRABBED == "true" ]]; then
		if [[ "${EXT_IP}" == "${PUBLIC_IP}" ]]; then
			output_error "  - ${EXT_IP}"
		else
			output "  - ${EXT_IP}"
		fi
	else
		output_error "  - ${EXT_IP}"
	fi

	if docker exec "${CONTAINER}" which ping >/dev/null 2>&1; then
		echo " Check internet connectivity:"
		if docker exec "${CONTAINER}" ping -c 2 -W 1 8.8.8.8 > /dev/null 2>&1; then
			output "  - OK"
		else
			output_error "  - FAIL"
		fi

		echo " Check DNS resolution:"
		if docker exec "${CONTAINER}" ping -c 2 -W 1 google.com > /dev/null 2>&1; then
			output "  - OK"
		else
			output_error "  - FAIL"
		fi
	else
		echo " Check internet connectivity:"
		output_error "  - Ping, Name resolution check not possible, ping not availabe in container" "false"
	fi
	echo
done
