#!/usr/bin/env bash
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
declare -A vlan60_net=(
[subnet]="192.168.60.0/24"
[gateway]="192.168.60.1"
[bridge]="br60"
)

##### Container specific settings

# Plex + Tautulli
{
# Checklist before creating this container:
# Ensure a group named `jailmedia` is created on the main system with GID `1001`
# Ensure a user named `plex` is created on the main system with UID `972`
# Ensure a user named `tautulli` is created on the main system with UID `892`
# ${mediaPth} is set and is r/w by `jailmedia`
# ${cDataPath}/plex is set and is owned by `plex`
# ${backupPth}/plex is set and is owned by `plex`
# ${cDataPath}/Tautulli is set and is owned by `tautulli`


# In this example we are setting the name of the bridge we are connecting to (or creating), what interface our trafic will go through (in this case the same as the web interface), and set the use of DHCP and a fixed MAC address to go with it.
declare -A _plex=(
[puid]="972"
[pgid]="${media_gid}"
[umask]="${comn_umask}"
[environment]="VERSION=docker"
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

# Jackett + FlareSolverr
{
# Checklist before creating this container:
# Ensure a group named `jailmedia` is created on the main system with GID `1001`
# Ensure a user named `jackett` is created on the main system with UID `354`
# ${cDataPath}/jackett is set and is owned by `jackett`


# In this example we are setting the name of the bridge we are connecting to (or creating), what interface our trafic will go through (in this case the different from the web interface so we set the appropriate resolver), and set the use of DHCP, a fixed MAC address to go with it.
declare -A _jackett=(
[puid]="354"
[pgid]="${media_gid}"
[umask]="${comn_umask}"
[icon]="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/jackett.svg"
[networks]="vlan60_net"
[volumes]="${cDataPath}/jackett:/config,${thingPath}/Torrents:/mnt/transmission"
)
declare -A _jackett_vlan60_net=(
# [mac_address]=""
# [ipv4_address]=""
)

declare -A _flaresolverr=(
[environment]="LOG_LEVEL=info"
[icon]="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/flaresolverr.svg"
[networks]="vlan60_net"
)
declare -A _flaresolverr_vlan60_net=(
# [mac_address]=""
# [ipv4_address]=""
)

}

# Bazarr
{
# Checklist before creating this container:
# Ensure a group named `jailmedia` is created on the main system with GID `1001`
# Ensure a user named `bazarr` is created on the main system with UID `357`
# ${mediaPth} is set and is r/w by `jailmedia`
# ${cDataPath}/bazarr is set and is owned by `bazarr`


# In this example we are setting the name of the bridge we are connecting to (or creating), what interface our trafic will go through (in this case the different from the web interface so we set the appropriate resolver), and set the use of DHCP, a fixed MAC address to go with it.
declare -A _bazarr=(
[puid]="357"
[pgid]="${media_gid}"
[umask]="${comn_umask}"
[icon]="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/bazarr.svg"
[networks]="vlan60_net"
[volumes]="${cDataPath}/bazarr:/config,${mediaPth}:/media"
)
declare -A _bazarr_vlan60_net=(
# [mac_address]=""
# [ipv4_address]=""
)

}

# Sonarr
{
# Checklist before creating this container:
# Ensure a group named `jailmedia` is created on the main system with GID `1001`
# Ensure a user named `sonarr` is created on the main system with UID `351`
# ${mediaPth} is set and is r/w by `jailmedia`
# ${cDataPath}/sonarr is set and is owned by `sonarr`


# In this example we are setting the name of the bridge we are connecting to (or creating), what interface our trafic will go through (in this case the different from the web interface so we set the appropriate resolver), and set the use of DHCP, a fixed MAC address pair to go with it.
declare -A _sonarr=(
[puid]="351"
[pgid]="${media_gid}"
[umask]="${comn_umask}"
[icon]="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/sonarr.svg"
[networks]="vlan60_net"
[volumes]="${cDataPath}/sonarr:/config,${mediaPth}:/media"
)
declare -A _sonarr_vlan60_net=(
# [mac_address]=""
# [ipv4_address]=""
)

}

# Radarr
{
# Checklist before creating this container:
# Ensure a group named `jailmedia` is created on the main system with GID `1001`
# Ensure a user named `radarr` is created on the main system with UID `352`
# ${mediaPth} is set and is r/w by `jailmedia`
# ${cDataPath}/radarr is set and is owned by `radarr`


# In this example we are setting the name of the bridge we are connecting to (or creating), what interface our trafic will go through (in this case the different from the web interface so we set the appropriate resolver), and set the use of DHCP, a fixed MAC address pair to go with it.
declare -A _radarr=(
[puid]="352"
[pgid]="${media_gid}"
[umask]="${comn_umask}"
[icon]="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/radarr.svg"
[networks]="vlan60_net"
[volumes]="${cDataPath}/radarr:/config,${mediaPth}:/media"
)
declare -A _radarr_vlan60_net=(
# [mac_address]=""
# [ipv4_address]=""
)

}

# Transmission + OpenVPN (LXC)
{
torntPath="/mnt/data/torrents" # a temp location for torrents to land so a different Record Size can be set
# Checklist before creating this container:
# Ensure a group named `jailmedia` is created on the main system with GID `1001`
# Ensure a user named `transmission` is created on the main system with UID `921`
# ${mediaPth} is set and is r/w by `jailmedia`
# ${scriptPth} is set and is r/w by `jailmedia`
# ${jDataPath}/transmission is set and is owned by `transmission`
# ${jDataPath}/openvpn is set and is owned by `root`
# ${torntPath} is set and is owned by `transmission` and is r/w by `jailmedia`
# ${thingPath}/Torrents is set and is r/w by `jailmedia`
# pia-port-forward.sh, nftables.conf, transmission.crontab, and transmission.logrotate are in ${scriptPth}/trans


# In this example we are allowing tun interfaces, setting the name of the bridge we are connecting to (or creating), what interface our trafic will go through (in this case the different from the web interface so we set the appropriate resolver), and set the use of DHCP, and a fixed MAC address pair to go with it.
declare -A _transmission=(
[template]="debian"
[puid]="921"
[pgid]="${media_gid}"
[transmission_user]="transmission"
[group_name]="jailmedia"
[umask]="${comn_umask}"
[icon]="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/transmission.svg"
[version]="4.0.6+dfsg-3"
[networks]="vlan60_net"
[volumes]="${cDataPath}/transmission:/var/lib/transmission-daemon/config,${mediaPth}:/mnt/incoming,${torntPath}:/mnt/torrents,${thingPath}/Torrents:/mnt/transmission,${scriptPth}:/mnt/scripts,${userPth}:/mnt/users/dak180"
# Static route to allow cross vlan communication; comment to disable
[static_route]="192.168.0.0/16|192.168.60.1"
[local_lan]="192.168.0.0/16"
)
declare -A _openvpn=(
[volumes]="${cDataPath}/openvpn:/etc/openvpn"
# Name of openvpn config file
[openvpn_configfile]="openvpn.conf"
[mount]="/dev/net/tun:dev/net/tun"
)
declare -A _transmission_vlan60_net=(
# [mac_address]=""
# [ipv4_address]=""
)

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


	if [ ! -z "${testing}" ]; then
		echo "Network Details: ${netName};${!subnet};${!gateway};${!bridge}"
		return 0
	fi

	bridgeCheck="$(midclt call interface.query | jq -r --arg bn "${!bridge}" '.[] | select(.type == "BRIDGE" and .name == $bn) | .name')"
	if [ ! "${bridgeCheck}" = "${!bridge}" ]; then
		echo "Bridge ${!bridge} does not exist!" >&2
		exit 1
	fi


	if docker network ls --format '{{.Name}}' | grep -q "^${netName}$"; then
		echo "Network matches an existing configuration." >&2
		return 0
	else
		sudo docker network create -d macvlan \
		--subnet="${!subnet}" \
		--gateway="${!gateway}" \
		-o parent="${!bridge}" \
		"${netName}"
	fi
}

function usrpths {
	# Sets up command prompt and nano defaults for root in the contaners.
	local usrpth="/mnt/scripts/user"

	# Link files
	sudo truenas-nsexec "${lxc_name}" "cd /root/ && ln -s '${usrpth}/.profile' .bashrc"
	sudo truenas-nsexec "${lxc_name}" 'cd /root/ && ln -fs .bashrc .profile'
	sudo truenas-nsexec "${lxc_name}" "cd /root/ && ln -s '${usrpth}/.nanorc' .nanorc"
	sudo truenas-nsexec "${lxc_name}" "cd /root/ && ln -s '${usrpth}/.config' .config"
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

	if [ ! -z "${_plex[environment]}" ]; then
		mapfile -t plexEnvs < <(sed -e 's:,:\n:g' <<< "${_plex[environment]}")
		for plexEnv in "${plexEnvs[@]}"; do
			containConfig="$(jq --arg environment "${plexEnv}" '.services.plex.environment += [$environment]' <<< "${containConfig}")"
		done
	fi


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

	if [ ! -z "${_tautulli[environment]}" ]; then
		mapfile -t tautulliEnvs < <(sed -e 's:,:\n:g' <<< "${_tautulli[environment]}")
		for tautulliEnv in "${tautulliEnvs[@]}"; do
			containConfig="$(jq --arg environment "${tautulliEnv}" '.services.tautulli.environment += [$environment]' <<< "${containConfig}")"
		done
	fi

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
elif [ "${cnType}" = "jackett" ]; then
{
	containConfig="{}"
	containConfig="$(jq '. += {"services": {},"networks": {}}' <<< "${containConfig}")"

# Setup the Network
{
	mapfile -t containNetworks < <(sed -e 's:,:\n:g' <<< "${_jackett[networks]},${_flaresolverr[networks]}" | uniq)
	for containNetwork in "${containNetworks[@]}"; do
		dockerNetwork "${containNetwork}"
		containConfig="$(jq --arg network "${containNetwork}" '.networks += {($network): {"external": true}}' <<< "${containConfig}")"
	done
	mapfile -t jackettNetworks < <(sed -e 's:,:\n:g' <<< "${_jackett[networks]}")
	mapfile -t flaresolverrNetworks < <(sed -e 's:,:\n:g' <<< "${_flaresolverr[networks]}")
}

# jackett
{
	# Start to build the json
	containConfig="$(jq '.services += {"jackett": {"image": "lscr.io/linuxserver/jackett:latest", "container_name": "jackett", "environment": [], "volumes": [], "restart": "unless-stopped"}}' <<< "${containConfig}")"


	# Setup the environment
	containConfig="$(jq --arg puid "${_jackett[puid]}" '.services.jackett.environment += ["PUID=\($puid)"]' <<< "${containConfig}")"
	containConfig="$(jq --arg pgid "${_jackett[pgid]}" '.services.jackett.environment += ["PGID=\($pgid)"]' <<< "${containConfig}")"
	containConfig="$(jq --arg umask "${_jackett[umask]}" '.services.jackett.environment += ["UMASK=\($umask)"]' <<< "${containConfig}")"

	if [ ! -z "${_jackett[environment]}" ]; then
		mapfile -t jackettEnvs < <(sed -e 's:,:\n:g' <<< "${_jackett[environment]}")
		for jackettEnv in "${jackettEnvs[@]}"; do
			containConfig="$(jq --arg environment "${jackettEnv}" '.services.jackett.environment += [$environment]' <<< "${containConfig}")"
		done
	fi


	# Add the mounts
	mapfile -t jackettMounts < <(sed -e 's:,:\n:g' <<< "${_jackett[volumes]}")
	for jackettMount in "${jackettMounts[@]}"; do
		containConfig="$(jq --arg volumes "${jackettMount}" '.services.jackett.volumes += [$volumes]' <<< "${containConfig}")"
	done


	# Assign network info
	for jackettNetwork in "${jackettNetworks[@]}"; do
		jackettNetMac="_jackett_${jackettNetwork}[mac_address]"
		if [ ! -z "${!jackettNetMac}" ]; then
			containConfig="$(jq --arg network "${jackettNetwork}" --arg mac_address "${!jackettNetMac}" '.services.jackett.networks[$network] += {"mac_address": $mac_address}' <<< "${containConfig}")"
		fi

		jackettNetIpv4="_jackett_${jackettNetwork}[ipv4_address]"
		containConfig="$(jq --arg network "${jackettNetwork}" --arg ipv4_address "${!jackettNetIpv4}" '.services.jackett.networks[$network] += {"ipv4_address": $ipv4_address}' <<< "${containConfig}")"
	done
}

# flaresolverr
{
	# Start to build the json
	containConfig="$(jq '.services += {"flaresolverr": {"image": "ghcr.io/flaresolverr/flaresolverr:latest", "container_name": "flaresolverr", "environment": [], "volumes": [], "restart": "unless-stopped"}}' <<< "${containConfig}")"


	# Setup the environment
	if [ ! -z "${_flaresolverr[environment]}" ]; then
		mapfile -t flaresolverrEnvs < <(sed -e 's:,:\n:g' <<< "${_flaresolverr[environment]}")
		for flaresolverrEnv in "${flaresolverrEnvs[@]}"; do
			containConfig="$(jq --arg environment "${flaresolverrEnv}" '.services.flaresolverr.environment += [$environment]' <<< "${containConfig}")"
		done
	fi


	# Assign network info
	for flaresolverrNetwork in "${flaresolverrNetworks[@]}"; do
		flaresolverrNetMac="_flaresolverr_${flaresolverrNetwork}[mac_address]"
		if [ ! -z "${!flaresolverrNetMac}" ]; then
			containConfig="$(jq --arg network "${flaresolverrNetwork}" --arg mac_address "${!flaresolverrNetMac}" '.services.flaresolverr.networks[$network] += {"mac_address": $mac_address}' <<< "${containConfig}")"
		fi

		flaresolverrNetIpv4="_flaresolverr_${flaresolverrNetwork}[ipv4_address]"
		containConfig="$(jq --arg network "${flaresolverrNetwork}" --arg ipv4_address "${!flaresolverrNetIpv4}" '.services.flaresolverr.networks[$network] += {"ipv4_address": $ipv4_address}' <<< "${containConfig}")"
	done
}

	dockerWrite "${cnType}" "${containConfig}"
}
elif [ "${cnType}" = "bazarr" ]; then
{
	containConfig="{}"
	containConfig="$(jq '. += {"services": {},"networks": {}}' <<< "${containConfig}")"

# Setup the Network
{
	mapfile -t containNetworks < <(sed -e 's:,:\n:g' <<< "${_bazarr[networks]}" | uniq)
	for containNetwork in "${containNetworks[@]}"; do
		dockerNetwork "${containNetwork}"
		containConfig="$(jq --arg network "${containNetwork}" '.networks += {($network): {"external": true}}' <<< "${containConfig}")"
	done
	mapfile -t bazarrNetworks < <(sed -e 's:,:\n:g' <<< "${_bazarr[networks]}")
}

# bazarr
{
	# Start to build the json
	containConfig="$(jq '.services += {"bazarr": {"image": "lscr.io/linuxserver/bazarr:latest", "container_name": "bazarr", "environment": [], "volumes": [], "restart": "unless-stopped"}}' <<< "${containConfig}")"


	# Setup the environment
	containConfig="$(jq --arg puid "${_bazarr[puid]}" '.services.bazarr.environment += ["PUID=\($puid)"]' <<< "${containConfig}")"
	containConfig="$(jq --arg pgid "${_bazarr[pgid]}" '.services.bazarr.environment += ["PGID=\($pgid)"]' <<< "${containConfig}")"
	containConfig="$(jq --arg umask "${_bazarr[umask]}" '.services.bazarr.environment += ["UMASK=\($umask)"]' <<< "${containConfig}")"

	if [ ! -z "${_bazarr[environment]}" ]; then
		mapfile -t bazarrEnvs < <(sed -e 's:,:\n:g' <<< "${_bazarr[environment]}")
		for bazarrEnv in "${bazarrEnvs[@]}"; do
			containConfig="$(jq --arg environment "${bazarrEnv}" '.services.bazarr.environment += [$environment]' <<< "${containConfig}")"
		done
	fi


	# Add the mounts
	mapfile -t bazarrMounts < <(sed -e 's:,:\n:g' <<< "${_bazarr[volumes]}")
	for bazarrMount in "${bazarrMounts[@]}"; do
		containConfig="$(jq --arg volumes "${bazarrMount}" '.services.bazarr.volumes += [$volumes]' <<< "${containConfig}")"
	done


	# Assign network info
	for bazarrNetwork in "${bazarrNetworks[@]}"; do
		bazarrNetMac="_bazarr_${bazarrNetwork}[mac_address]"
		if [ ! -z "${!bazarrNetMac}" ]; then
			containConfig="$(jq --arg network "${bazarrNetwork}" --arg mac_address "${!bazarrNetMac}" '.services.bazarr.networks[$network] += {"mac_address": $mac_address}' <<< "${containConfig}")"
		fi

		bazarrNetIpv4="_bazarr_${bazarrNetwork}[ipv4_address]"
		containConfig="$(jq --arg network "${bazarrNetwork}" --arg ipv4_address "${!bazarrNetIpv4}" '.services.bazarr.networks[$network] += {"ipv4_address": $ipv4_address}' <<< "${containConfig}")"
	done
}

	dockerWrite "${cnType}" "${containConfig}"
}
elif [ "${cnType}" = "sonarr" ]; then
{
	containConfig="{}"
	containConfig="$(jq '. += {"services": {},"networks": {}}' <<< "${containConfig}")"

# Setup the Network
{
	mapfile -t containNetworks < <(sed -e 's:,:\n:g' <<< "${_sonarr[networks]}" | uniq)
	for containNetwork in "${containNetworks[@]}"; do
		dockerNetwork "${containNetwork}"
		containConfig="$(jq --arg network "${containNetwork}" '.networks += {($network): {"external": true}}' <<< "${containConfig}")"
	done
	mapfile -t sonarrNetworks < <(sed -e 's:,:\n:g' <<< "${_sonarr[networks]}")
}

# sonarr
{
	# Start to build the json
	containConfig="$(jq '.services += {"sonarr": {"image": "lscr.io/linuxserver/sonarr:latest", "container_name": "sonarr", "environment": [], "volumes": [], "restart": "unless-stopped"}}' <<< "${containConfig}")"


	# Setup the environment
	containConfig="$(jq --arg puid "${_sonarr[puid]}" '.services.sonarr.environment += ["PUID=\($puid)"]' <<< "${containConfig}")"
	containConfig="$(jq --arg pgid "${_sonarr[pgid]}" '.services.sonarr.environment += ["PGID=\($pgid)"]' <<< "${containConfig}")"
	containConfig="$(jq --arg umask "${_sonarr[umask]}" '.services.sonarr.environment += ["UMASK=\($umask)"]' <<< "${containConfig}")"

	if [ ! -z "${_sonarr[environment]}" ]; then
		mapfile -t sonarrEnvs < <(sed -e 's:,:\n:g' <<< "${_sonarr[environment]}")
		for sonarrEnv in "${sonarrEnvs[@]}"; do
			containConfig="$(jq --arg environment "${sonarrEnv}" '.services.sonarr.environment += [$environment]' <<< "${containConfig}")"
		done
	fi


	# Add the mounts
	mapfile -t sonarrMounts < <(sed -e 's:,:\n:g' <<< "${_sonarr[volumes]}")
	for sonarrMount in "${sonarrMounts[@]}"; do
		containConfig="$(jq --arg volumes "${sonarrMount}" '.services.sonarr.volumes += [$volumes]' <<< "${containConfig}")"
	done


	# Assign network info
	for sonarrNetwork in "${sonarrNetworks[@]}"; do
		sonarrNetMac="_sonarr_${sonarrNetwork}[mac_address]"
		if [ ! -z "${!sonarrNetMac}" ]; then
			containConfig="$(jq --arg network "${sonarrNetwork}" --arg mac_address "${!sonarrNetMac}" '.services.sonarr.networks[$network] += {"mac_address": $mac_address}' <<< "${containConfig}")"
		fi

		sonarrNetIpv4="_sonarr_${sonarrNetwork}[ipv4_address]"
		containConfig="$(jq --arg network "${sonarrNetwork}" --arg ipv4_address "${!sonarrNetIpv4}" '.services.sonarr.networks[$network] += {"ipv4_address": $ipv4_address}' <<< "${containConfig}")"
	done
}

	dockerWrite "${cnType}" "${containConfig}"
}
elif [ "${cnType}" = "radarr" ]; then
{
	containConfig="{}"
	containConfig="$(jq '. += {"services": {},"networks": {}}' <<< "${containConfig}")"

# Setup the Network
{
	mapfile -t containNetworks < <(sed -e 's:,:\n:g' <<< "${_radarr[networks]}" | uniq)
	for containNetwork in "${containNetworks[@]}"; do
		dockerNetwork "${containNetwork}"
		containConfig="$(jq --arg network "${containNetwork}" '.networks += {($network): {"external": true}}' <<< "${containConfig}")"
	done
	mapfile -t radarrNetworks < <(sed -e 's:,:\n:g' <<< "${_radarr[networks]}")
}

# radarr
{
	# Start to build the json
	containConfig="$(jq '.services += {"radarr": {"image": "lscr.io/linuxserver/radarr:latest", "container_name": "radarr", "environment": [], "volumes": [], "restart": "unless-stopped"}}' <<< "${containConfig}")"


	# Setup the environment
	containConfig="$(jq --arg puid "${_radarr[puid]}" '.services.radarr.environment += ["PUID=\($puid)"]' <<< "${containConfig}")"
	containConfig="$(jq --arg pgid "${_radarr[pgid]}" '.services.radarr.environment += ["PGID=\($pgid)"]' <<< "${containConfig}")"
	containConfig="$(jq --arg umask "${_radarr[umask]}" '.services.radarr.environment += ["UMASK=\($umask)"]' <<< "${containConfig}")"

	if [ ! -z "${_radarr[environment]}" ]; then
		mapfile -t radarrEnvs < <(sed -e 's:,:\n:g' <<< "${_radarr[environment]}")
		for radarrEnv in "${radarrEnvs[@]}"; do
			containConfig="$(jq --arg environment "${radarrEnv}" '.services.radarr.environment += [$environment]' <<< "${containConfig}")"
		done
	fi


	# Add the mounts
	mapfile -t radarrMounts < <(sed -e 's:,:\n:g' <<< "${_radarr[volumes]}")
	for radarrMount in "${radarrMounts[@]}"; do
		containConfig="$(jq --arg volumes "${radarrMount}" '.services.radarr.volumes += [$volumes]' <<< "${containConfig}")"
	done


	# Assign network info
	for radarrNetwork in "${radarrNetworks[@]}"; do
		radarrNetMac="_radarr_${radarrNetwork}[mac_address]"
		if [ ! -z "${!radarrNetMac}" ]; then
			containConfig="$(jq --arg network "${radarrNetwork}" --arg mac_address "${!radarrNetMac}" '.services.radarr.networks[$network] += {"mac_address": $mac_address}' <<< "${containConfig}")"
		fi

		radarrNetIpv4="_radarr_${radarrNetwork}[ipv4_address]"
		containConfig="$(jq --arg network "${radarrNetwork}" --arg ipv4_address "${!radarrNetIpv4}" '.services.radarr.networks[$network] += {"ipv4_address": $ipv4_address}' <<< "${containConfig}")"
	done
}

	dockerWrite "${cnType}" "${containConfig}"
}
elif [ "${cnType}" = "trans" ] || [ "${cnType}" = "transmission" ]; then
lxc_name="transmission"
{
	# FixMe: We would create the LXC container here if we could

	# Generic Configuration
	usrpths
	if [ ! -f "${cDataPath}/transmission/.bash_history" ]; then
		sudo touch "${cDataPath}/transmission/.bash_history"
	fi
	sudo truenas-nsexec "${lxc_name}" 'ln -sf "/var/lib/transmission-daemon/config/.bash_history" "/root/.bash_history"'

	# Install prereqs
	sudo truenas-nsexec "${lxc_name}" 'apt-get -y update'
	sudo truenas-nsexec "${lxc_name}" 'apt-get -y install bash bash-completion tmux wget curl nano sudo fortune-mod fortunes bc'

	# Install main packages
	sudo truenas-nsexec "${lxc_name}" 'apt-get -y install openvpn coreutils jq nftables'

	if [ ! -z "${_transmission[version]}" ]; then
		# Get the download location of the deb
		lxc_arch="$(sudo truenas-nsexec "${lxc_name}" dpkg --print-architecture)"
		transmission_file_hash="$(curl -s "https://snapshot.debian.org/mr/binary/transmission-daemon/${_transmission[version]}/binfiles" 2>/dev/null | jq -r --arg arch "${lxc_arch}" '.result[] | select(.architecture == $arch) | .hash')"
		if [ -z "${transmission_file_hash}" ]; then
			echo "Be sure to pick a valid version: https://snapshot.debian.org/binary/transmission-daemon/" >&2
			exit 1
		fi
		transmission_pub_date="$(curl -s "https://snapshot.debian.org/mr/file/${transmission_file_hash}/info" 2>/dev/null | jq -r '.result[0].first_seen')"

		sudo truenas-nsexec "${lxc_name}" bash -c 'echo "deb [check-valid-until=no] https://snapshot.debian.org/archive/debian/20240804T152144Z trixie main" > /etc/apt/sources.list.d/transmission-snapshot.list'
		sudo truenas-nsexec "${lxc_name}" 'apt-get -o "Acquire::Check-Valid-Until=false" -y update'

		# Install specified version
		sudo truenas-nsexec "${lxc_name}" env DEBIAN_FRONTEND=noninteractive apt-get -y install --allow-downgrades \
        transmission-daemon="${_transmission[version]}" \
        transmission-cli="${_transmission[version]}" \
        transmission-common="${_transmission[version]}"

        sudo truenas-nsexec "${lxc_name}" 'rm /etc/apt/sources.list.d/transmission-snapshot.list'
	else
		sudo truenas-nsexec "${lxc_name}" 'apt-get -y install transmission-cli transmission-daemon transmission-common'
	fi

	# Lock the installed version
	sudo truenas-nsexec "${lxc_name}" 'apt-mark hold transmission-daemon transmission-cli transmission-common'

	# Set permissions
	sudo truenas-nsexec "${lxc_name}" "groupadd -g ${_transmission[pgid]} ${_transmission[group_name]}"
	sudo truenas-nsexec "${lxc_name}" "useradd -M -u ${_transmission[puid]} -g ${_transmission[pgid]} -s /usr/sbin/nologin ${_transmission[transmission_user]}"
	sudo truenas-nsexec "${lxc_name}" "usermod -aG ${_transmission[group_name]} ${_transmission[transmission_user]}"
	sudo truenas-nsexec "${lxc_name}" 'touch /var/log/transmission.log'
	sudo truenas-nsexec "${lxc_name}" "chown ${_transmission[transmission_user]}:${_transmission[group_name]} /var/log/transmission.log"
	sudo truenas-nsexec "${lxc_name}" 'mkdir -p "/tmp/trans/"'

	# Enable Services
	## Transmission config
	sudo truenas-nsexec "${lxc_name}" 'install -d -m 755 -o root -g root /etc/systemd/system/transmission-daemon.service.d'
	sudo truenas-nsexec "${lxc_name}" 'cp /mnt/scripts/trans/transmission-override.conf /tmp/trans/'

	sudo truenas-nsexec "${lxc_name}" "sed -i -e 's:%%umask%%:${_transmission[umask]}:g' -e 's:%%transmission_user%%:${_transmission[transmission_user]}:g' -e 's:%%group_name%%:${_transmission[group_name]}:g' '/tmp/trans/transmission-override.conf'"
	sudo truenas-nsexec "${lxc_name}" 'install -m 644 -o root -g root /tmp/trans/transmission-override.conf /etc/systemd/system/transmission-daemon.service.d/override.conf'

	## OpenVPN config
	# FixMe: is there anything that needs to be here

	## Network config
	sudo truenas-nsexec "${lxc_name}" 'cp /mnt/scripts/trans/transmission-nftables.conf /tmp/trans/'
	sudo truenas-nsexec "${lxc_name}" "sed -i -e 's:%%transmission_user%%:${_transmission[transmission_user]}:g' -e 's:%%local_lan%%:${_transmission[local_lan]}:g' '/tmp/trans/transmission-nftables.conf'"

	sudo truenas-nsexec "${lxc_name}" 'install -d -m 755 -o root -g root /etc/nftables.d'
	sudo truenas-nsexec "${lxc_name}" 'install -m 644 -o root -g root /tmp/trans/transmission-nftables.conf /etc/nftables.d/transmission-nftables.conf'
	sudo truenas-nsexec "${lxc_name}" bash -c 'grep -q "include \"/etc/nftables.d/\*.conf\"" /etc/nftables.conf || echo "include \"/etc/nftables.d/*.conf\"" >> /etc/nftables.conf'

	### Static route for local inter-vlan connections
	if [ ! -z "${_transmission[static_route]}" ]; then
		st_routeSc="$(cut -d '|' -f '1' <<< "${_transmission[static_route]}")"
		st_routeEd="$(cut -d '|' -f '2' <<< "${_transmission[static_route]}")"
		sudo truenas-nsexec "${lxc_name}" "cp /mnt/scripts/trans/static-route.service /tmp/trans/"
		sudo truenas-nsexec "${lxc_name}" "sed -i -e 's:%%st_routeSc%%:${st_routeSc}:g' -e 's:%%st_routeEd%%:${st_routeEd}:g' /tmp/trans/static-route.service"

		sudo truenas-nsexec "${lxc_name}" "install -m 644 -o root -g root /tmp/trans/static-route.service /etc/systemd/system/static-route.service"
	fi


	# Start services
	sudo truenas-nsexec "${lxc_name}" 'systemctl daemon-reload'
	sudo truenas-nsexec "${lxc_name}" "wget http://ipinfo.io/ip -qO -"
    sudo truenas-nsexec "${lxc_name}" 'systemctl enable --now nftables'
	sudo truenas-nsexec "${lxc_name}" "wget http://ipinfo.io/ip -qO -"
	sudo truenas-nsexec "${lxc_name}" "systemctl enable --now static-route.service"
    sudo truenas-nsexec "${lxc_name}" 'systemctl enable --now openvpn@openvpn'
    sudo truenas-nsexec "${lxc_name}" 'systemctl enable --now transmission-daemon'

    # Final configuration
    sudo truenas-nsexec "${lxc_name}" 'transmission-remote --torrent-done-script "/mnt/scripts/trans/torrentPost.sh"'
    sudo truenas-nsexec "${lxc_name}" '/mnt/scripts/trans/pia-port-forward.sh >> /var/log/pia.log 2>&1'
    sudo truenas-nsexec "${lxc_name}" "cp -sf /mnt/scripts/trans/transmission.logrotate /etc/logrotate.d/transmission"
    sudo truenas-nsexec "${lxc_name}" "crontab /mnt/scripts/trans/transmission.crontab"
}
else
{
	echo "Please specify a supported container type. See ${configFile} for a list." >&2
	exit 1
}
fi

exit 0
