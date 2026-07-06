#!/bin/bash
# shellcheck disable=SC2001

# Write out a default config file
function cConfig() {
	tee > "${configFile}" <<"EOF"
# Set this to 0 to enable
defaultFile="1"
configVers=0

# Common paths to be mounted into jails (relative to the host).
mediaPth="/mnt/data/Media" # path to media; will be mounted to `/media` in jails
cDataPath="/mnt/jails/Data" # prefix path to where persistant container application data will be ie: `/mnt/jails/Data/znc` these datasets will need to be created prior to making the jail
gitPath="/mnt/data/git" # a location for git repos so a different Record Size can be set
backupPth="/mnt/data/Backups" # prefix path to backup locations ie: `/mnt/data/Backups/plex`
scriptPth="/mnt/jails/scripts" # path to a common set of scripts
thingPath="/mnt/data/Things" # path to a general SMB share
userPth="/mnt/jails/users/dak180" # path to a full user directory on the base system

# Common paths in containers (relative to the container).
usrpth="/mnt/scripts/user" # where user files are loaded into container ie: .bashrc .profile .nanorc .config/*

# Common Settings
media_gid="1001"
comn_umask="002"

# Common Networks
declare -A vlan10_net=(
[subnet]="192.168.9.0/24"
[gateway]="192.168.9.1"
[bridge]="br10"
)

##### Container specific settings

# Plex + Tautulli
{
# Checklist before creating this jail:
# Ensure a group named `jailmedia` is created on the main system with GID `1001`
# Ensure a user named `plex` is created on the main system with UID `972`
# Ensure a user named `tautulli` is created on the main system with UID `892`
# ${mediaPth} is set and is r/w by `jailmedia`
# ${jDataPath}/plex is set and is owned by `plex`
# ${backupPth}/plex is set and is owned by `plex`
# ${jDataPath}/Tautulli is set and is owned by `tautulli`


# In this example we are disabling ipv6, setting the name of the bridge we are connecting to (or creating), what interface our trafic will go through (in this case the same as the web interface), and set the use of DHCP and a fixed MAC address pair to go with it.
declare -A _plex=(
[puid]="972"
[pgid]="${media_gid}"
[umask]="${comn_umask}"
[icon]="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/plex.svg"
[networks]="vlan10_net"
[volumes]="${cDataPath}/plex:/config,${mediaPth}:/media,${backupPth}/plex:/mnt/dbBackup"
[devices]="/dev/dri:/dev/dri"
)
declare -A _plex_vlan10_net=(
# [mac_address]=""
# [ipv4_address]=""
)

declare -A _tautulli=(
[puid]="892"
[pgid]="${media_gid}"
[umask]="${comn_umask}"
[icon]="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/tautulli.svg"
[networks]="vlan10_net"
[volumes]="${cDataPath}/Tautulli:/config"
)
declare -A _tautulli_vlan10_net=(
# [mac_address]=""
# [ipv4_address]=""
)

}

EOF
}

while getopts ":c:t:T" OPTION; do
	case "${OPTION}" in
		c)
			configFile="${OPTARG}"
		;;
		t)
			cnType="${OPTARG}"
		;;
		T)
			testing="true"
		;;
		?)
			# If an unknown flag is used (or -?):
			echo "${0} -c <configFile> -t <containerType>" >&2
			exit 1
		;;
	esac
done

if [ -z "${configFile}" ]; then
	echo "Please specify a config file location; if none exist one will be created." >&2
	exit 1
elif [ ! -f "${configFile}" ]; then
	cConfig
	exit 0
elif [ -z "${cnType}" ]; then
	echo "Please specify a container type." >&2
	exit 1
fi

# shellcheck source=./containers.cfg
. "${configFile}"

# Do not run if the config file has not been edited.
if [ ! "${defaultFile}" = "0" ]; then
	echo "Please edit the config file for your setup" >&2
	exit 1
elif [ ! "${configVers}" = "0" ]; then
	mv "${configFile}" "${configFile}.bak"
	cConfig
	echo "The config has been changed please update it for your setup" >&2
	exit 1
fi


# Common Functions

function dockerWrite() {
	local name
	local payload
	local output

	name="${1}"
	payload="${2}"

	output="$(jq -n \
		--arg name "${name}" \
		--argjson config "${payload}" \
		'{app_name: $name, custom_app: true, custom_compose_config: $config}')"

	if [ -z "${testing}" ]; then
		sudo midclt call app.create "${output}"
	else
		echo "${output}"
	fi
}

function dockerNetwork() {
	local netName
	local bridgeCheck

	netName="${1}"
	local subnet="${netName}[subnet]"
	local gateway="${netName}[gateway]"
	local bridge="${netName}[bridge]"

	if [ -z "${!subnet}" ] || [ -z "${!gateway}" ] || [ -z "${!bridge}" ]; then
		echo "Network ${netName} is not defined!" >&2
		exit 1
	fi

	bridgeCheck="$(midclt call interface.query | jq -r --arg bn "${!bridge}" '.[] | select(.type == "BRIDGE" and .name == $bn) | .name')"
	if [ ! "${bridgeCheck}" = "${!bridge}" ]; then
		echo "Bridge ${!bridge} does not exist!" >&2
		exit 1
	fi


	if [ -z "${testing}" ]; then
		echo "Network Details: ${netName};${!subnet};${!gateway};${!bridge}"
		return 0
	elif docker network ls --format '{{.Name}}' | grep -q "^${netName}$"; then
		echo "Network matches an existing configuration."
		return 0
	else
		sudo docker network create -d macvlan \
		--subnet="${!subnet}" \
		--gateway="${!gateway}" \
		-o parent="${!bridge}" \
		"${netName}"
	fi
}

# Prevent sudo timeout
sudo -v # ask for sudo password up-front
while true; do
  # Update user's timestamp without running a command
  sudo -nv; sleep "60"
  # Exit when the parent process is not running any more. In fact this loop
  # would be killed anyway after being an orphan (when the parent process
  # exits). But this ensures that and probably exits sooner.
  kill -0 $$ 2>/dev/null || exit
done &


# Container Creation
if [ "${cnType}" = "plex" ]; then
{
	containConfig="{}"
	containConfig="$(jq '. += {"services": {},"networks": {}}' <<< "${containConfig}")"

# Setup the Network
{
	mapfile -t containNetworks < <(sed -e 's:,:\n:g' <<< "${_plex[networks]},${_tautulli[networks]}" | uniq)
	for containNetwork in "${containNetworks[@]}"; do
		dockerNetwork "${containNetwork}"
		containConfig="$(jq --arg network "${containNetwork}" '.networks += {($network): {"external": true}}' <<< "${containConfig}")"
	done
	mapfile -t plexNetworks < <(sed -e 's:,:\n:g' <<< "${_plex[networks]}")
	mapfile -t tautulliNetworks < <(sed -e 's:,:\n:g' <<< "${_tautulli[networks]}")
}

# plex
{
	# Start to build the json
	containConfig="$(jq '.services += {"plex": {"image": "lscr.io/linuxserver/plex:latest", "container_name": "plex", "environment": [], "volumes": [], "restart": "unless-stopped"}}' <<< "${containConfig}")"

	# Add passthrough devices for transcoding if present
	if [ ! -z "${_plex[devices]}" ]; then
		containConfig="$(jq --arg devices "${_plex[devices]}" '.services.plex += {"devices": [$devices]}' <<< "${containConfig}")"
	fi

	# Setup the environment
	containConfig="$(jq --arg puid "${_plex[puid]}" '.services.plex.environment += ["PUID=\($puid)"]' <<< "${containConfig}")"
	containConfig="$(jq --arg pgid "${_plex[pgid]}" '.services.plex.environment += ["PGID=\($pgid)"]' <<< "${containConfig}")"
	containConfig="$(jq --arg umask "${_plex[umask]}" '.services.plex.environment += ["UMASK=\($umask)"]' <<< "${containConfig}")"
	containConfig="$(jq '.services.plex.environment += ["VERSION=docker"]' <<< "${containConfig}")"

	# Add the mounts
	mapfile -t plexMounts < <(sed -e 's:,:\n:g' <<< "${_plex[volumes]}")
	for plexMount in "${plexMounts[@]}"; do
		containConfig="$(jq --arg volumes "${plexMount}" '.services.plex.volumes += [$volumes]' <<< "${containConfig}")"
	done

	# Assign network info
	for plexNetwork in "${plexNetworks[@]}"; do
		plexNetMac="_plex_${plexNetwork}[mac_address]"
		if [ ! -z "${!plexNetMac}" ]; then
			containConfig="$(jq --arg network "${plexNetwork}" --arg mac_address "${!plexNetMac}" '.services.plex.networks[$network] += {"mac_address": $mac_address}' <<< "${containConfig}")"
		fi
		plexNetIpv4="_plex_${plexNetwork}[ipv4_address]"
		containConfig="$(jq --arg network "${plexNetwork}" --arg ipv4_address "${!plexNetIpv4}" '.services.plex.networks[$network] += {"ipv4_address": $ipv4_address}' <<< "${containConfig}")"
	done
}

# tautulli
{
	# Start to build the json
	containConfig="$(jq '.services += {"tautulli": {"image": "lscr.io/linuxserver/tautulli:latest", "container_name": "tautulli", "environment": [], "volumes": [], "restart": "unless-stopped"}}' <<< "${containConfig}")"

	# Setup the environment
	containConfig="$(jq --arg puid "${_tautulli[puid]}" '.services.tautulli.environment += ["PUID=\($puid)"]' <<< "${containConfig}")"
	containConfig="$(jq --arg pgid "${_tautulli[pgid]}" '.services.tautulli.environment += ["PGID=\($pgid)"]' <<< "${containConfig}")"
	containConfig="$(jq --arg umask "${_tautulli[umask]}" '.services.tautulli.environment += ["UMASK=\($umask)"]' <<< "${containConfig}")"

	# Add the mounts
	mapfile -t tautulliMounts < <(sed -e 's:,:\n:g' <<< "${_tautulli[volumes]}")
	for tautulliMount in "${tautulliMounts[@]}"; do
		containConfig="$(jq --arg volumes "${tautulliMount}" '.services.tautulli.volumes += [$volumes]' <<< "${containConfig}")"
	done

	# Assign network info
	for tautulliNetwork in "${tautulliNetworks[@]}"; do
		tautulliNetMac="_tautulli_${tautulliNetwork}[mac_address]"
		if [ ! -z "${!tautulliNetMac}" ]; then
			containConfig="$(jq --arg network "${tautulliNetwork}" --arg mac_address "${!tautulliNetMac}" '.services.tautulli.networks[$network] += {"mac_address": $mac_address}' <<< "${containConfig}")"
		fi
		tautulliNetIpv4="_tautulli_${tautulliNetwork}[ipv4_address]"
		containConfig="$(jq --arg network "${tautulliNetwork}" --arg ipv4_address "${!tautulliNetIpv4}" '.services.tautulli.networks[$network] += {"ipv4_address": $ipv4_address}' <<< "${containConfig}")"
	done
}

	dockerWrite "${cnType}" "${containConfig}"
}
else
{
	echo "Please specify a supported container type. See ${configFile} for a list." >&2
	exit 1
}
fi

exit 0
