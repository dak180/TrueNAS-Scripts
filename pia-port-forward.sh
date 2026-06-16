#!/usr/local/bin/bash

# Copyright (c) 2023 dak180 and contributors. See
# https://opensource.org/licenses/mit-license.php
#
# Enable port forwarding for transmission specifically in FreeBSD.
#
# Requirements:
#   This can be executed from cron or from the shell with no arguments
#   Ensure that your PIA credentials are accessable from this script.
#
# Packages needed:
#   pkg install -y sudo transmission-cli transmission-utils base64 jq curl wget openvpn bash
#
# Usage:
#  ./pia-port-forward.sh or bash pia-port-forward.sh or call from cron
#
# shellcheck disable=SC2236

# Export path for when you use this in cron
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/games:/usr/local/sbin:/usr/local/bin:/root/bin"

# Config
vpnUser="transmission"
vpnDir="/usr/local/etc/openvpn"
tempDir="/tmp/piaPort"
curlMaxTime="15"
firewallScript="/mnt/scripts/trans/ipfw.rules"
payloadFile="${tempDir}/payload.sig"
passFile="${vpnDir}/pass.txt"
varFile="${vpnDir}/vars.tool"
confFile="${vpnDir}/openvpn.conf"
gateFile="${tempDir}/gateway.txt"
gateCert="${tempDir}/gateway.pem"
gateHost=""

mapfile -t auth < "${passFile}"
PIA_USER="${auth[0]}"
PIA_PASS="${auth[1]}"

if [ ! -d "${tempDir}" ]; then
	mkdir -p "${tempDir}"
fi

function check_for_connectivity() {
	if sudo -u "${vpnUser}" -- nc -zw 1 google.com 80 &> /dev/null; then
		echo "| VPN connection up." 1>&2
		return 0
	else
		echo "| VPN connection down." 1>&2
		return 1
	fi
}

function re_check_connectivity() {
	# google.com
	if sudo -u "${vpnUser}" -- nc -zw 1 google.com 80 &> /dev/null; then
		echo "| VPN connection restored." 1>&2
		return 0
	else
		echo "| Unable to restore VPN connection. Subscription expired? Exiting." 1>&2
		exit 1
	fi
}

function restart_vpn() {

	echo "| Restarting openvpn." 1>&2
	service openvpn restart &> /dev/null
	sleep 15

	${firewallScript}
}

function VPN_Status() {
	# set adaptorName
	# Config
	local tunnelAdapter
	local try

	tunnelAdapter="$(ifconfig | grep -v "groups" | grep "tun" | cut -d ":" -f1 | tail -n 1)"
	while [ -z "${tunnelAdapter}" ] && [ "${try:=0}" -le "20" ]; do
		tunnelAdapter="$(ifconfig | grep -v "groups" | grep "tun" | cut -d ":" -f1 | tail -n 1)"
		try="$(( try + 1 ))"
		sleep 3
	done

	if [ -z "${tunnelAdapter}" ]; then
		return 1
	else
		echo "${tunnelAdapter}"
		return 0
	fi
}

function is_port_forwarded() {
	# test to see if the port is already forwarded
	# Config
	local json
	local currentPort

	# -si gets the session info including the current port
	currentPort="$(transmission-remote -si | grep 'Listen port' | sed -e 's|[[:blank:]]*Listen port: ||')"
	if [ ! "${payLoadPort}" = "${currentPort}" ]; then
		echo "| Configured port ${currentPort} does not match PIA port ${payLoadPort}." 1>&2
		return 1
	fi

	# -pt tests for open port.
	json="$(transmission-remote -pt 2>&1)"
	if [ "${json}" == "Port is open: No" ] ; then
		echo "| Closed port detected." 1>&2
		return 1
	elif [ "${json}" == "Port is open: Yes" ]; then
		echo "| Open port detected." 1>&2
		return 0
	else
		echo "| Error: transmission said: ${json}" 1>&2
		exit 1
	fi
}

function write_gateway_script() {
	tee "${varFile}" <<- EOL
		#!/usr/local/bin/bash


		/bin/echo "\${route_vpn_gateway}" > "${gateFile}"

EOL
	chmod +x "${varFile}"

	if grep -q "^script-security 1" < "${confFile}"; then
		sed -i '' -e 's:script-security 1:script-security 2:' "${confFile}"
	elif grep -q "^script-security 0" < "${confFile}"; then
		sed -i '' -e 's:script-security 0:script-security 2:' "${confFile}"
	elif ! grep -q "^script-security" < "${confFile}"; then
		tee -a "${confFile}" <<< "script-security 2"
	fi

	if ! grep -q "^up '${varFile}'" < "${confFile}"; then
		tee -a "${confFile}" <<< "up '${varFile}'"
	fi
	restart_vpn
}

function get_gateway_ip() {
	# get gateway ip address
	# Config
	local gatewayAddress

	if [ ! -x "${varFile}" ]; then
		write_gateway_script
	elif [ ! -s "${gateFile}" ]; then
		restart_vpn
	fi

	gatewayAddress="$(cat "${gateFile}")"
	if [ ! -s "${gateCert}" ] || [ "${gateFile}" -nt "${gateCert}" ]; then
		openssl s_client -connect "${gatewayAddress}:19999" -showcerts 2> /dev/null 1> "${gateCert}"
	fi
	gateHost="$(openssl x509 -noout -ext subjectAltName -in "${gateCert}" | grep 'DNS' | sed -e 's|[[:blank:]]*DNS:||')"

	echo "${gatewayAddress} ${gateHost}"
	return 0
}

function get_auth_token() {
    # Get Auth Token
    # Config
	local adaptorName

    local authToken
    local tokenFile
    tokenFile="${payloadFile}"
    tokenError="$(cat "${tokenFile}.tokenError" 2> /dev/null)"

	adaptorName="${1}"

	if [ -s "${tokenFile}" ]; then
		authToken="$(jq -Mre '.payload | values' < "${tokenFile}" | base64 -d | jq -Mre '.token | values')"
	elif [[ ! "${tokenError:-0}" -le "0" ]]; then
		tokenError="$(( tokenError - 1 ))"
	else
		echo "| Acquiring new auth token." 1>&2

		authToken="$(sudo -u "${vpnUser}" -- curl \
		--interface "${adaptorName}" \
		--request POST \
		--silent --show-error --fail --location \
		--max-time "${curlMaxTime}" \
		--data-urlencode "username=${PIA_USER}" \
		--data-urlencode "password=${PIA_PASS}" \
		'https://www.privateinternetaccess.com/api/client/v2/token' 2> /dev/null)"
		local tokenError="${?}"
		if [ ! "${tokenError}" = "0" ]; then
			tokenError="3"
		fi

		if [ -z "${authToken}" ]; then
			authToken="$(sudo -u "${vpnUser}" -- curl \
			--http1.1 --no-alpn \
			--interface "${adaptorName}" \
			--get --insecure --silent --show-error --fail --location \
			--max-time "${curlMaxTime}" \
			-u "${PIA_USER}:${PIA_PASS}" \
			"https://10.0.0.1/authv3/generateToken" 2> /dev/null)"

		fi
		authToken="$(jq -Mre '.token | values' <<< "${authToken}")"
	fi

	if [ ! -z "${authToken}" ]; then
		rm -f "${tokenFile}.tokenError"
    	echo "${authToken}"
    	return 0
    elif [ ! "${tokenError}" = "0" ]; then
		echo "| Skipping the next ${tokenError} attempts." 1>&2
		echo "${tokenError}" > "${tokenFile}.tokenError"
		exit 1
    else
		echo "| Failed to acquire new auth token." 1>&2
		rm -f "${tokenFile}"
		echo "${tokenError}" > "${tokenFile}.tokenError"
    	exit 1
    fi
}

function get_payload_and_sig() {
	# Get payload & signature
	# Config
	local authToken
	local gatewayAddress
	local adaptorName

	local json
	local Pstatus
	local Pexpire

	authToken="${1}"
	gatewayAddress="${2}"
	adaptorName="${3}"


	if [ -s "${payloadFile}" ]; then
		json="$(cat "${payloadFile}")"
	elif [ ! -z "${authToken}" ]; then
		json="$(sudo -u "${vpnUser}" -- curl \
		--http1.1 --no-alpn \
		--interface "${adaptorName}" \
		--cacert "${gateCert}" \
		--connect-to "${gateHost}::${gatewayAddress}:" \
		--silent --show-error --fail --location -G \
		--max-time "${curlMaxTime}" \
		--data-urlencode "token=${authToken}" \
		"https://${gateHost}:19999/getSignature" 2> /dev/null \
		| jq -Mre . \
		| tee "${payloadFile}")"

		echo "| Acquired new Signature." 1>&2
	else
		exit 1
	fi
	Pstatus="$(jq -Mre '.status | values' <<< "${json}")"
	Pexpire="$(date -juf '%FT%T' "$(jq -Mre '.payload | values' <<< "${json}" | base64 -d | jq -Mre '.expires_at | values' | cut -c '1-19')" +'%s' 2> /dev/null)"

	if [ ! "${Pstatus}" = "OK" ]; then
		echo "| Status is not ok: ${Pstatus}" 1>&2
		rm -f "${payloadFile}"
		exit 1
	elif [ "$(date -ju +'%s' 2> /dev/null)" -ge "${Pexpire}" ]; then
		echo "| Payload file is expired." 1>&2
		rm -f "${payloadFile}"
		exit 1
	fi

	echo "${json}"
}

function set_port() {
	# if port is not forwarded, get a new port for transmission
	echo "| Loading port forward assignment information.." 1>&2

	# Config
	local json
	local PORTNUM

	json="${1}"

	PORTNUM="$(echo "${json}" | grep -oE "[0-9]+")"
	# test to make sure that the port is actually a number
	if echo "${PORTNUM}" | grep -qE '^\-?[0-9]+$'; then
		# it IS numeric
        echo "| New port: ${PORTNUM}" 1>&2
        if ! transmission-remote -p "${PORTNUM}" &> /dev/null; then
        	return 2
        fi
        return 0
	else
		# it is NOT numeric.
		echo "| Garbled data: ${PORTNUM}" 1>&2
		return 1
	fi
}

function refresh_port() {
	# Bind the port to the server; this must be done at least every 15 mins.

	# Config
	local payload
	local signature
	local gatewayAddress
	local adaptorName

	local json
	local bindStatus
	local bindMessage

	payload="${1}"
	signature="${2}"
	gatewayAddress="${3}"
	adaptorName="${4}"

	json="$(sudo -u "${vpnUser}" -- curl \
	--http1.1 --no-alpn \
	--interface "${adaptorName}" \
	--get \
	--cacert "${gateCert}" \
	--connect-to "${gateHost}::${gatewayAddress}:" \
	--silent --show-error --fail --location \
	--max-time "${curlMaxTime}" \
	--data-urlencode "payload=${payload}" \
	--data-urlencode "signature=${signature}" \
	"https://${gateHost}:19999/bindPort" 2> /dev/null)"
	bindStatus="$(jq -Mre '.status | values' <<< "${json}")"
	bindMessage="$(jq -Mre '.message | values' <<< "${json}")"


	if [ ! "${bindStatus}" = "OK" ]; then
		echo "| Failed to bind the port: ${bindStatus:="Bad Gateway"}; ${bindMessage:="Incorrect gateway address"}" 1>&2
		exit 1
	else
		echo "| Status: ${bindMessage}."
		return 0
	fi
}


# First check for connectivity using the user that executes Transmission.  If this fails, script will try to relaunch openvpn service and re-check (15 second pause to allow OpenVPN to start)
# If re-check fails, script will exit without any other execution.
#
# Second this will check for port forward status.  If the port forward
# is enabled, script will exit.  If the port is not properly
# forwarded, the script will call for a new port assignment and if it
# is valid, will tell transmission to use the new port.

# echo date/time for logging
echo "+----------------------" 1>&2
echo "| Transmission Port Forward $(date '+%F %T')" 1>&2

# Check that the vpn is up
if ! check_for_connectivity; then
	restart_vpn
	tunnelAdapter="$(VPN_Status)"
	re_check_connectivity
else
	tunnelAdapter="$(VPN_Status)"
fi

if [ -z "${tunnelAdapter}" ]; then
	echo "| Could not find tunnel adapter." 1>&2
	exit 1
fi

# Parse Payload
read -r gateIP gateHost <<< "$(get_gateway_ip)"
payloadPlusSig="$(get_payload_and_sig "$(get_auth_token "${tunnelAdapter}")" "${gateIP}" "${tunnelAdapter}")"

# Try to catch error conditions
if [ -z "${payloadPlusSig}" ]; then
	exit 1
fi

payloadSig="$(echo "${payloadPlusSig}" | jq -Mre ".signature")"
payLoad="$(echo "${payloadPlusSig}" | jq -Mre ".payload")"
payLoadPort="$(echo "${payLoad}" | base64 -d | jq -Mre ".port")"


# Check port
is_port_forwarded
portStatus="${?}"

# Get the port if we do not have one
if [ "${portStatus}" = "1" ]; then
	if ! set_port "${payLoadPort}"; then
		echo "| Cannot set the port." 1>&2
		exit 1
	fi
fi

# Refresh the port
refresh_port "${payLoad}" "${payloadSig}" "${gateIP}" "${tunnelAdapter}"

exit 0
